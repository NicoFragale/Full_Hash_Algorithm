module control_fsm (
    input  logic clk,                  // System clock
    input  logic reset_n,              // Asynchronous active-low reset
    input  logic start_msg,            // Signals the start of a new hashing session
    input  logic msg_done,             // Indicates that all message bytes have been sent
    input  logic round_done,           // Indicates that the current round has completed
    input  logic final_round_done,     // Indicates that the final round using the counter has completed
    input  logic valid_in,             // Indicates that the input byte is valid

    output logic init_H,               // Initializes the hash state H with predefined IV
    output logic load_byte,            // Loads the message byte into internal register
    output logic use_counter,          // Selects the counter as input instead of message byte (used in finalization)
    output logic round_exec_active,    // Signals that a hash round is currently executing
    output logic digest_ready,         // Indicates that the digest output is stable and ready
    output logic final_round_active,   // Signals that we are in the final round using the message length counter
    output logic update_H,             // Enables update of the hash register H[i]
    output logic [2:0] state,          // Exposes the current FSM state externally
    output logic [2:0] final_hash_state // Exposes the FINAL_HASH state as a constant
);

    typedef enum logic [2:0] {
        IDLE,         // Waits for start signal
        INIT,         // Initializes internal state H[i]
        LOAD_BYTE,    // Waits for and loads the next message byte
        ROUND_EXEC,   // Performs hash rounds per byte
        FINAL_HASH,   // Performs one final round using the message length counter
        FINALIZE      // Indicates that the digest is complete
    } state_t;

    state_t current_state, next_state;
    logic msg_done_latched; // Latched version of msg_done to persist its assertion until FINAL_HASH

    // Sequential logic: updates current state and latches msg_done
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state      <= IDLE;
            msg_done_latched   <= 1'b0;
        end
        else begin
            current_state <= next_state;
            // Latch msg_done until we exit the FINAL_HASH state
            if (msg_done)
                msg_done_latched <= 1'b1;
            else if (current_state == FINAL_HASH && round_done) 
                msg_done_latched <= 1'b0;
        end
    end

    // Assign visible state outputs
    assign state = current_state;
    assign final_hash_state = FINAL_HASH; // Constant signal to identify FINAL_HASH externally

    // FSM combinational logic: next state and output signals
    always_comb begin
        // Default deassertion of all control signals
        init_H             = 0;
        load_byte          = 0;
        update_H           = 0;
        digest_ready       = 0;
        use_counter        = 0;
        final_round_active = 0;
        round_exec_active  = 0;

        next_state = current_state;

        // FSM state transitions and outputs
        case (current_state)
            IDLE: begin
                // Wait for start_msg signal to begin a new hash
                if (start_msg)  begin
                    if (msg_done)
                        // If the message is empty, skip directly to finalization
                        next_state = FINAL_HASH;
                    else
                        // Otherwise, go to initialization
                        next_state = INIT;
                end
            end

            INIT: begin
                init_H = 1;                 // Reset H[i] registers to initial IV
                next_state = LOAD_BYTE;     // Proceed to message byte loading
            end

            LOAD_BYTE: begin
                // Wait for a valid byte to be provided
                if (valid_in) begin
                    load_byte = 1;          // Trigger byte load
                    next_state = ROUND_EXEC;
                end else begin
                    next_state = LOAD_BYTE; // Stay here until byte is valid
                end
            end

            ROUND_EXEC: begin
                update_H = 1;               // Enable hash state update
                round_exec_active = 1;      // Signal that round is in progress
                if (round_done)
                    // If message is done, move to FINAL_HASH; else process next byte
                    next_state = (msg_done_latched) ? FINAL_HASH : LOAD_BYTE;
                else
                    next_state = ROUND_EXEC; // Stay in round until it completes
            end

            FINAL_HASH: begin
                update_H = 1;               // Enable hash update
                use_counter = 1;            // Use message length counter instead of input byte
                final_round_active = 1;     // Signal that this is the final round
                if ( final_round_done )
                    next_state = FINALIZE;  // If final round completes, go to finalization
                else
                    next_state = FINAL_HASH;
            end

            FINALIZE: begin
                digest_ready = 1;           // Output hash is ready and valid
                next_state = IDLE;          // Return to IDLE, ready for new message
            end

            default:
                next_state = IDLE;          // Safe fallback in case of undefined state
        endcase
    end
endmodule
