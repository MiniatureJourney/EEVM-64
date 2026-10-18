`timescale 1ns / 1ps

// Exhaustive independent core check at WIDTH=8 (all 65,536 unsigned pairs).
module tb_array_multiplier_core_small;
    logic [7:0] a, b;
    logic [15:0] product;
    logic [15:0] expected;
    integer i, j, errors;

    array_multiplier_core #(.WIDTH(8)) dut (.a(a), .b(b), .product(product));

    initial begin
        $dumpfile("tb_array_multiplier_core_small.vcd");
        $dumpvars(0, tb_array_multiplier_core_small);
        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a = i[7:0];
                b = j[7:0];
                expected = i * j; // Reference only; DUT contains no multiplication operator.
                #1;
                if (product !== expected) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("FAIL [array core W=8] a=%h b=%h got=%h expected=%h",
                                 a, b, product, expected);
                end
            end
        end
        if (errors == 0)
            $display("PASS: Block16 array core exhaustive WIDTH=8; 65536/65536 pairs correct");
        else
            $display("FAIL: Block16 array core WIDTH=8; errors=%0d", errors);
        if (errors != 0) $fatal(1, "Block16 small core regression failed");
        $finish;
    end
endmodule
