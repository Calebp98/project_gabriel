
://github.com/Calebp98/project_gabriel

Hardware:
Pi pico (Microcontroller)
Icebreaker (FPGA)
Software:
Languages: Arduino sketches (ino), verilog, FPGA
Verification tool: SymbiYosys/yosys-smtbmc

Gabriel Project Pitch
Hey I’d love to get you quick thoughts on some ai for fpga fv /security projects which you bet one could prototype in a weekend and would be cool
0:11

Pick a super simple grammar which can be specified with a FSM. Then have the FPGA take serial in and out, but only allows through data which matches the grammar
0:14

And formally verify that the verilog implements the grammar
0:14

So read into a buffer. If the buffer overflows, reject and reset. Otherwise follow the FSM while filling the buffer and if the FSM lands on an "accept" state, empty the buffer to the output
0:15

heart

If you want to make it a bit more complicated (though honestly I think just getting familiar with the fv tools and doing the simple stream and buffer handling is already plenty for a weekend) then you could implement autocorrect using the method and tooling from here to generate the FSM:
- https://getreuer.info/posts/keyboards/autocorrection/#how-does-it-work
- https://docs.qmk.fm/features/autocorrect
13:01

Oh I think you want a deterministic finite automaton (DFA) specifically. But that's for accept/reject, not translation. You could also remove the serial out part and just flash a light if the input is accepted and a different one if rejected


Claude Explanation of Gabriel’s Pitch
This is a really cool FPGA security/formal verification project! Let me break it down:
What It Actually Means
You're building a hardware-based input validator that sits between an input source and output, only allowing data through if it matches a specific pattern/grammar. Think of it as a hardware firewall that physically blocks malformed data.
The key innovation: you're not just implementing this in hardware, you're formally verifying it - mathematically proving your FPGA design correctly implements the grammar rules, with no bugs.
Why It's Cool/Useful
Hardware security: Software filters can be bypassed/exploited. Hardware filters are much harder to compromise
Zero-day protection: Blocks malformed inputs that might exploit unknown vulnerabilities
Performance: FPGA processes data at wire speed with no CPU overhead
Formal verification: You get mathematical proof it works correctly - no "99% tested" - it's proven
Real-world applications: Protocol validators, SQL injection prevention, command filtering for embedded systems
The Steps Involved
Weekend Version (Simpler)
Choose a simple grammar (30 min)
Example: Only allow strings like "hello", "world", "hi" - nothing else
Define as a DFA (Deterministic Finite Automaton) - a state machine with accept/reject states
Design the Verilog module (2-3 hours)
Serial input pin receiving data byte-by-byte
Buffer to temporarily store incoming data
FSM logic that tracks which state you're in as bytes arrive
If buffer overflows → reject and reset
If FSM reaches "accept" state → output is allowed (light turns on or data passes through)
If FSM reaches "reject" state → blocked (different light)
Write the formal verification properties (2-3 hours)
Use tools like SymbiYosys/yosys-smtbmc
Specify assertions like: "if input matches grammar, output must be allowed"
"If buffer overflows, system must reject and reset"
"System never outputs data that doesn't match grammar"
Run formal verification (1-2 hours)
Let the tool mathematically prove your design is correct
Fix any bugs it finds
Iterate until proof succeeds
Test on actual FPGA (2-3 hours)
Flash to board, connect serial input
Send valid/invalid inputs, verify LEDs respond correctly
Extended Version (if you have more time)
Add the autocorrect feature using the QMK method:
Build a trie (tree structure) of valid words
As input arrives, traverse the trie
If you hit a typo that's close to a valid word, auto-correct it
This requires a more complex FSM that can handle "fuzzy matching"
Example Simple Grammar
Let's say you want to only accept the strings "cat", "dog", "bird":
States: START → C → CA → CAT(accept)
              → D → DO → DOG(accept)  
              → B → BI → BIR → BIRD(accept)

Any other sequence → REJECT state → no output
The FPGA literally implements this state machine in hardware, and formal verification proves it's implemented correctly!
This is genuinely a fantastic learning project - you get hands-on with FPGAs, formal methods, security, and digital design all at once. Want me to help you get started with any particular part?

Claude suggested wiring - not yet checked
Raspberry Pi Pico    →    iCEBreaker FPGA
=================         ================
GP0 (UART0 TX)      →    Pin 6 (RX on PMOD 1A)
GP1 (UART0 RX)      →    Pin 9 (TX on PMOD 1A) [optional]
GND                 →    GND (any GND pin on PMOD)

Important:
TX goes to RX (crossed connection!)
Both run at 3.3V - no level shifter needed
Must share common ground



Et's add another asset for http://2.vndic.net/index.php?word=%E4%BD%A0&dict=cn_vi See @tests/test_fetcher.py 
