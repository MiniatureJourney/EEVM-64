`timescale 1ns / 1ps

// =============================================================================
// EEVM-64 — Phase 2, Block 17
// Radix-4 modified Booth multiplier baseline.
//
// Core structure:
//   1. Radix-4 Booth recoding of the unsigned magnitude multiplier.
//   2. Generate signed partial products in {-2A, -A, 0, +A, +2A}.
//   3. Sign-extend and shift each row into the 2*WIDTH product domain.
//   4. Reduce rows with a carry-save compressor tree.
//   5. Use one final carry-propagate addition.
//
// The top-level wrapper keeps the RV64 M-extension port and operation contract,
// but intentionally excludes the proposed Vedic hierarchy, precision detection,
// operand isolation, and low-power clock gating. It is a separate baseline.
// =============================================================================

module booth_csa_stage #(
    parameter int WIDTH = 128,
    parameter int ROWS = 3,
    parameter int OUT_ROWS = (ROWS / 3) * 2 + (ROWS % 3)
) (
    input  wire [WIDTH-1:0] in_rows  [0:ROWS-1],
    output wire [WIDTH-1:0] out_rows [0:OUT_ROWS-1]
);
    localparam int GROUPS = ROWS / 3;
    localparam int REMAINDER = ROWS % 3;

    genvar g;
    generate
        for (g = 0; g < GROUPS; g = g + 1) begin : g_compress
            wire [WIDTH-1:0] x, y, z;
            assign x = in_rows[3*g];
            assign y = in_rows[3*g+1];
            assign z = in_rows[3*g+2];

            // Carry-save reduction: the carry row is shifted one bit left.
            assign out_rows[2*g]   = x ^ y ^ z;
            assign out_rows[2*g+1] = ((x & y) | (x & z) | (y & z)) << 1;
        end

        if (REMAINDER == 1) begin : g_pass_one
            assign out_rows[2*GROUPS] = in_rows[ROWS-1];
        end else if (REMAINDER == 2) begin : g_pass_two
            assign out_rows[2*GROUPS]   = in_rows[3*GROUPS];
            assign out_rows[2*GROUPS+1] = in_rows[3*GROUPS+1];
        end
    endgenerate
endmodule


module booth_radix4_core #(
    parameter int WIDTH = 64
) (
    input  logic [WIDTH-1:0]   a,
    input  logic [WIDTH-1:0]   b,
    output wire [2*WIDTH-1:0]  product
);
    // One extra unsigned-sign bit plus Booth's low zero yields ceil(WIDTH/2)+1
    // overlapping radix-4 groups, including a top group that prevents b[MSB]
    // from being interpreted as a negative signed multiplier bit.
    localparam int PRODUCT_WIDTH = 2 * WIDTH;
    localparam int N0 = (WIDTH + 1) / 2 + 1;
    localparam int N1 = (N0 / 3) * 2 + (N0 % 3);
    localparam int N2 = (N1 / 3) * 2 + (N1 % 3);
    localparam int N3 = (N2 / 3) * 2 + (N2 % 3);
    localparam int N4 = (N3 / 3) * 2 + (N3 % 3);
    localparam int N5 = (N4 / 3) * 2 + (N4 % 3);
    localparam int N6 = (N5 / 3) * 2 + (N5 % 3);
    localparam int N7 = (N6 / 3) * 2 + (N6 % 3);
    localparam int N8 = (N7 / 3) * 2 + (N7 % 3);

    logic [WIDTH+2:0] booth_bits;
    logic signed [WIDTH+1:0] a_ext;
    logic signed [WIDTH+1:0] pp_small;
    logic [2:0] booth_code;
    logic [PRODUCT_WIDTH-1:0] pp_rows [0:N0-1];
    integer bit_index;
    integer group_index;

    // Explicit radix-4 partial-product generation. b is treated as unsigned:
    // booth_bits[WIDTH+1] and above are zero extension, while booth_bits[0]=0.
    always_comb begin
        booth_bits = '0;
        for (bit_index = 0; bit_index < WIDTH; bit_index = bit_index + 1)
            booth_bits[bit_index+1] = b[bit_index];

        a_ext = $signed({2'b00, a});
        booth_code = 3'b000;
        pp_small = '0;
        for (group_index = 0; group_index < N0; group_index = group_index + 1) begin
            booth_code = booth_bits[(2*group_index) +: 3];
            case (booth_code)
                3'b001, 3'b010: pp_small = a_ext;
                3'b011:         pp_small = a_ext <<< 1;
                3'b100:         pp_small = -(a_ext <<< 1);
                3'b101, 3'b110: pp_small = -a_ext;
                default:        pp_small = '0;
            endcase

            pp_rows[group_index] =
                $signed({{(WIDTH-2){pp_small[WIDTH+1]}}, pp_small})
                <<< (2*group_index);
        end
    end

    wire [PRODUCT_WIDTH-1:0] s1 [0:N1-1];
    wire [PRODUCT_WIDTH-1:0] s2 [0:N2-1];
    wire [PRODUCT_WIDTH-1:0] s3 [0:N3-1];
    wire [PRODUCT_WIDTH-1:0] s4 [0:N4-1];
    wire [PRODUCT_WIDTH-1:0] s5 [0:N5-1];
    wire [PRODUCT_WIDTH-1:0] s6 [0:N6-1];
    wire [PRODUCT_WIDTH-1:0] s7 [0:N7-1];
    wire [PRODUCT_WIDTH-1:0] s8 [0:N8-1];

    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N0), .OUT_ROWS(N1)) u_csa1
        (.in_rows(pp_rows), .out_rows(s1));
    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N1), .OUT_ROWS(N2)) u_csa2
        (.in_rows(s1), .out_rows(s2));
    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N2), .OUT_ROWS(N3)) u_csa3
        (.in_rows(s2), .out_rows(s3));
    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N3), .OUT_ROWS(N4)) u_csa4
        (.in_rows(s3), .out_rows(s4));
    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N4), .OUT_ROWS(N5)) u_csa5
        (.in_rows(s4), .out_rows(s5));
    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N5), .OUT_ROWS(N6)) u_csa6
        (.in_rows(s5), .out_rows(s6));
    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N6), .OUT_ROWS(N7)) u_csa7
        (.in_rows(s6), .out_rows(s7));
    booth_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N7), .OUT_ROWS(N8)) u_csa8
        (.in_rows(s7), .out_rows(s8));

    // N8 is two for WIDTH<=64. This is the only carry-propagate adder in the
    // Booth core; addition naturally returns the low PRODUCT_WIDTH bits.
    assign product = s8[0] + s8[1];
endmodule


module booth_radix4_multiplier #(
    parameter int PIPELINE_STAGES = 2
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [1:0]  op_sel,       // 00=MUL, 01=MULH, 10=MULHSU, 11=MULHU
    input  logic [63:0] rs1,
    input  logic [63:0] rs2,
    output logic        valid_out,
    output logic [63:0] result
);
    localparam logic [1:0] OP_MUL    = 2'b00;
    localparam logic [1:0] OP_MULH   = 2'b01;
    localparam logic [1:0] OP_MULHSU = 2'b10;
    localparam logic [1:0] OP_MULHU  = 2'b11;

    logic signed_a, signed_b;
    logic neg_a, neg_b;
    logic negate_product_comb;
    logic [63:0] mag_a, mag_b;
    wire  [127:0] product_mag_comb;

    // Common architectural signedness wrapper; the arithmetic core itself is
    // unsigned and receives magnitudes, like the Block 16 array baseline.
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

    booth_radix4_core #(.WIDTH(64)) u_booth_core (
        .a(mag_a), .b(mag_b), .product(product_mag_comb)
    );

    // Stage 1: register magnitude product and associated operation metadata.
    logic [127:0] product_mag_s1;
    logic          negate_s1;
    logic [1:0]    op_sel_s1;
    logic          valid_s1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_mag_s1 <= '0;
            negate_s1       <= 1'b0;
            op_sel_s1       <= OP_MUL;
            valid_s1        <= 1'b0;
        end else begin
            // No precision detector, operand isolation, or datapath clock gate:
            // switching behavior belongs to the conventional baseline.
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
        input logic [1:0] operation
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
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result    <= '0;
                    valid_out <= 1'b0;
                end else begin
                    result    <= select_product_slice(product_signed_s1, op_sel_s1);
                    valid_out <= valid_s1;
                end
            end
        end else if (PIPELINE_STAGES == 3) begin : g_pipe3
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
            initial $error("booth_radix4_multiplier: PIPELINE_STAGES must be 2 or 3");
            always_comb begin
                result    = 64'b0;
                valid_out = 1'b0;
            end
        end
    endgenerate
endmodule
