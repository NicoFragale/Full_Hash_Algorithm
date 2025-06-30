// =============================================================================
// File        : hash_registers.v
// Description : Array of 8 8-bit registers that store H[0..7], used as the internal
//               hash state. Supports asynchronous reset, initialization with IV,
//               and controlled per-byte update based on i_count.
// =============================================================================

module hash_registers (
    input  logic        clk,         // System clock
    input  logic        reset_n,     // Asynchronous active-low reset
    input  logic        init_H,      // Initializes hash state to IV (used at start of each message)
    input  logic        update_H,    // Enables update of H[i_count] with new value
    input  logic [2:0]  i_count,     // Selects which register H[i] to update
    input  logic [7:0]  H_update,    // New byte to be written into H[i_count]
    output logic [7:0]  H_out [0:7]  // Outputs the current state of all H registers
);

    // Initial Vector (IV) used to seed H[i] at the beginning of each hashing session
    localparam logic [7:0] IV [0:7] = '{
        8'h11,  // H[0]
        8'hA3,  // H[1]
        8'h1F,  // H[2]
        8'h3A,  // H[3]
        8'hCC,  // H[4]
        8'h84,  // H[5]
        8'hCC,  // H[6]
        8'hA0   // H[7]
    };

    integer i;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // On global reset, initialize all H[i] registers to the IV
            for (i = 0; i < 8; i++)
                H_out[i] <= IV[i];
        end else if (init_H) begin
            // When init_H is asserted (FSM in INIT), reload the IV
            for (i = 0; i < 8; i++)
                H_out[i] <= IV[i];
        end else if (update_H) begin
            // When update_H is asserted, update H[i_count] with the new value
            H_out[i_count] <= H_update;
        end
        // Otherwise, keep previous values
    end

endmodule 

// =============================================================================
// File        : shift_xor_unit.v
// Description : Combinational unit that computes the transformation
//               (H[(i+1)%8] ⊕ M) <<< i.
//               Used during the message-processing phase of hashing.
// =============================================================================

module shift_xor_unit (
    input  logic [7:0]  H_next,        // Input H[(i+1)%8] from hash_registers
    input  logic [7:0]  byte_in,       // Current message byte M
    input  logic [2:0]  i_count,       // Index i used for rotation
    output logic [7:0]  shift_xor_out  // Output to be fed to S-box
);

    logic [7:0] comb_val;

    always_comb begin
        // First XOR between H and message byte
        comb_val = H_next ^ byte_in;

        // Then perform a left circular shift by i_count bits
        shift_xor_out = ((comb_val << i_count) | 
                        (comb_val >> (8 - i_count))) & 8'hFF;
    end

endmodule


// =============================================================================
// File        : final_hash_unit.v
// Description : Combinational unit that processes the finalization round,
//               using the message length counter C[i] instead of message bytes.
//               Applies the same transformation logic used in message processing.
// =============================================================================

module final_hash_unit (
    input  logic [7:0]  H_next,               // H[(i+1)%8] value
    input  wire  [7:0]  C_byte[0:7],          // Byte-wise counter representing message length
    input  logic [2:0]  i_count,              // Current index i (0 to 7)
    output logic [7:0]  sbox_input_final      // Output to be fed into the AES S-box
);

    logic [7:0] xor_result;

    always_comb begin
        // XOR with corresponding byte of the message-length counter
        xor_result = H_next ^ C_byte[i_count];

        // Apply left circular shift by i_count bits
        sbox_input_final = ((xor_result << i_count) |
                           (xor_result >> (8 - i_count))) & 8'hFF;
    end

endmodule
