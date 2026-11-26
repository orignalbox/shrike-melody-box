# shrike-melody-box

a music box in fpga logic, with no cpu.

plays two 16-note melodies on a piezo disc using only counters, a lookup table, and a PWM envelope inside the Renesas ForgeFPGA (SLG47910V) on the Vicharak Shrike Lite. the RP2040 only loads the bitstream — after that, the sound comes from logic alone.

## what it does

- two songs: ode to joy (opening) and a c major arpeggio up and down
- a button switches between them
- each note fades out like a plucked string (PWM envelope)
- about 85 lines of verilog

## wiring

| part | goes to |
| --- | --- |
| piezo red, through 100 Ω resistor | FPGA_IO0 (GPIO0, PIN 13) |
| piezo black | FPGA_IO1 (GPIO1, PIN 14) |
| button, one leg | FPGA_IO2 (GPIO2, PIN 15) |
| button, other leg | GND |

GPIO2 has its internal pull-up enabled.

## building

1. open the project in [Go Configure](https://www.renesas.com/en/products/programmable-mixed-signal-asic-ip-products/forgefpga-slg47910#tab-tools) (ForgeFPGA Workshop v6.55)
2. add `melody.v` as custom code under Source Code → Custom Code
3. map the ports in the I/O Planner:
   - `clk` → OSC_CLK
   - `clk_en` → OSC_EN
   - `piezo_p` → GPIO0_OUT
   - `piezo_p_en` → GPIO0_OE
   - `piezo_n` → GPIO1_OUT
   - `piezo_n_en` → GPIO1_OE
   - `btn_n` → GPIO2_IN
4. set GPIO0, GPIO1 as push-pull outputs; GPIO2 as pull-up input
5. Synthesize → Generate Bitstream

## flashing

```
cd build/bitstream
mpremote cp FPGA_bitstream_MCU.bin :
mpremote exec "import shrike; shrike.flash('FPGA_bitstream_MCU.bin')"
```

to auto-load on every power-up:

```
printf "import shrike\nshrike.flash('FPGA_bitstream_MCU.bin')\n" > main.py
mpremote cp main.py :
```

## how it works

the FPGA's internal oscillator runs at 50 MHz. a note at frequency f is a square wave that flips every `25,000,000 / f` clocks. a tick counter steps through 16 notes at ~168 ms each. a case statement maps each index to a half-period value (0 = rest).

each note starts at full volume and fades: an 8-bit envelope counter starts at 255 and counts down. a fast 8-bit PWM counter gates the tone — the output is on only while `pwm < env`. as `env` falls, the duty cycle shrinks and the note gets quieter.

the piezo is driven differentially — `piezo_p` and `piezo_n` are opposites while active, doubling the voltage swing and volume. when the note is off, both pins go to 0 (no DC across the piezo).

## license

MIT
