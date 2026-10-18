`timescale 1ns / 1ps

// =============================================================================
// EEVM-64 — Phase 2, Block 16
// Conventional unsigned row-array multiplier and RV64 M-extension wrapper.
//
// The core generates every partial-product row with AND gates. Each row is
// accumulated with a WIDTH-cell ripple-carry adder into the partial product
// accumulated by the preceding row. This is intentionally a regular,
// carry-propagating baseline; it does not use the Vedic hierarchy, a compressor
// tree, a parallel-prefix final adder, precision detection, or operand isolation.
//
// The top-level `array_multiplier` uses the EEVM-64 rv64_multiplier_unit-style
// ports and supports PIPELINE_STAGES=2 or 3. The accepted request edge is the
// first pipeline stage: a 2-stage instance presents its result after the next
// rising edge; a 3-stage instance presents it after two rising-edge intervals.
// =============================================================================

module array_multiplier_core #(
    parameter int WIDTH = 64
) (
    input  logic [WIDTH-1:0]     a,
    input  logic [WIDTH-1:0]     b,
    output logic [2*WIDTH-1:0]   product
);
    // accum[r] holds the partial sum after rows 0 through r-1 have been added.
    // Bits below the current row index are already final and pass unchanged.
    // Every row adds WIDTH partial-product bits and emits one carry bit above
    // that row's most-significant partial-product column.
    wire [2*WIDTH-1:0] accum [0:WIDTH];
    assign accum[0] = '0;

    genvar r, c;
    generate
        for (r = 0; r < WIDTH; r = r + 1) begin : g_row
            wire [WIDTH:0] carry;
            assign carry[0] = 1'b0;

            if (r > 0) begin : g_preserve_final_low_bits
                assign accum[r+1][r-1:0] = accum[r][r-1:0];
            end

            for (c = 0; c < WIDTH; c = c + 1) begin : g_cell
                wire pp;
                wire acc_bit;
                assign pp      = a[c] & b[r];
                assign acc_bit = accum[r][r+c];

                // Full-adder sum and carry for this cell of the row array.
                assign accum[r+1][r+c] = acc_bit ^ pp ^ carry[c];
                assign carry[c+1] = (acc_bit & pp) |
                                    (acc_bit & carry[c]) |
                                    (pp      & carry[c]);
            end

            // Final carry of row r has weight 2^(WIDTH+r).
            assign accum[r+1][r+WIDTH] = carry[WIDTH];

            if ((r + WIDTH + 1) < (2*WIDTH)) begin : g_preserve_high_bits
                assign accum[r+1][2*WIDTH-1:r+WIDTH+1] =
                       accum[r][2*WIDTH-1:r+WIDTH+1];
            end
        end
    endgenerate

    assign product = accum[WIDTH];
endmodule


module array_multiplier #(
    parameter int PIPELINE_STAGES = 2
) (
    input  logic        clk,
    input  logic        rst_n,       // asynchronous, active-low reset
    input  logic        valid_in,    // one request may be accepted each cycle
    input  logic [1:0]  op_sel,      // 00=MUL, 01=MULH, 10=MULHSU, 11=MULHU
    input  logic [63:0] rs1,
    input  logic [63:0] rs2,
    output logic        valid_out,
    output logic [63:0] result
);
    localparam logic [1:0] OP_MUL   = 2'b00;
    localparam logic [1:0] OP_MULH  = 2'b01;
    localparam logic [1:0] OP_MULHSU= 2'b10;
    localparam logic [1:0] OP_MULHU = 2'b11;

    logic signed_a, signed_b;
    logic neg_a, neg_b;
    logic negate_product_comb;
    logic [63:0] mag_a, mag_b;
    logic [127:0] product_mag_comb;

    // Keep the architectural signedness contract common to the other EEVM-64
    // top-level configurations. Unlike the proposed Vedic datapath, this
    // baseline deliberately does not mask operands when valid_in is low.
    always_comb begin
        signed_a = 1'b0;
        signed_b = 1'b0;
        case (op_sel)
            OP_MULH: begin
                signed_a = 1'b1;
                signed_b = 1'b1;
            end
            OP_MULHSU: begin
                signed_a = 1'b1;
                signed_b = 1'b0;
            end
            default: begin
                signed_a = 1'b0;
                signed_b = 1'b0;
            end
        endcase

        neg_a = signed_a && rs1[63];
        neg_b = signed_b && rs2[63];
        mag_a = neg_a ? ((~rs1) + 64'd1) : rs1;
        mag_b = neg_b ? ((~rs2) + 64'd1) : rs2;
        negate_product_comb = neg_a ^ neg_b;
    end

    array_multiplier_core #(.WIDTH(64)) u_array_core (
        .a       (mag_a),
        .b       (mag_b),
        .product (product_mag_comb)
    );

    // Stage 1: register the unsigned magnitude product and operation metadata.
    logic [127:0] product_mag_s1;
    logic         negate_s1;
    logic [1:0]   op_sel_s1;
    logic         valid_s1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_mag_s1 <= '0;
            negate_s1       <= 1'b0;
            op_sel_s1       <= OP_MUL;
            valid_s1        <= 1'b0;
        end else begin
            // No clock-enable or operand-isolation optimization in the baseline.
            product_mag_s1 <= product_mag_comb;
            negate_s1       <= negate_product_comb;
            op_sel_s1       <= op_sel;
            valid_s1        <= valid_in;
        end
    end

    logic [127:0] product_signed_s1;
    assign product_signed_s1 = negate_s1
                             ? ((~product_mag_s1) + 128'd1)
                             : product_mag_s1;

    function automatic logic [63:0] select_product_slice(
        input logic [127:0] product_value,
        input logic [1:0]   operation
    );
        begin
            case (operation)
                OP_MUL:    select_product_slice = product_value[63:0];
                OP_MULH,
                OP_MULHSU,
                OP_MULHU:  select_product_slice = product_value[127:64];
                default:   select_product_slice = 64'b0;
            endcase
        end
    endfunction

    generate
        if (PIPELINE_STAGES == 2) begin : g_pipe2
            // Stage 2: sign-correct and select the architectural result slice.
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result   <= '0;
                    valid_out<= 1'b0;
                end else begin
                    result    <= select_product_slice(product_signed_s1, op_sel_s1);
                    valid_out <= valid_s1;
                end
            end
        end else if (PIPELINE_STAGES == 3) begin : g_pipe3
            // Stage 2: capture the signed full product and matching metadata.
            logic [127:0] product_signed_s2;
            logic [1:0]   op_sel_s2;
            logic         valid_s2;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    product_signed_s2 <= '0;
                    op_sel_s2         <= OP_MUL;
                    valid_s2          <= 1'b0;
                end else begin
                    product_signed_s2 <= product_signed_s1;
                    op_sel_s2         <= op_sel_s1;
                    valid_s2          <= valid_s1;
                end
            end

            // Stage 3: select and register the architectural result slice.
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result    <= '0;
                    valid_out <= 1'b0;
                end else begin
                    result    <= select_product_slice(product_signed_s2, op_sel_s2);
                    valid_out <= valid_s2;
                end
            end
        end else begin : g_invalid_pipeline_parameter
            initial $error("array_multiplier: PIPELINE_STAGES must be 2 or 3");
            always_comb begin
                result    = 64'b0;
                valid_out = 1'b0;
            end
        end
    endgenerate
endmodule
