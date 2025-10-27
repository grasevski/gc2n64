.PHONY: flash clean

# Assemble program.
gc2n64.s.hex: gc2n64.s
	avra $<

# Write program to attiny9 over tagconnect.
flash: gc2n64.s.hex
	avrdude -c avrispmkii -p t9 -U flash:w:$<

# Delete assembler output.
clean:
	rm gc2n64.s.*
