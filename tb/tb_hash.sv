`timescale 1ns/1ps
module tb_hash_top;

    // ---------------- Testbench signals ----------------
    logic        clk;
    logic        reset_n;
    logic        start_msg;
    logic [7:0]  msg_byte;
    logic        msg_done;
    logic        valid_in;
    logic [7:0]  digest [7:0];
    logic        digest_ready;
    logic        load_byte;
    logic        round_exec_active;

    // ---------------- Device Under Test (DUT) ----------------
    hash_top dut (
        .clk              (clk),
        .reset_n          (reset_n),
        .start_msg        (start_msg),
        .msg_byte         (msg_byte),
        .msg_done         (msg_done),
        .valid_in         (valid_in),
        .digest           (digest),
        .digest_ready     (digest_ready),
        .load_byte        (load_byte),
        .round_exec_active(round_exec_active)
    );

    // 10 ns clock generation
    initial  clk = 0;
    always #5 clk = ~clk;

    // Task to print the final digest in hex format
    task automatic print_digest(string label);
        int i;
        for (i = 0; i < 8; i = i + 1) begin
            $write("%02h ", digest[i]);
        end
    endtask

    // =========  PARAMETRI DI PROVA  =========
    // cambia questa stringa per testare casi diversi
    string  message_str = "Hello World";   // "" → caso vuoto

    // =========  TEST SEQUENCE  ===========
    initial begin
        // --- Apply reset ---
        reset_n   = 0;
        start_msg = 0;
        msg_done  = 0;
        valid_in  = 0;
        msg_byte  = '0;
        repeat (2) @(posedge clk);
        reset_n = 1;
        @(posedge clk);

        // === MESSAGE TRANSMISSION ===
        if (message_str.len() == 0) begin
            // ---- Empty message case ----
            start_msg = 1;
            msg_done  = 1;
            @(posedge clk);
            start_msg = 0;
            msg_done  = 0;
        end
        else begin
            // ---- Non-empty message case ----
            start_msg = 1;
            @(posedge clk);
            start_msg = 0;

            foreach (message_str[i]) begin
                // Wait until no transformation round is active
                wait (round_exec_active == 0);
                @(negedge clk);
                msg_byte = message_str[i];
                valid_in = 1;
                @(posedge load_byte);   // Wait for core to latch msg_byte
                @(posedge clk);         // Safety margin cycle
                valid_in = 0;
            end

            // Signal end of message
            @(negedge clk);
            msg_done = 1;
            @(posedge clk);
            msg_done = 0;
        end

        // === WAIT FOR DIGEST ===
        @(posedge digest_ready);
        @(posedge clk);   // Ensure stability

        print_digest("\nDigest calculated: ");

        $display("\n=== End test hash_top ===");
        $finish;
    end
endmodule
