; Adapter to convert gamecube controller to N64.
;.equ STUB_GCC = 1
.device attiny9
.equ T9 = 1
;.device attiny25

; Hardware Abstraction Layer.
.ifdef T9
    ; Interrupt vector mapping.
    .equ PCINT0 = 0x0002
    .equ TIM0_COMPA = 0x0005

    ; Register mapping.
    .equ PINB = 0x00
    .equ DDRB = 0x01
    .equ PCMSK = 0x10
    .equ PCIFR = 0x11
    .equ PCICR = 0x12
    .equ OCR0AL = 0x26
    .equ TCNT0L = 0x28
    .equ TIFR0 = 0x2a
    .equ TIMSK0 = 0x2b
    .equ CLKPSR = 0x36
    .equ SMCR = 0x3a
    .equ CCP = 0x3c

    ; Peripheral pin mapping.
    .equ PCIE0 = 0
    .equ SE = 0
    .equ SIG = 0xd8
    .equ OCF0A = 1
    .equ OCIE0A = 1
    .equ PCIF0 = 0

    ; Make it align with attiny25 timing.
    .macro set_bit
        nop
        sbi @0, @1
    .endm

    ; Make it align with attiny25 timing.
    .macro clr_bit
        nop
        cbi @0, @1
    .endm

    ; Sets up timer for gamecube interrupt.
    .macro tmr_init
        ldi gcc_0, 13
        out 0x2d, gcc_0
    .endm
.else
    ; Interrupt vector mapping.
    .equ PCINT0 = 0x0002
    .equ TIM0_COMPA = 0x000a

    ; Register mapping.
    .equ PINB = 0x16
    .equ DDRB = 0x17
    .equ PCMSK = 0x15
    .equ PCIFR = 0x3a
    .equ PCICR = 0x3b
    .equ OCR0AL = 0x29
    .equ TCNT0L = 0x32
    .equ TIFR0 = 0x38
    .equ TIMSK0 = 0x39
    .equ CLKPSR = 0x26
    .equ SMCR = 0x35
    .equ CCP = CLKPSR

    ; Peripheral pin mapping.
    .equ PCIE0 = 5
    .equ SE = 5
    .equ SIG = 1 << 7
    .equ OCF0A = 4
    .equ OCIE0A = 4
    .equ PCIF0 = 5

    ; Wrapper to ensure cycle counts match.
    .macro set_bit
        sbi @0, @1
    .endm

    ; Wrapper to ensure cycle counts match.
    .macro clr_bit
        cbi @0, @1
    .endm

    ; Sets up timer for gamecube interrupt.
    .macro tmr_init
        ldi gcc_0, 2
        out 0x2a, gcc_0
        ldi gcc_0, 5
        out 0x33, gcc_0
    .endm
.endif

; N64 data pin.
.equ n64 = 0

; Gamecube controller data pin.
.equ gcc = 1

; LED status pin.
.equ led = 2

; N64 response buffer.
.def n64_0 = r16
.def n64_1 = r17
.def n64_x = r18
.def n64_y = r19

; Gamecube controller temp variables.
.def gcc_0 = r20
.def gcc_1 = r21
.def gcc_cx = r22
.def gcc_cy = r23

; gcc_0 button mappings.
.equ gcc_0_a = 0
.equ gcc_0_b = 1
.equ gcc_0_x = 2
.equ gcc_0_y = 3
.equ gcc_0_s = 4

; gcc_1 button mappings.
.equ gcc_1_left = 0
.equ gcc_1_right = 1
.equ gcc_1_down = 2
.equ gcc_1_up = 3
.equ gcc_1_z = 4
.equ gcc_1_r = 5
.equ gcc_1_l = 6

; n64_0 button mappings.
.equ n64_0_a = 7
.equ n64_0_b = 6
.equ n64_0_z = 5
.equ n64_0_s = 4
.equ n64_0_up = 3
.equ n64_0_down = 2
.equ n64_0_left = 1
.equ n64_0_right = 0

; n64_1 button mappings.
.equ n64_1_reset = 7
.equ n64_1_l = 5
.equ n64_1_r = 4
.equ n64_1_cu = 3
.equ n64_1_cd = 2
.equ n64_1_cl = 1
.equ n64_1_cr = 0

; Low threshold for button press.
.equ analog_lo = 64

; High threshold for button press.
.equ analog_hi = 192

; Midpoint for gamecube analog.
.equ analog_mid = 128

; Map the same button on gamecube to N64.
.macro map
    map_button @1, @0, @2, @0
.endm

; Map a button on gamecube to N64.
.macro map_button
    sbrc @2, @2_@3
    ori @0, 1 << @0_@1
.endm

; Set a C button on N64.
.macro set_c
    ori n64_1, 1 << n64_1_c@0
.endm

; 4 NOPs at 4MHz is 1 microsecond.
.macro delay_1_us
    nop
    nop
    nop
    nop
.endm

; Bit bang a byte.
.macro send_byte
    ldi gcc_0, 8
; Bit bang one bit.
send_bit_%:
    set_bit DDRB, @0
    sbrs @1, 7
    rjmp send_0_%
    clr_bit DDRB, @0
    rjmp send_end_%
; Bit bang a 0 bit.
send_0_%:
    nop
    nop
    nop
; Release the line and send another bit if required.
send_end_%:
    lsl @1
    dec gcc_0
    nop
    nop
    clr_bit DDRB, @0
    brne send_bit_%
.endm

; Finish N64 response.
.macro send_stop
    nop
    set_bit DDRB, n64
    rjmp n64_request_done
.endm

; Read several bits.
.macro read_bits
    ldi @2, @3
; Wait until the line is low.
read_bit_%:
    sbis PINB, @0
    rjmp read_bit_value_%
    sbic PINB, @0
    rjmp read_bit_value_%
; Read one bit.
read_bit_value_%:
    lsl @1
    nop
    nop
    nop
    sbic PINB, @0
    inc @1
    dec @2
    nop
    nop
    nop
    brne read_bit_%
.endm

; Read a byte from gamecube controller.
.macro gcc_read
    read_bits gcc, @0, n64_0, 8
.endm

; Busy wait until the line is driven low.
.macro wait_for_low
    ; Unroll the busy loop for faster response time.
    .if @0 > 1
        sbis PINB, gcc
        rjmp read_bit_value
        wait_for_low @0 - 1
    .endif
.endm

; Reset vector.
.org 0x0000
    rjmp reset

; Pin change interrupt when N64 console sends a request.
.org PCINT0
    rjmp n64_request

; Interrupt when it is time to poll gamecube controller.
.org TIM0_COMPA
    ldi gcc_1, 0x40
    ldi gcc_cx, 0x03
    clr gcc_cy
    send_byte gcc, gcc_1
    send_byte gcc, gcc_cx
    send_byte gcc, gcc_cy
    clr gcc_0
    set_bit DDRB, gcc
    clr n64_1
    nop
    clr_bit DDRB, gcc
    delay_1_us
    nop
    nop
    gcc_read gcc_0
    gcc_read gcc_1
    gcc_read n64_x
    gcc_read n64_y
    gcc_read gcc_cx
    gcc_read gcc_cy
    clr n64_0

    ; Put in all zero values for gamecube controller.
    .ifdef STUB_GCC
        clr gcc_0
        clr gcc_1
        clr gcc_cx
        clr gcc_cy
        ldi n64_x, analog_mid
        ldi n64_y, analog_mid
    .endif

    map a, n64_0, gcc_0
    map b, n64_0, gcc_0
    map_button n64_0, z, gcc_1, l
    map s, n64_0, gcc_0
    map up, n64_0, gcc_1
    map down, n64_0, gcc_1
    map left, n64_0, gcc_1
    map right, n64_0, gcc_1
    map_button n64_1, l, gcc_0, y
    map r, n64_1, gcc_1
    map_button n64_1, cd, gcc_0, x
    cpi gcc_cx, analog_lo
    brsh not_c_left
    set_c l
; Right stick is not pushed to the left.
not_c_left:
    cpi gcc_cx, analog_hi
    brlo not_c_right
    set_c r
; Right stick is not pushed to the right.
not_c_right:
    cpi gcc_cy, analog_lo
    brsh not_c_down
    set_c d
; Right stick is not pushed downwards.
not_c_down:
    cpi gcc_cy, analog_hi
    brlo not_c_up
    set_c u
; Right stick is not pushed upwards.
not_c_up:
    subi n64_x, analog_mid
    subi n64_y, analog_mid
    sbrs n64_0, n64_0_s
    reti
    sbrs n64_1, n64_1_r
    reti
    sbrs n64_1, n64_1_l
    reti
    andi n64_0, ~(1 << n64_0_s)
    ori n64_1, 1 << n64_1_reset
    reti

; Configures registers.
reset:
    ldi gcc_0, SIG
    out CCP, gcc_0
    ldi gcc_0, 1
    out CLKPSR, gcc_0
    set_bit PCMSK, n64
    ldi gcc_0, 1 << PCIE0
    out PCICR, gcc_0
    tmr_init
    ldi gcc_0, 50
    out OCR0AL, gcc_0
    ldi gcc_0, 1 << SE
    out SMCR, gcc_0
    set_bit DDRB, led
    clr n64_0
    clr n64_1
    clr n64_x
    clr n64_y
    sei
; Sleep and let interrupts do the work.
main:
    sleep
    rjmp main

; React to N64 request.
n64_request:
    read_bits n64, gcc_0, gcc_1, 7
    andi gcc_0, 0x7f
    tst gcc_0
    breq status
    cpi gcc_0, 0x7f
    breq status
    cpi gcc_0, 1
    brne n64_request_done
    rjmp poll
; Clear interrupt flag and exit.
n64_request_done:
    clr_bit DDRB, n64
    nop
    nop
    ldi gcc_0, 1 << PCIF0
    out PCIFR, gcc_0
    reti
; Send status response.
status:
    set_bit PINB, led
    ldi gcc_1, 5
    ldi gcc_cx, 0
    ldi gcc_cy, 2
    send_byte n64, gcc_1
    send_byte n64, gcc_cx
    send_byte n64, gcc_cy
    send_stop
; Send poll response.
poll:
    clr gcc_0
    out TCNT0L, gcc_0
    ldi gcc_0, 1 << OCF0A
    out TIFR0, gcc_0
    ldi gcc_0, 1 << OCIE0A
    out TIMSK0, gcc_0
    send_byte n64, n64_0
    send_byte n64, n64_1
    send_byte n64, n64_x
    send_byte n64, n64_y
    send_stop
