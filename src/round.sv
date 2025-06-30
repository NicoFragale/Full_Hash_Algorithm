// =============================================================================
// File        : round_tracker.sv
// Description : Tracks the internal round and step counters for the hash process
// =============================================================================

module round_tracker (
    input  logic        clk,                 // System clock
    input  logic        reset_n,             // Asynchronous active-low reset
    input  logic        round_exec_active,   // High when in the message-processing phase
    input  logic        final_round_active,  // High during final hash round with counter C[i]
    input  logic [2:0]  state,               // Current FSM state
    input  logic [2:0]  final_hash_state,    // Target FSM state for finalization
    output logic [2:0]  i_count,             // Index from 0 to 7, used in H[i] update
    output logic        round_done,          // Raised at the end of each 36-round block
    output logic        final_round_done     // Raised at the end of the final 8-round block
);

    // Counter for number of full rounds completed (0 to 35)
    logic [5:0] round_count;

    // Sequential logic for round and index counters
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset both counters asynchronously
            i_count <= 3'd0;
            round_count <= 6'd0;

        end else if (round_exec_active) begin
            // During message-processing rounds
            if (i_count == 3'd7) begin
                i_count <= 3'd0;                     // Reset step counter
                round_count <= round_count + 6'd1;   // Advance round counter
            end else begin
                i_count <= i_count + 3'd1;           // Increment step counter
            end

        end else if (final_round_active) begin
            // During finalization round using C[i]
            if (i_count < 3'd7)
                i_count <= i_count + 3'd1;
            // No increment if already at 7 — will be handled via final_round_done

        end else begin
            // Default reset between message sessions
            i_count <= 3'd0;
            round_count <= 6'd0;
        end
    end

    // Output raised after completing 8 steps during final hash phase
    assign final_round_done = (state == final_hash_state && i_count == 3'd7);

    // Output raised at the end of 36 rounds of message processing
    assign round_done = (round_exec_active && round_count == 6'd35 && i_count == 3'd7);

endmodule
