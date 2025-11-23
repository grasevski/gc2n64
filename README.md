# gc2n64
Gamecube controller to N64 adapter. Dependencies:

 * [avra](https://github.com/Ro5bert/avra): `apt install avra` - AVR assembler
 * [avrdude](https://github.com/avrdudes/avrdude): `apt install avrdude` - to flash program to ATTiny
 * [KiCAD](https://www.kicad.org/): `apt install kicad` - for schematic
 * [ATTiny9](https://www.microchip.com/en-us/product/attiny9): SOT-23-6 is used for running the code. Attiny 25/45/85 can be used instead if preferred.

Usage:

```
# Build
make

# Flash to attiny9
make flash

# Delete build output
make clean
```

The KiCAD schematic is in the schematic directory. It has a TC2030-NL footprint for flashing and debugging. It is designed to be wired to two respective extension cables for gamecube and n64. Then it can be heatshrunk for neatness and stress relief.

![pcb](pcb.png)

![schematic](schematic.svg)
