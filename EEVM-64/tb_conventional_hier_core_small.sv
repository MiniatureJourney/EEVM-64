`timescale 1ns / 1ps

// Exhaustive WIDTH=8 check of the structural 8x8 hierarchy (65,536 input pairs).
module tb_conventional_hier_core_small;
    logic [7:0] a, b;
    wire [15:0] product;
    logic [15:0] expected;
    integer i, j, errors;

    conventional_hier_mul_8 dut (.a(a), .b(b), .product(product));

    initial begin
        $dumpfile("tb_conventional_hier_core_small.vcd");
        $dumpvars(0, tb_conventional_hier_core_small);
        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a = i[7:0];
                b = j[7:0];
                expected = i * j; // Golden reference only; hierarchy has no '*' above 4x4.
                #1;
                if (product !== expected) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("FAIL [Hier core W=8] a=%h b=%h got=%h expected=%h", a, b, product, expected);
                end
            end
        end
        if (errors == 0)
            $display("PASS: Block19 hierarchical core exhaustive WIDTH=8; 65536/65536 pairs correct");
        else
            $display("FAIL: Block19 hierarchical core WIDTH=8; errors=%0d", errors);
        if (errors != 0) $fatal(1, "Block19 small-core regression failed");
        $finish;
    end
endmodule
