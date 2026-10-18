`timescale 1ns / 1ps

// =============================================================================
// EEVM-64 — Phase 2, Block 19
// Conventional hierarchical multiplier baseline (no low-power techniques).
//
// Structure: 64x64 -> four 32x32 products -> four 16x16 products per branch
// -> four 8x8 products per branch -> four 4x4 leaf products. Each level
// combines the four subproducts using the conventional shift-and-add identity:
//   A = Ah*2^H + Al; B = Bh*2^H + Bl
//   A*B = (Ah*Bh)*2^(2H) + (Ah*Bl)*2^H + (Al*Bh)*2^H + Al*Bl
//
// Only the 4x4 leaf uses behavioral '*'. No Vedic decomposition, Booth
// recoding, Wallace/array reduction tree, precision detection, operand
// isolation, or custom low-power clock gating is included.
//
// Top-level port contract follows Blocks 14–18. PIPELINE_STAGES=2 or 3.
// The project-wide edge-count convention remains an open cross-block item:
// request-sampling edge is designated stage 1; 2-stage result updates on the
// next rising edge, and 3-stage adds one extra registered stage.
// =============================================================================

module conventional_hier_mul_4 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output wire  [7:0] product
);
    assign product = a * b;
endmodule

module conventional_hier_mul_8 (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output wire [15:0] product
);
    wire [3:0] a_lo = a[3:0];
    wire [3:0] a_hi = a[7:4];
    wire [3:0] b_lo = b[3:0];
    wire [3:0] b_hi = b[7:4];
    wire [7:0] p_ll, p_lh, p_hl, p_hh;
    wire [15:0] t_ll, t_lh, t_hl, t_hh;

    conventional_hier_mul_4 u_ll (.a(a_lo), .b(b_lo), .product(p_ll));
    conventional_hier_mul_4 u_lh (.a(a_lo), .b(b_hi), .product(p_lh));
    conventional_hier_mul_4 u_hl (.a(a_hi), .b(b_lo), .product(p_hl));
    conventional_hier_mul_4 u_hh (.a(a_hi), .b(b_hi), .product(p_hh));

    assign t_ll = {8'b0, p_ll};
    assign t_lh = {8'b0, p_lh} << 4;
    assign t_hl = {8'b0, p_hl} << 4;
    assign t_hh = {8'b0, p_hh} << 8;
    assign product = t_ll + t_lh + t_hl + t_hh;
endmodule

module conventional_hier_mul_16 (
    input  logic [15:0] a,
    input  logic [15:0] b,
    output wire  [31:0] product
);
    wire [7:0] a_lo = a[7:0];
    wire [7:0] a_hi = a[15:8];
    wire [7:0] b_lo = b[7:0];
    wire [7:0] b_hi = b[15:8];
    wire [15:0] p_ll, p_lh, p_hl, p_hh;
    wire [31:0] t_ll, t_lh, t_hl, t_hh;

    conventional_hier_mul_8 u_ll (.a(a_lo), .b(b_lo), .product(p_ll));
    conventional_hier_mul_8 u_lh (.a(a_lo), .b(b_hi), .product(p_lh));
    conventional_hier_mul_8 u_hl (.a(a_hi), .b(b_lo), .product(p_hl));
    conventional_hier_mul_8 u_hh (.a(a_hi), .b(b_hi), .product(p_hh));

    assign t_ll = {16'b0, p_ll};
    assign t_lh = {16'b0, p_lh} << 8;
    assign t_hl = {16'b0, p_hl} << 8;
    assign t_hh = {16'b0, p_hh} << 16;
    assign product = t_ll + t_lh + t_hl + t_hh;
endmodule

module conventional_hier_mul_32 (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output wire  [63:0] product
);
    wire [15:0] a_lo = a[15:0];
    wire [15:0] a_hi = a[31:16];
    wire [15:0] b_lo = b[15:0];
    wire [15:0] b_hi = b[31:16];
    wire [31:0] p_ll, p_lh, p_hl, p_hh;
    wire [63:0] t_ll, t_lh, t_hl, t_hh;

    conventional_hier_mul_16 u_ll (.a(a_lo), .b(b_lo), .product(p_ll));
    conventional_hier_mul_16 u_lh (.a(a_lo), .b(b_hi), .product(p_lh));
    conventional_hier_mul_16 u_hl (.a(a_hi), .b(b_lo), .product(p_hl));
    conventional_hier_mul_16 u_hh (.a(a_hi), .b(b_hi), .product(p_hh));

    assign t_ll = {32'b0, p_ll};
    assign t_lh = {32'b0, p_lh} << 16;
    assign t_hl = {32'b0, p_hl} << 16;
    assign t_hh = {32'b0, p_hh} << 32;
    assign product = t_ll + t_lh + t_hl + t_hh;
endmodule

module conventional_hier_mul_64 (
    input  logic [63:0] a,
    input  logic [63:0] b,
    output wire  [127:0] product
);
    wire [31:0] a_lo = a[31:0];
    wire [31:0] a_hi = a[63:32];
    wire [31:0] b_lo = b[31:0];
    wire [31:0] b_hi = b[63:32];
    wire [63:0] p_ll, p_lh, p_hl, p_hh;
    wire [127:0] t_ll, t_lh, t_hl, t_hh;

    conventional_hier_mul_32 u_ll (.a(a_lo), .b(b_lo), .product(p_ll));
    conventional_hier_mul_32 u_lh (.a(a_lo), .b(b_hi), .product(p_lh));
    conventional_hier_mul_32 u_hl (.a(a_hi), .b(b_lo), .product(p_hl));
    conventional_hier_mul_32 u_hh (.a(a_hi), .b(b_hi), .product(p_hh));

    assign t_ll = {64'b0, p_ll};
    assign t_lh = {64'b0, p_lh} << 32;
    assign t_hl = {64'b0, p_hl} << 32;
    assign t_hh = {64'b0, p_hh} << 64;
    assign product = t_ll + t_lh + t_hl + t_hh;
endmodule

module conventional_hierarchical_multiplier #(
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

    // Signedness is handled outside the unsigned hierarchical core.
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

    conventional_hier_mul_64 u_hierarchical_core (
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
            // Baseline intentionally has no precision/operand isolation or
            // low-power clock gating; datapath toggling is not suppressed.
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
            initial $error("conventional_hierarchical_multiplier: PIPELINE_STAGES must be 2 or 3");
            always_comb begin result = 64'b0; valid_out = 1'b0; end
        end
    endgenerate
endmodule
