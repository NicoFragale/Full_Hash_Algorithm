`timescale 1ns/1ps

module tb_round_tracker;

  // Segnali di test
  logic clk;
  logic reset_n;
  logic round_exec_active;
  logic final_round_active;
  logic [2:0] state; // Stato corrente della FSM
  logic [2:0] final_hash_state; // Stato finale della hash


  logic [2:0] i_count;
  logic [5:0] round_count;
  logic round_done;
  logic final_round_done;

  // Clock generation: 20 ns periodo (50 MHz)
  always #10 clk = ~clk;

  // Istanziazione del modulo sotto test (UUT)
  round_tracker uut (
    .clk(clk),
    .reset_n(reset_n),
    .round_exec_active(round_exec_active),
    .final_round_active(final_round_active),
    .state(state),
    .final_hash_state(final_hash_state),
    .i_count(i_count),
    .round_count(round_count),
    .round_done(round_done),
    .final_round_done(final_round_done)
  );

  // Stimoli
  initial begin
    $display("=== Test ROUND_TRACKER ===");

    // Inizializzazione
    clk = 0;
    reset_n = 0;
    round_exec_active = 0;
    final_round_active = 0;
    state = 3'd0;
    final_hash_state = 3'd4; // Supponiamo che FINAL_HASH sia lo stato 4
    
    #12;
    reset_n = 1;

    // Simula 36 round completi (36 * 8 = 288 cicli)
    round_exec_active = 1;
    for (int r = 0; r < 288; r++) begin
      @(posedge clk);
    end
    round_exec_active = 0;

    $display("Dopo round: i_count = %0d, round_count = %0d, round_done = %b", i_count, round_count, round_done);

    // Simula il final round (8 cicli)
    final_round_active = 1;
    for (int i = 0; i < 8; i++) begin
      @(posedge clk);
    end
    final_round_active = 0;

    $display("Dopo final round: i_count = %0d, final_round_done = %b", i_count, final_round_done);
    
    // Puoi anche cambiare lo stato se serve simulare lo stato final_hash
    state = final_hash_state;
    final_round_active = 1;
    for (int i = 0; i < 8; i++) begin
      @(posedge clk);
    end
    final_round_active = 0;

    $display("Dopo final round: i_count = %0d, final_round_done = %b", i_count, final_round_done);
    
    // Fine simulazione
    #10;
    $stop;
  end

endmodule