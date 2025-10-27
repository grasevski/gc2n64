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
    .equ PORTB = 0x02
    .equ PCMSK = 0x10
    .equ PCIFR = 0x11
    .equ PCICR = 0x12
    .equ OCR0AL = 0x26
    .equ TCNT0L = 0x28
    .equ TIMSK0 = 0x2b
    .equ TCCR0B = 0x2d
    .equ TCCR0A = 0x2e
    .equ CLKPSR = 0x36
    .equ OSCCAL = 0x39
    .equ SMCR = 0x3a
    .equ CCP = 0x3c

    ; Peripheral pin mapping.
    .equ PCIE0 = 0
    .equ SE = 0
    .equ SIG = 0xd8
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
.else
    ; Interrupt vector mapping.
    .equ PCINT0 = 0x0002
    .equ TIM0_COMPA = 0x000a

    ; Register mapping.
    .equ PINB = 0x16
    .equ DDRB = 0x17
    .equ PORTB = 0x18
    .equ PCMSK = 0x15
    .equ PCIFR = 0x3a
    .equ PCICR = 0x3b
    .equ OCR0AL = 0x29
    .equ TCNT0L = 0x32
    .equ TIMSK0 = 0x39
    .equ TCCR0A = 0x2a
    .equ TCCR0B = 0x33
    .equ CLKPSR = 0x26
    .equ OSCCAL = 0x31
    .equ SMCR = 0x35
    .equ CCP = CLKPSR

    ; Peripheral pin mapping.
    .equ PCIE0 = 5
    .equ SE = 5
    .equ SIG = 1 << 7
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
.def n64_2 = r18
.def n64_3 = r19

; Gamecube controller temp variables.
.def gcc_0 = r20
.def gcc_1 = r21
.def gcc_2 = r22
.def gcc_3 = r23

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
    .if @0 == gcc
        nop
    .endif
    clr_bit DDRB, @0
    rjmp send_end_%
; Bit bang a 0 bit.
send_0_%:
    nop
    nop
    nop
    .if @0 == gcc
        nop
    .endif
; Release the line and send another bit if required.
send_end_%:
    lsl @1
    dec gcc_0
    nop
    nop
    .if @0 == gcc
        nop
        nop
    .endif
    clr_bit DDRB, @0
    .if @0 == gcc
        nop
    .endif
    brne send_bit_%
.endm

; Read several bits.
.macro read_bits
    ldi @2, @3
; Read one bit.
read_bit_%:
    lsl @1
    nop
    nop
    nop
    delay_1_us
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

; Reset vector.
.org 0x0000
    rjmp reset

; Pin change interrupt when N64 console sends a request.
.org PCINT0
    rjmp n64_request

; Interrupt when it is time to poll gamecube controller.
.org TIM0_COMPA
    ldi gcc_1, 0x40
    ldi gcc_2, 0x00
    ldi gcc_3, 0x03
    send_byte gcc, gcc_1
    send_byte gcc, gcc_2
    send_byte gcc, gcc_3
    clr gcc_0
    set_bit DDRB, gcc
    nop
    nop
    nop
    clr_bit DDRB, gcc
; Detect the start of the gamecube controller response.
wait_for_low:
    sbis PINB, gcc
    rjmp read
    dec gcc_0
    brne wait_for_low
; Read the gamecube response.
read:
    clr gcc_0
    clr n64_1
    nop
    sbis PINB, gcc
    inc gcc_0
    nop
    nop
    delay_1_us
    read_bits gcc, gcc_0, n64_0, 7
    gcc_read gcc_1
    gcc_read n64_2
    gcc_read n64_3
    gcc_read gcc_2
    gcc_read gcc_3
    clr n64_0

    ; Put in all zero values for gamecube controller.
    .ifdef STUB_GCC
        clr gcc_0
        clr gcc_1
        clr gcc_2
        clr gcc_3
        ldi n64_2, 128
        ldi n64_3, 128
    .endif

    sbrc gcc_0, 0
    sbr n64_0, 7
    sbrc gcc_0, 1
    sbr n64_0, 6
    sbrc gcc_0, 2
    sbr n64_1, 2
    sbrc gcc_0, 3
    sbr n64_1, 3
    sbrc gcc_0, 4
    sbr n64_0, 4
    sbrc gcc_1, 0
    sbr n64_0, 1
    sbrc gcc_1, 1
    sbr n64_0, 0
    sbrc gcc_1, 2
    sbr n64_0, 2
    sbrc gcc_1, 3
    sbr n64_0, 3
    sbrc gcc_1, 4
    sbr n64_0, 5
    sbrc gcc_1, 5
    sbr n64_1, 4
    sbrc gcc_1, 6
    sbr n64_1, 5
    ldi gcc_1, 5
    cpi gcc_2, 64
    brge not_c_left
    sbr n64_1, 1
; Right stick is not pushed to the left.
not_c_left:
    cpi gcc_2, 192
    brlt not_c_right
    sbr n64_1, 0
; Right stick is not pushed to the right.
not_c_right:
    cpi gcc_3, 64
    brge not_c_down
    sbr n64_1, 2
; Right stick is not pushed downwards.
not_c_down:
    cpi gcc_3, 192
    brlt not_c_up
    sbr n64_1, 3
; Right stick is not pushed upwards.
not_c_up:
    subi n64_2, 128
    subi n64_3, 128
    sbrs n64_0, 4
    reti
    sbrs n64_1, 4
    reti
    sbrs n64_1, 5
    reti
    cbr n64_0, 4
    sbr n64_1, 7
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
    ldi gcc_0, 2
    out TCCR0A, gcc_0
    ldi gcc_0, 5
    out TCCR0B, gcc_0
    ldi gcc_0, 64
    out OCR0AL, gcc_0
    ldi gcc_0, 1 << SE
    out SMCR, gcc_0
    set_bit DDRB, led
    clr n64_0
    clr n64_1
    clr n64_2
    clr n64_3
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
    breq poll
; Clear interrupt flag and exit.
n64_request_done:
    delay_1_us
    clr_bit DDRB, n64
    nop
    nop
    ldi gcc_0, 1 << PCIF0
    out PCIFR, gcc_0
    reti
; Send status response.
status:
    set_bit PINB, led
    ldi n64_1, 5
    ldi n64_2, 0
    ldi n64_3, 2
    rjmp n64_send_1
; Send poll response.
poll:
    clr gcc_0
    out TCNT0L, gcc_0
    sbr gcc_0, OCIE0A
    out TIMSK0, gcc_0
    send_byte n64, n64_0
; Send remaining response bytes.
n64_send_1:
    send_byte n64, n64_1
    send_byte n64, n64_2
    send_byte n64, n64_3
    nop
    set_bit DDRB, n64
    rjmp n64_request_done
