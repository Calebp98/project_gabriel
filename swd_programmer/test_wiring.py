#!/usr/bin/env python3
"""
Interactive wiring test - helps verify physical connections.
"""

import sys
from swd_bridge import SWDBridge
import time


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 test_wiring.py <serial_port>")
        sys.exit(1)

    port = sys.argv[1]

    print("=" * 60)
    print("Interactive Wiring Test")
    print("=" * 60)
    print()
    print("This script will toggle GPIO pins so you can verify connections")
    print("with a multimeter or LED.")
    print()

    with SWDBridge(port) as bridge:
        # Test SWCLK
        print("TEST 1: SWCLK (Bridge GP2)")
        print("-" * 40)
        print("Bridge GP2 should be toggling HIGH/LOW repeatedly.")
        print("Measure with multimeter on:")
        print("  - Bridge: Physical pin 4 (GP2)")
        print("  - Target: Physical pin 29 (GPIO 24)")
        print()
        print("If connected correctly, BOTH pins should toggle.")
        print()
        input("Press Enter to start SWCLK test (Ctrl+C to stop)...")

        try:
            print("Toggling SWCLK... (press Ctrl+C to stop)")
            while True:
                bridge.swclk_high()
                print("SWCLK = HIGH", end='\r')
                time.sleep(0.5)
                bridge.swclk_low()
                print("SWCLK = LOW ", end='\r')
                time.sleep(0.5)
        except KeyboardInterrupt:
            print("\nStopped                    ")
            bridge.swclk_low()

        print()
        input("Did you see voltage toggling? Press Enter to continue...")
        print()

        # Test SWDIO output
        print("TEST 2: SWDIO Output (Bridge GP3)")
        print("-" * 40)
        print("Bridge GP3 should be toggling HIGH/LOW repeatedly.")
        print("Measure with multimeter on:")
        print("  - Bridge: Physical pin 5 (GP3)")
        print("  - Target: Physical pin 34 (GPIO 25)")
        print()
        print("If connected correctly, BOTH pins should toggle.")
        print()
        input("Press Enter to start SWDIO test (Ctrl+C to stop)...")

        bridge.swdio_output()
        try:
            print("Toggling SWDIO... (press Ctrl+C to stop)")
            while True:
                bridge.swdio_high()
                print("SWDIO = HIGH", end='\r')
                time.sleep(0.5)
                bridge.swdio_low()
                print("SWDIO = LOW ", end='\r')
                time.sleep(0.5)
        except KeyboardInterrupt:
            print("\nStopped                    ")
            bridge.swdio_low()

        print()
        input("Did you see voltage toggling? Press Enter to continue...")
        print()

        # Test SWDIO input (loopback test)
        print("TEST 3: SWDIO Loopback Test")
        print("-" * 40)
        print("This tests if SWDIO can read what it writes.")
        print()
        print("On the TARGET Pico, temporarily short:")
        print("  GPIO 24 (pin 29) to GPIO 25 (pin 34)")
        print()
        print("This creates a loopback: SWCLK drives SWDIO.")
        print()
        input("When shorted, press Enter to test...")

        # Set SWDIO to input mode
        bridge.swdio_input()

        # Test loopback
        success_count = 0
        fail_count = 0

        for i in range(10):
            # Set SWCLK high, expect to read high on SWDIO
            bridge.swclk_high()
            time.sleep(0.01)
            bit = bridge.swdio_read()
            if bit:
                success_count += 1
                print(f"  Test {i+1}: SWCLK=HIGH, SWDIO read=HIGH ✓")
            else:
                fail_count += 1
                print(f"  Test {i+1}: SWCLK=HIGH, SWDIO read=LOW ✗ (expected HIGH)")

            # Set SWCLK low, expect to read low on SWDIO
            bridge.swclk_low()
            time.sleep(0.01)
            bit = bridge.swdio_read()
            if not bit:
                success_count += 1
                print(f"  Test {i+1}: SWCLK=LOW,  SWDIO read=LOW ✓")
            else:
                fail_count += 1
                print(f"  Test {i+1}: SWCLK=LOW,  SWDIO read=HIGH ✗ (expected LOW)")

        print()
        print(f"Results: {success_count} passed, {fail_count} failed out of 20 tests")
        print()

        if fail_count == 0:
            print("✓ PERFECT! Loopback works. Wiring is good.")
            print()
            print("Remove the short and try SWD communication again.")
        elif success_count == 0:
            print("✗ FAILED! No loopback detected.")
            print()
            print("Possible issues:")
            print("  1. Wires not actually connected to target pins")
            print("  2. Wrong pins on bridge Pico")
            print("  3. Broken wires")
        else:
            print("⚠ PARTIAL! Some tests passed.")
            print("  Could be intermittent connection or noise.")

        print()
        print("=" * 60)
        print("Wiring Test Complete")
        print("=" * 60)


if __name__ == '__main__':
    main()
