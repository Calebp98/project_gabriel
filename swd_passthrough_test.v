// Simple SWD Passthrough for testing
// This just passes signals through with a basic enable switch
// No authentication yet - just proving the concept works

module swd_passthrough_test (
    // Control
                                // Can wire to button, switch, or tie HIGH for testing

    // SWD signals from Picoprobe
    input wire swclk_in,         // From Picoprobe GP2
    inout wire swdio_probe,      // From Picoprobe GP3

    // SWD signals to Target Pico
    output wire swclk_out,       // To Target SWCLK
    inout wire swdio_target,     // To Target SWDIO

    // Optional status LED
    output wire led_status       // Shows when enabled
);

    wire enable = 1'b1; // Always enabled
    // ===== SWCLK Passthrough =====
    // SWCLK is unidirectional (Picoprobe -> Target only)
    // When enabled: pass through
    // When disabled: hold low to prevent clocking
    assign swclk_out = enable ? swclk_in : 1'b0;


    // ===== SWDIO Bidirectional Passthrough =====
    // SWDIO needs to work both directions:
    // - Picoprobe drives when sending commands/data
    // - Target drives when responding
    // When enabled: connect both sides (tri-state)
    // When disabled: both sides high-impedance (disconnected)

    assign swdio_target = enable ? swdio_probe : 1'bz;
    assign swdio_probe = enable ? swdio_target : 1'bz;


    // ===== Status LED =====
    // LED on when passthrough is enabled
    assign led_status = enable;

endmodule


// ===== TESTING INSTRUCTIONS =====
//
// 1. Initial Test - Always Enabled:
//    Wire the 'enable' input HIGH (to VCC/3.3V)
//    This makes the FPGA always pass signals through
//    Test that OpenOCD can program the target
//
// 2. Switch Test:
//    Connect 'enable' to a physical switch or button
//    Verify programming only works when switch is ON
//
// 3. Pin Connections:
//    Picoprobe GP2 (SWCLK) → swclk_in
//    Picoprobe GP3 (SWDIO) → swdio_probe
//    Picoprobe GND         → FPGA GND
//
//    FPGA swclk_out        → Target SWCLK (debug header)
//    FPGA swdio_target     → Target SWDIO (debug header)
//    FPGA GND              → Target GND
//
//    FPGA enable           → Tie HIGH for testing (or switch)
//    FPGA led_status       → LED + 220Ω resistor → GND
//
// 4. Verification:
//    Run: openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
//         -c "init" -c "targets" -c "exit"
//
//    Should see successful connection if enable is HIGH
//
// 5. Next Steps:
//    Once this works, we'll add the authentication logic
//    that controls the 'enable' signal


// ===== NOTES =====
//
// Tri-state explanation:
// - 1'b0 = drive low
// - 1'b1 = drive high
// - 1'bz = high impedance (don't drive, let other side control)
//
// For SWDIO bidirectional:
// - When enable=1: both assigns use 'bz, creating a connection
// - When enable=0: both sides are 'bz (fully disconnected)
//
// The key is that when we're not driving (using 'bz),
// the other side can drive, and we can read it
