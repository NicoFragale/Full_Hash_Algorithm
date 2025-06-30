module hash_top (
    input  logic clk,                // System clock
    input  logic reset_n,            // Active-low asynchronous reset
    input  logic start_msg,          // Signal to start a new hashing session
    input  logic [7:0] msg_byte,     // 8-bit message byte input
    input  logic msg_done,           // Indicates completion of message input
    input  logic valid_in,           // Indicates validity of msg_byte
    output logic round_exec_active,  // High when a round transformation is in progress
    output logic load_byte,          // Asserted to latch msg_byte into internal register
    output logic [7:0] digest [7:0], // 64-bit final hash digest (unpacked into 8 bytes)
    output logic digest_ready        // High when digest is finalized and ready
);

    // === Internal control signals from control_fsm ===
    logic round_done;                // Asserted when a round finishes
    logic final_round_done;         // Asserted after final round using C[i] counter bytes
    logic init_H;                   // Triggers initialization of hash registers to IV
    logic use_counter;              // Switches data path input from msg_byte to C[i]
    logic final_round_active;       // High during the final round using length counter
    logic update_H;                 // Triggers update to H[i] register with new S-box output
    logic [2:0] state;              // Current state of the FSM
    logic [2:0] final_hash_state;   // State constant marking final hashing stage

    // === From round_tracker ===
    logic [2:0] i_count;            // Loop index counter for 8 rounds

    // === From hash_registers ===
    logic [7:0] H_update;           // Value to write to hash register H[i]
    logic [7:0] H_out[0:7];         // Current content of all 8 hash registers
    logic [7:0] H_next;             // H[(i+1)%8], used in transformation logic
    logic [7:0] byte_in;            // Active input byte, either msg_byte or C[i]
    logic [7:0] shift_xor_out;      // Output of shift_xor_unit
    logic [7:0] C_byte[0:7];        // Byte-length counter array (used as C[i])
    logic [7:0] sbox_input_final;   // Input byte to the S-box during finalization

    // === S-box internal wiring ===
    logic [7:0] sbox_input;         // Input to AES S-box
    logic [7:0] sbox_out;           // Output from AES S-box

    // === Internal registers ===
    logic clear_byte_counter;       // Reset signal for byte counter
    logic [7:0] byte_in_reg;        // Latched version of incoming message byte
    logic [63:0] msg_byte_counter;  // Counts number of processed input bytes
    logic [63:0] byte_len;          // Holds total length of message in bytes
    

    // === Local state encoding (mirrors FSM states) ===
    localparam IDLE       = 3'd0;
    localparam INIT       = 3'd1;
    localparam LOAD_BYTE  = 3'd2;
    localparam ROUND_EXEC = 3'd3;
    localparam FINAL_HASH = 3'd4;
    localparam FINALIZE   = 3'd5;

    // === FSM instantiation ===
    control_fsm fsm (
        .clk(clk),
        .reset_n(reset_n),
        .start_msg(start_msg),
        .msg_done(msg_done),
        .round_done(round_done),
        .final_round_done(final_round_done),
        .valid_in(valid_in),
        .init_H(init_H),
        .load_byte(load_byte),
        .use_counter(use_counter),
        .round_exec_active(round_exec_active),
        .digest_ready(digest_ready),
        .final_round_active(final_round_active),
        .update_H(update_H),
        .state(state),
        .final_hash_state(final_hash_state)
    );

    // === Hash register bank ===
    hash_registers regs (
        .clk(clk),
        .reset_n(reset_n),
        .init_H(init_H),
        .update_H(update_H),
        .i_count(i_count),
        .H_update(H_update),
        .H_out(H_out)
    );
    assign H_next = H_out[(i_count + 3'd1) % 8];  // Circular reference for transformation

    // === Shift-and-XOR unit ===
    shift_xor_unit u_shift (
        .H_next(H_next),
        .byte_in(byte_in),
        .i_count(i_count),
        .shift_xor_out(shift_xor_out)
    );

    // === AES S-box instantiation ===
    aes_sbox_lut u_sbox (
        .sbox_input(sbox_input),
        .sbox_out(sbox_out)
    );
    assign sbox_input = (use_counter) ? sbox_input_final : shift_xor_out;
    assign H_update = sbox_out;

    // === Final hash transformation using length counter ===
    final_hash_unit final_unit (
        .H_next(H_next),
        .C_byte(C_byte),
        .i_count(i_count),
        .sbox_input_final(sbox_input_final)
    );

    // === Round tracker module (i and round counters) ===
    round_tracker tracker (
        .clk(clk),
        .reset_n(reset_n),
        .round_exec_active(round_exec_active),
        .final_round_active(final_round_active),
        .state(state),
        .final_hash_state(final_hash_state),
        .i_count(i_count),
        .round_done(round_done),
        .final_round_done(final_round_done)
    );

    // === Byte counter logic ===
    assign clear_byte_counter = (state == INIT);  // Reset counter at the start of a new message

    // Counts the number of valid bytes processed during message input
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            msg_byte_counter <= 64'd0;               // Asynchronous reset
        else if (clear_byte_counter)
            msg_byte_counter <= 64'd0;               // Reset in INIT state
        else if (load_byte && valid_in)
            msg_byte_counter <= msg_byte_counter + 64'd1; // Increment on valid loaded byte
    end

    assign byte_len = msg_byte_counter;  // Alias for use in finalization phase


    // === C[i] Builder: Loads the 64-bit message length into an 8-byte array ===
    // This register array holds the big-endian representation of the total message length.
    // It is populated during the final round phase and used as the input to the final hash computation.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            C_byte <= '{default:8'h00};
        else if (final_round_active) begin
            C_byte[0] <= byte_len[63:56];
            C_byte[1] <= byte_len[55:48];
            C_byte[2] <= byte_len[47:40];
            C_byte[3] <= byte_len[39:32];
            C_byte[4] <= byte_len[31:24];
            C_byte[5] <= byte_len[23:16];
            C_byte[6] <= byte_len[15:8 ];
            C_byte[7] <= byte_len[7 :0 ];
        end
    end

    // === Input byte capture ===
    // This register holds the input byte from the message stream.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            byte_in_reg <= 8'h00;
        else if (load_byte)
            byte_in_reg <= msg_byte;
    end
    assign byte_in = (use_counter) ? C_byte[i_count] : byte_in_reg;

    // === Digest output assignment (packed) ===
    assign {digest[7], digest[6], digest[5], digest[4], digest[3], digest[2], digest[1], digest[0]} =
           (digest_ready) ? {H_out[7], H_out[6], H_out[5], H_out[4], H_out[3], H_out[2], H_out[1], H_out[0]} : 64'd0;

endmodule
