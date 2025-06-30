`timescale 1ns/1ps

module tb_hash_registers;

    logic clk;
    logic reset_n;
    logic init_H;
    logic update_H;
    logic [2:0] i_count;
    logic [7:0] H_update;
    logic [7:0] H_out [0:7];

    // Istanziazione del DUT
    hash_registers dut (
        .clk(clk),
        .reset_n(reset_n),
        .init_H(init_H),
        .update_H(update_H),
        .i_count(i_count),
        .H_update(H_update),
        .H_out(H_out)
    );

    // Clock a 10ns
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        // Inizializza segnali
        reset_n = 1;
        init_H = 0;
        update_H = 0;
        i_count = 0;
        H_update = 8'h00;

        $display("=== Test HASH_REGISTERS ===");

        // 1. Applica reset
        reset_n = 0;
        #10;
        reset_n = 1;
        #10;
        $display("--- Dopo reset ---");
        print_H();

        // 2. Cambia H[3] per vedere che il valore cambi
        update_H = 1;
        i_count = 3;
        H_update = 8'h99;
        #10;
        update_H = 0;
        #10;
        $display("--- Dopo update_H su H[3] ---");
        print_H();

        // 3. Inizializza di nuovo (init_H = 1)
        init_H = 1;
        #10;
        init_H = 0;
        #10;
        $display("--- Dopo init_H ---");
        print_H();

        // 4. Aggiorna più registri in sequenza
        repeat (8) begin
            update_H = 1;
            i_count = $random % 8;
            H_update = $random;
            #10;
            update_H = 0;
            #10;
            $display("Aggiornato H[%0d] a 0x%0h", i_count, H_update);
            print_H();
        end

        $display("=== Fine test hash_registers ===");
        $finish;
    end

    // Task per stampare i registri H
    task print_H;
        int i;
        $write("H = [");
        for (i = 0; i < 8; i = i + 1) begin
            $write("0x%0h", H_out[i]);
            if (i != 7) $write(", ");
        end
        $write("]\n");
    endtask

endmodule
