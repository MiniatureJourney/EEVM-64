`timescale 1ns / 1ps

// =============================================================================
// EEVM-64 — Phase 2, Block 15
// Configuration wrapper for the three-stage Kogge–Stone variant.
//
// Keep the canonical, parameterized rv64_multiplier_unit as the single source
// of datapath behavior. This wrapper fixes this experiment's parameters without
// changing Block 14's default two-stage Brent–Kung configuration.
// =============================================================================
module rv64_multiplier_unit_block15 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [1:0]  op_sel,
    input  logic [63:0] rs1,
    input  logic [63:0] rs2,
    output logic        valid_out,
    output logic [63:0] result
);

    rv64_multiplier_unit #(
        .PIPELINE_STAGES(3),
        .ADDER_TYPE("KOGGE_STONE"),
        .COMBINE("CSA_3TO2")
    ) u_rv64_multiplier_unit (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .op_sel   (op_sel),
        .rs1      (rs1),
        .rs2      (rs2),
        .valid_out(valid_out),
        .result   (result)
    );

endmodule
