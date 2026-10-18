`timescale 1ns / 1ps

// =============================================================================
// Testbench : tb_rv64_multiplier_unit_block15
// DUT       : rv64_multiplier_unit_block15
// Configuration: 3 pipeline stages, KOGGE_STONE, CSA_3TO2
//
// Checks RV64 MUL/MULH/MULHSU/MULHU semantics against an independent behavioral
// multiplication oracle, precisely aligned to this design's three registered
// stages. Includes directed signedness/precision boundaries, continuous input
// traffic, bubbles, mid-stream asynchronous reset, and pseudorandom vectors.
// =============================================================================
module tb_rv64_multiplier_unit_block15;
    localparam logic [1:0] OP_MUL    = 2'b00;
    localparam logic [1:0] OP_MULH   = 2'b01;
    localparam logic [1:0] OP_MULHSU = 2'b10;
    localparam logic [1:0] OP_MULHU  = 2'b11;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic valid_in = 1'b0;
    logic [1:0] op_sel = OP_MUL;
    logic [63:0] rs1 = '0;
    logic [63:0] rs2 = '0;
    logic valid_out;
    logic [63:0] result;

    integer errors = 0;
    integer checks = 0;
    integer i;
    integer random_op;
    logic [63:0] random_a, random_b;

    // Three register stages mean that a request sampled at rising edge k is
    // visible at the outputs after rising edge k+2 (two complete periods elapse).
    // The accepted edge counts as the first pipeline stage.
    logic exp_valid_d1 = 1'b0;
    logic exp_valid_d2 = 1'b0;
    logic [63:0] exp_result_d1 = '0;
    logic [63:0] exp_result_d2 = '0;

    always #5 clk = ~clk;

    rv64_multiplier_unit_block15 dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .op_sel   (op_sel),
        .rs1      (rs1),
        .rs2      (rs2),
        .valid_out(valid_out),
        .result   (result)
    );

    function automatic logic [63:0] reference_result(
        input logic [63:0] a,
        input logic [63:0] b,
        input logic [1:0] operation
    );
        logic [127:0] unsigned_a;
        logic [127:0] unsigned_b;
        logic [127:0] unsigned_product;
        logic signed [127:0] signed_a;
        logic signed [127:0] signed_b;
        logic signed [127:0] signed_product;
        begin
            unsigned_a = {64'b0, a};
            unsigned_b = {64'b0, b};
            signed_a   = {{64{a[63]}}, a};
            signed_b   = {{64{b[63]}}, b};

            case (operation)
                OP_MUL: begin
                    unsigned_product = unsigned_a * unsigned_b;
                    reference_result = unsigned_product[63:0];
                end
                OP_MULH: begin
                    signed_product = signed_a * signed_b;
                    reference_result = signed_product[127:64];
                end
                OP_MULHSU: begin
                    // First operand signed; second operand zero-extended unsigned.
                    signed_b = $signed({64'b0, b});
                    signed_product = signed_a * signed_b;
                    reference_result = signed_product[127:64];
                end
                OP_MULHU: begin
                    unsigned_product = unsigned_a * unsigned_b;
                    reference_result = unsigned_product[127:64];
                end
                default: reference_result = 64'b0;
            endcase
        end
    endfunction

    task automatic step_and_check(
        input logic        v,
        input logic [63:0] a,
        input logic [63:0] b,
        input logic [1:0]  operation
    );
        logic [63:0] this_result;
        begin
            @(negedge clk);
            valid_in = v;
            rs1 = a;
            rs2 = b;
            op_sel = operation;
            this_result = v ? reference_result(a, b, operation) : 64'b0;

            @(posedge clk);
            #1;
            checks = checks + 1;

            if (valid_out !== exp_valid_d2) begin
                errors = errors + 1;
                $display("FAIL [Block15] valid cycle=%0d got=%b expected=%b",
                         checks, valid_out, exp_valid_d2);
            end
            if (exp_valid_d2 && (result !== exp_result_d2)) begin
                errors = errors + 1;
                $display("FAIL [Block15] result cycle=%0d op history mismatch: got=%h expected=%h",
                         checks, result, exp_result_d2);
            end

            // Scoreboard delay: update only after comparing the result for this edge.
            exp_valid_d2  = exp_valid_d1;
            exp_result_d2 = exp_result_d1;
            exp_valid_d1  = v;
            exp_result_d1 = this_result;
        end
    endtask

    task automatic asynchronous_reset_and_flush;
        begin
            @(negedge clk);
            valid_in = 1'b0;
            rs1 = '0;
            rs2 = '0;
            op_sel = OP_MUL;
            rst_n = 1'b0;
            exp_valid_d1 = 1'b0;
            exp_valid_d2 = 1'b0;
            exp_result_d1 = '0;
            exp_result_d2 = '0;
            #1;
            checks = checks + 1;
            if (valid_out !== 1'b0 || result !== 64'b0) begin
                errors = errors + 1;
                $display("FAIL [Block15] asynchronous reset did not clear outputs");
            end
            repeat (2) @(posedge clk);
            #1;
            if (valid_out !== 1'b0 || result !== 64'b0) begin
                errors = errors + 1;
                $display("FAIL [Block15] outputs not held reset");
            end
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    initial begin
        $dumpfile("tb_rv64_multiplier_unit_block15.vcd");
        $dumpvars(0, tb_rv64_multiplier_unit_block15);

        // Initial reset; verify no stale transaction is marked valid.
        repeat (2) @(posedge clk);
        #1;
        if (valid_out !== 1'b0 || result !== 64'b0) begin
            errors = errors + 1;
            $display("FAIL [Block15] initial reset check failed");
        end
        @(negedge clk);
        rst_n = 1'b1;

        // Directed corner cases for arithmetic semantics and precision tiers.
        step_and_check(1'b1, 64'h0000_0000_0000_0000, 64'h0000_0000_0000_0000, OP_MUL);
        step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0001, OP_MUL);
        step_and_check(1'b1, 64'h8000_0000_0000_0000, 64'hFFFF_FFFF_FFFF_FFFF, OP_MULH);
        step_and_check(1'b1, 64'h8000_0000_0000_0000, 64'hFFFF_FFFF_FFFF_FFFF, OP_MULHSU);
        step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FFFF, 64'hFFFF_FFFF_FFFF_FFFF, OP_MULHU);
        step_and_check(1'b1, 64'h7FFF_FFFF_FFFF_FFFF, 64'h7FFF_FFFF_FFFF_FFFF, OP_MULH);
        step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FF80, 64'h0000_0000_0000_0080, OP_MULH);
        step_and_check(1'b1, 64'h0000_0000_0000_00FF, 64'h0000_0000_0000_0100, OP_MULHU);
        step_and_check(1'b1, 64'h0000_0000_0000_FFFF, 64'h0000_0000_0001_0000, OP_MULHU);
        step_and_check(1'b1, 64'h0000_0000_7FFF_FFFF, 64'h0000_0000_8000_0000, OP_MULHU);
        step_and_check(1'b1, 64'h5555_5555_5555_5555, 64'hAAAA_AAAA_AAAA_AAAA, OP_MULHU);
        step_and_check(1'b0, 64'hDEAD_BEEF_DEAD_BEEF, 64'h0123_4567_89AB_CDEF, OP_MULH);
        step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FFFF, 64'h8000_0000_0000_0001, OP_MULHSU);

        // Mix all opcodes under consecutive requests to check metadata alignment.
        for (i = 0; i < 4; i = i + 1) begin
            step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FFFF,
                           64'h8000_0000_0000_0001, i[1:0]);
            step_and_check(1'b1, 64'h8000_0000_0000_0000,
                           64'h0000_0000_0000_0003, i[1:0]);
            step_and_check(1'b1, 64'h0000_0000_0000_0007,
                           64'h0000_0000_0000_0009, i[1:0]);
        end

        // Mid-stream asynchronous reset must flush all in-flight valid metadata.
        step_and_check(1'b1, 64'h1234_5678_9ABC_DEF0, 64'hFEDC_BA98_7654_3210, OP_MULHU);
        step_and_check(1'b1, 64'h8000_0000_0000_0000, 64'h0000_0000_0000_0003, OP_MULH);
        asynchronous_reset_and_flush();
        step_and_check(1'b0, '0, '0, OP_MUL);

        // Continuous pseudo-random stream: one request per cycle, all opcodes.
        for (i = 0; i < 1000; i = i + 1) begin
            random_a = {$urandom, $urandom};
            random_b = {$urandom, $urandom};
            step_and_check(1'b1, random_a, random_b, i[1:0]);
        end

        // Random valid bubbles exercise valid/result alignment without backpressure.
        for (i = 0; i < 250; i = i + 1) begin
            random_a = {$urandom, $urandom};
            random_b = {$urandom, $urandom};
            random_op = $urandom_range(0, 3);
            step_and_check(($urandom_range(0, 3) != 0), random_a, random_b, random_op[1:0]);
        end

        // Drain the three-stage pipeline and ensure no unexpected valid remains.
        step_and_check(1'b0, '0, '0, OP_MUL);
        step_and_check(1'b0, '0, '0, OP_MUL);
        step_and_check(1'b0, '0, '0, OP_MUL);

        if (errors == 0)
            $display("PASS: Block15 3-stage KOGGE_STONE regression; checks=%0d", checks);
        else
            $display("FAIL: Block15 regression; errors=%0d checks=%0d", errors, checks);

        if (errors != 0) $fatal(1, "Block15 regression failed");
        $finish;
    end
endmodule
