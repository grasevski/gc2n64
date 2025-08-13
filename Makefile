.PHONY: flash clean

# Assemble program.
gc2n64.s.hex: gc2n64.s
	avra $<

# Write program to attiny85 over USB.
flash: gc2n64.s.hex
	avrdude -c usbasp -p t85 -U flash:w:$<

# Delete assembler output.
clean:
	rm gc2n64.s.*
