`timescale 1ns / 1ps

// =============================================================================
// EEVM-64 — Phase 2, Block 18
// Conventional Wallace-tree multiplier baseline.
//
// The arithmetic core forms one AND-generated partial-product row per bit of b.
// A Wallace reduction network repeatedly compresses triples of 2*WIDTH-bit rows
// into sum and shifted-carry rows; the final two rows are added once. No Vedic
// hierarchy, radix-4 Booth recoding, precision detector, operand isolation, or
// custom low-power clock gating is used in this baseline.
//
// The wrapper follows the existing EEVM-64 RV64 M-extension port contract and
// supports PIPELINE_STAGES=2 or 3. In this convention the request-sampling edge
// is stage 1; the 2-stage result register updates on the following rising edge,
// while the 3-stage path adds one more registered stage. Keep this convention
// aligned across Block 14–19 testbenches/specification before paper claims.
// =============================================================================

module wallace_csa_stage #(
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

            // Per-bit full-adder equations. Carry is shifted to its next weight.
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


module wallace_tree_core #(
    parameter int WIDTH = 64
) (
    input  logic [WIDTH-1:0]  a,
    input  logic [WIDTH-1:0]  b,
    output wire [2*WIDTH-1:0] product
);
    localparam int PRODUCT_WIDTH = 2 * WIDTH;
    // Keep a second zero row for WIDTH=1; the main use is WIDTH=64.
    localparam int N0  = (WIDTH < 2) ? 2 : WIDTH;
    localparam int N1  = (N0  / 3) * 2 + (N0  % 3);
    localparam int N2  = (N1  / 3) * 2 + (N1  % 3);
    localparam int N3  = (N2  / 3) * 2 + (N2  % 3);
    localparam int N4  = (N3  / 3) * 2 + (N3  % 3);
    localparam int N5  = (N4  / 3) * 2 + (N4  % 3);
    localparam int N6  = (N5  / 3) * 2 + (N5  % 3);
    localparam int N7  = (N6  / 3) * 2 + (N6  % 3);
    localparam int N8  = (N7  / 3) * 2 + (N7  % 3);
    localparam int N9  = (N8  / 3) * 2 + (N8  % 3);
    localparam int N10 = (N9  / 3) * 2 + (N9  % 3);

    wire [PRODUCT_WIDTH-1:0] pp_rows [0:N0-1];
    genvar r;
    generate
        for (r = 0; r < N0; r = r + 1) begin : g_partial_products
            if (r < WIDTH) begin : g_real_row
                assign pp_rows[r] =
                    ({{WIDTH{1'b0}}, (a & {WIDTH{b[r]}})} << r);
            end else begin : g_padding_row
                assign pp_rows[r] = '0;
            end
        end
    endgenerate

    wire [PRODUCT_WIDTH-1:0] s1  [0:N1-1];
    wire [PRODUCT_WIDTH-1:0] s2  [0:N2-1];
    wire [PRODUCT_WIDTH-1:0] s3  [0:N3-1];
    wire [PRODUCT_WIDTH-1:0] s4  [0:N4-1];
    wire [PRODUCT_WIDTH-1:0] s5  [0:N5-1];
    wire [PRODUCT_WIDTH-1:0] s6  [0:N6-1];
    wire [PRODUCT_WIDTH-1:0] s7  [0:N7-1];
    wire [PRODUCT_WIDTH-1:0] s8  [0:N8-1];
    wire [PRODUCT_WIDTH-1:0] s9  [0:N9-1];
    wire [PRODUCT_WIDTH-1:0] s10 [0:N10-1];

    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N0),  .OUT_ROWS(N1))  u_csa1  (.in_rows(pp_rows), .out_rows(s1));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N1),  .OUT_ROWS(N2))  u_csa2  (.in_rows(s1),      .out_rows(s2));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N2),  .OUT_ROWS(N3))  u_csa3  (.in_rows(s2),      .out_rows(s3));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N3),  .OUT_ROWS(N4))  u_csa4  (.in_rows(s3),      .out_rows(s4));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N4),  .OUT_ROWS(N5))  u_csa5  (.in_rows(s4),      .out_rows(s5));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N5),  .OUT_ROWS(N6))  u_csa6  (.in_rows(s5),      .out_rows(s6));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N6),  .OUT_ROWS(N7))  u_csa7  (.in_rows(s6),      .out_rows(s7));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N7),  .OUT_ROWS(N8))  u_csa8  (.in_rows(s7),      .out_rows(s8));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N8),  .OUT_ROWS(N9))  u_csa9  (.in_rows(s8),      .out_rows(s9));
    wallace_csa_stage #(.WIDTH(PRODUCT_WIDTH), .ROWS(N9),  .OUT_ROWS(N10)) u_csa10 (.in_rows(s9),      .out_rows(s10));

    // For WIDTH<=64 the tree has at most 64 initial rows and reduces to two.
    assign product = s10[0] + s10[1];
endmodule


module wallace_tree_multiplier #(
    parameter int PIPELINE_STAGES = 2
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [1:0]  op_sel,     // 00=MUL, 01=MULH, 10=MULHSU, 11=MULHU
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

    // Signedness wrapper is shared conceptually with the other baseline blocks.
    // The Wallace core itself performs only unsigned magnitude multiplication.
    always_comb begin
        signed_a = 1'b0;
        signed_b = 1'b0;
        case (op_sel)
            OP_MULH: begin signed_a = 1'b1; signed_b = 1'b1; end
            OP_MULHSU: begin signed_a = 1'b1; signed_b = 1'b0; end
            default: begin signed_a = 1'b0; signed_b = 1'b0; end
        endcase

        neg_a = signed_a && rs1[63];
        neg_b = signed_b && rs2[63];
        mag_a = neg_a ? ((~rs1) + 64'd1) : rs1;
        mag_b = neg_b ? ((~rs2) + 64'd1) : rs2;
        negate_product_comb = neg_a ^ neg_b;
    end

    wallace_tree_core #(.WIDTH(64)) u_wallace_core (
        .a(mag_a), .b(mag_b), .product(product_mag_comb)
    );

    // Stage 1: register the full unsigned magnitude product and metadata.
    logic [127:0] product_mag_s1;
    logic          negate_s1;
    logic [1:0]    op_sel_s1;
    logic          valid_s1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_mag_s1 <= '0;
            negate_s1      <= 1'b0;
            op_sel_s1      <= OP_MUL;
            valid_s1       <= 1'b0;
        end else begin
            // No operand isolation or datapath clock gating in the baseline.
            product_mag_s1 <= product_mag_comb;
            negate_s1      <= negate_product_comb;
            op_sel_s1      <= op_sel;
            valid_s1       <= valid_in;
        end
    end

    wire [127:0] product_signed_s1 = negate_s1
                                   ? ((~product_mag_s1) + 128'd1)
                                   : product_mag_s1;

    function automatic logic [63:0] select_product_slice(
        input logic [127:0] product_value,
        input logic [1:0] operation
    );
        begin
            case (operation)
                OP_MUL: select_product_slice = product_value[63:0];
                OP_MULH, OP_MULHSU, OP_MULHU:
                    select_product_slice = product_value[127:64];
                default: select_product_slice = 64'b0;
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
            initial $error("wallace_tree_multiplier: PIPELINE_STAGES must be 2 or 3");
            always_comb begin result = 64'b0; valid_out = 1'b0; end
        end
    endgenerate
endmodule
