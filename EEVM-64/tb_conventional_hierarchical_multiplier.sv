`timescale 1ns / 1ps

// Independent reference-model regression for the 2-stage and 3-stage baseline.
module tb_conventional_hierarchical_multiplier;
    localparam logic [1:0] OP_MUL    = 2'b00;
    localparam logic [1:0] OP_MULH   = 2'b01;
    localparam logic [1:0] OP_MULHSU = 2'b10;
    localparam logic [1:0] OP_MULHU  = 2'b11;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic valid_in = 1'b0;
    logic [1:0] op_sel = OP_MUL;
    logic [63:0] rs1 = '0, rs2 = '0;
    logic valid_out_2, valid_out_3;
    logic [63:0] result_2, result_3;
    integer errors = 0;
    integer checks = 0;
    integer i;
    logic [63:0] random_a, random_b;
    logic [1:0] random_op;
    logic [63:0] rng_state = 64'hB007_4A64_17C0_F00D;

    logic exp_valid_2_q = 1'b0;
    logic [63:0] exp_result_2_q = '0;
    logic exp_valid_3_q0 = 1'b0, exp_valid_3_q1 = 1'b0;
    logic [63:0] exp_result_3_q0 = '0, exp_result_3_q1 = '0;

    always #5 clk = ~clk;

    conventional_hierarchical_multiplier #(.PIPELINE_STAGES(2)) dut_2stage (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .op_sel(op_sel),
        .rs1(rs1), .rs2(rs2), .valid_out(valid_out_2), .result(result_2)
    );

    conventional_hierarchical_multiplier #(.PIPELINE_STAGES(3)) dut_3stage (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .op_sel(op_sel),
        .rs1(rs1), .rs2(rs2), .valid_out(valid_out_3), .result(result_3)
    );

    function automatic logic [63:0] reference_result(
        input logic [63:0] a,
        input logic [63:0] b,
        input logic [1:0] operation
    );
        logic [127:0] ua, ub, up;
        logic signed [127:0] sa, sb, sp;
        begin
            ua = {64'b0, a};
            ub = {64'b0, b};
            sa = {{64{a[63]}}, a};
            sb = {{64{b[63]}}, b};
            up = '0;
            sp = '0;
            case (operation)
                OP_MUL: begin
                    up = ua * ub;
                    reference_result = up[63:0];
                end
                OP_MULH: begin
                    sp = sa * sb;
                    reference_result = sp[127:64];
                end
                OP_MULHSU: begin
                    sb = $signed({64'b0, b});
                    sp = sa * sb;
                    reference_result = sp[127:64];
                end
                OP_MULHU: begin
                    up = ua * ub;
                    reference_result = up[127:64];
                end
                default: reference_result = 64'b0;
            endcase
        end
    endfunction

    task automatic next_random(output logic [63:0] value);
        begin
            rng_state = rng_state ^ (rng_state << 13);
            rng_state = rng_state ^ (rng_state >> 7);
            rng_state = rng_state ^ (rng_state << 17);
            value = rng_state;
        end
    endtask

    task automatic step_and_check(
        input logic v,
        input logic [63:0] a,
        input logic [63:0] b,
        input logic [1:0] operation
    );
        logic [63:0] this_result;
        begin
            @(negedge clk);
            valid_in = v;
            rs1 = a;
            rs2 = b;
            op_sel = operation;
            this_result = reference_result(a, b, operation);

            @(posedge clk);
            #1;
            checks = checks + 1;

            if (valid_out_2 !== exp_valid_2_q) begin
                errors = errors + 1;
                $display("FAIL [Hierarchical P2] valid check=%0d got=%b expected=%b",
                         checks, valid_out_2, exp_valid_2_q);
            end
            if (exp_valid_2_q && (result_2 !== exp_result_2_q)) begin
                errors = errors + 1;
                $display("FAIL [Hierarchical P2] result check=%0d got=%h expected=%h",
                         checks, result_2, exp_result_2_q);
            end
            if (valid_out_3 !== exp_valid_3_q1) begin
                errors = errors + 1;
                $display("FAIL [Hierarchical P3] valid check=%0d got=%b expected=%b",
                         checks, valid_out_3, exp_valid_3_q1);
            end
            if (exp_valid_3_q1 && (result_3 !== exp_result_3_q1)) begin
                errors = errors + 1;
                $display("FAIL [Hierarchical P3] result check=%0d got=%h expected=%h",
                         checks, result_3, exp_result_3_q1);
            end

            exp_valid_2_q = v;
            exp_result_2_q = this_result;
            exp_valid_3_q1 = exp_valid_3_q0;
            exp_result_3_q1 = exp_result_3_q0;
            exp_valid_3_q0 = v;
            exp_result_3_q0 = this_result;
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
            exp_valid_2_q = 1'b0;
            exp_result_2_q = '0;
            exp_valid_3_q0 = 1'b0;
            exp_valid_3_q1 = 1'b0;
            exp_result_3_q0 = '0;
            exp_result_3_q1 = '0;
            #1;
            checks = checks + 1;
            if (valid_out_2 !== 1'b0 || result_2 !== 64'b0 ||
                valid_out_3 !== 1'b0 || result_3 !== 64'b0) begin
                errors = errors + 1;
                $display("FAIL [Hierarchical] asynchronous reset did not clear outputs");
            end
            repeat (2) @(posedge clk);
            #1;
            if (valid_out_2 !== 1'b0 || valid_out_3 !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL [Hierarchical] valid output asserted during reset");
            end
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    initial begin
        $dumpfile("tb_conventional_hierarchical_multiplier.vcd");
        $dumpvars(0, tb_conventional_hierarchical_multiplier);
        errors = 0;
        rng_state = 64'hB007_4A64_17C0_F00D;

        repeat (2) @(posedge clk);
        #1;
        if (valid_out_2 !== 1'b0 || valid_out_3 !== 1'b0 ||
            result_2 !== 64'b0 || result_3 !== 64'b0) begin
            errors = errors + 1;
            $display("FAIL [Hierarchical] initial reset check failed");
        end
        @(negedge clk);
        rst_n = 1'b1;

        // Corner cases, mixed-signedness paths, and 8/16/32/64-bit boundaries.
        step_and_check(1'b1, 64'h0, 64'h0, OP_MUL);
        step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FFFF, 64'd1, OP_MUL);
        step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FFFF, 64'hFFFF_FFFF_FFFF_FFFF, OP_MULHU);
        step_and_check(1'b1, 64'h8000_0000_0000_0000, 64'hFFFF_FFFF_FFFF_FFFF, OP_MULH);
        step_and_check(1'b1, 64'h8000_0000_0000_0000, 64'hFFFF_FFFF_FFFF_FFFF, OP_MULHSU);
        step_and_check(1'b1, 64'h7FFF_FFFF_FFFF_FFFF, 64'h7FFF_FFFF_FFFF_FFFF, OP_MULH);
        step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FF80, 64'h80, OP_MULHSU);
        step_and_check(1'b1, 64'h0000_0000_0000_00FF, 64'h0000_0000_0000_0100, OP_MULHU);
        step_and_check(1'b1, 64'h0000_0000_0000_FFFF, 64'h0000_0000_0001_0000, OP_MULHU);
        step_and_check(1'b1, 64'h0000_0000_7FFF_FFFF, 64'h0000_0000_8000_0000, OP_MULHU);
        step_and_check(1'b1, 64'h5555_5555_5555_5555, 64'hAAAA_AAAA_AAAA_AAAA, OP_MULHU);
        step_and_check(1'b1, 64'hFFFF_FFFF_0000_0001, 64'h0000_0001_FFFF_FFFF, OP_MUL);
        step_and_check(1'b0, 64'hDEAD_BEEF_DEAD_BEEF, 64'h0123_4567_89AB_CDEF, OP_MULH);

        for (i = 0; i < 4; i = i + 1) begin
            step_and_check(1'b1, 64'hFFFF_FFFF_FFFF_FFFF,
                           64'h8000_0000_0000_0001, i[1:0]);
            step_and_check(1'b1, 64'h8000_0000_0000_0000,
                           64'h0000_0000_0000_0003, i[1:0]);
            step_and_check(1'b1, 64'h0000_0000_0000_0007,
                           64'h0000_0000_0000_0009, i[1:0]);
        end

        // Asynchronous reset must flush every in-flight transaction.
        step_and_check(1'b1, 64'h1234_5678_9ABC_DEF0,
                       64'hFEDC_BA98_7654_3210, OP_MULHU);
        step_and_check(1'b1, 64'h8000_0000_0000_0000,
                       64'h0000_0000_0000_0003, OP_MULH);
        asynchronous_reset_and_flush();
        step_and_check(1'b0, '0, '0, OP_MUL);

        // Deterministic high-volume continuous request stream.
        for (i = 0; i < 1500; i = i + 1) begin
            next_random(random_a);
            next_random(random_b);
            step_and_check(1'b1, random_a, random_b, i[1:0]);
        end

        // Random bubbles and operation selection.
        for (i = 0; i < 300; i = i + 1) begin
            next_random(random_a);
            next_random(random_b);
            random_op = random_a[1:0];
            step_and_check((random_b[1:0] != 2'b00), random_a, random_b, random_op);
        end

        step_and_check(1'b0, '0, '0, OP_MUL);
        step_and_check(1'b0, '0, '0, OP_MUL);
        step_and_check(1'b0, '0, '0, OP_MUL);

        if (errors == 0)
            $display("PASS: Block19 conventional_hierarchical_multiplier; checks=%0d; PIPELINE_STAGES=2 and 3 passed", checks);
        else
            $display("FAIL: Block19 Hierarchical multiplier; errors=%0d checks=%0d", errors, checks);
        if (errors != 0) $fatal(1, "Block19 Hierarchical regression failed");
        $finish;
    end
endmodule
