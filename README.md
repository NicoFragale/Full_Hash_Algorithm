# Full Hash Algorithm v1 (AES S-Box Based)

This repository contains the complete implementation, verification, and FPGA deployment of a custom 64-bit cryptographic hash function based on the AES S-box transformation. The project was developed as part of the *Hardware and Embedded Security* course at the University of Pisa, Master’s Degree in Cybersecurity (A.Y. 2024/2025).

## 📜 Overview

The hash function processes an input message byte-by-byte, transforming an internal 64-bit state vector over multiple rounds using the AES S-box. It consists of two main phases:

1. **Message Processing** – Each input byte is processed through 36 transformation rounds.
2. **Finalization** – A final transformation is applied based on the message length, improving collision resistance.

## 🔧 Project Structure

### 1. High-Level Model
- A Python model (`HL_Model_Full_Hash_S_BOX.py`) simulates the hash algorithm to serve as a golden reference for hardware validation.
- Implements message and finalization phases.
- Supports edge cases including empty messages.

### 2. RTL Design (SystemVerilog)
- Modular and synthesizable implementation of the algorithm.
- Core modules include:
  - `control_fsm`: 6-state finite state machine for coordinating hash operations.
  - `hash_registers`: 8-register bank for internal state.
  - `shift_xor_unit` and `final_hash_unit`: XOR + circular shift logic.
  - `aes_sbox_lut`: Combinational AES S-box lookup.
  - `round_tracker`: Tracks iterations and transitions between rounds.
  - `hash_top`: Top-level integration module.

### 3. Functional Verification
- SystemVerilog testbenches for each module and the top-level system.
- Simulation scenarios include:
  - Nominal messages
  - Empty inputs
  - Edge condition tests
- Validated against the Python reference model and waveform analysis in ModelSim.

### 4. FPGA Synthesis (Cyclone V)
- Fully synthesized and fitted using Intel Quartus Prime.
- Timing closure achieved at **9.7 ns (≈103 MHz)**.
- Static Timing Analysis, fitter summaries, and pin assignments included.

## ✅ Features

- Fully asynchronous reset and byte-wise valid input.
- Internal message length counter integrated for finalization.
- 64-bit digest output ready signal (`digest_ready`).
- Clock-cycle-accurate control FSM.

## 📊 Results Summary

| Metric                     | Value                          |
|---------------------------|-------------------------------|
| Device                    | Intel Cyclone V (5CGXFC9D6F27C7) |
| Max Clock Frequency       | ~103 MHz                      |


## 🧠 Authors

- **[Range](https://github.com/NicoFragale)**
- **[Ex0DiUs](https://github.com/Ed3f)**

## 📚 Academic Info

**Course:** Hardware and Embedded Security  
**Program:** Master's Degree in Cybersecurity, University of Pisa  
**Academic Year:** 2024/2025

## 📜 License

This project is intended for academic purposes. Please contact the authors for reuse or modification permissions.
