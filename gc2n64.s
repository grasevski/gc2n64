; Adapter to convert gamecube controller to N64
.device attiny25
.equ PCMSK = 0x15
.equ PINB = 0x16
.equ DDRB = 0x17
.equ PORTB = 0x18
.equ WDTCR = 0x21
.equ CLKPR = 0x26
.equ OCR0A = 0x29
.equ OSCCAL = 0x31
.equ TCNT0 = 0x32
.equ TCCR0B = 0x33
.equ GIMSK = 0x3b
.equ TIMSK = 0x39
.equ n64 = 0
.equ gcc = 1
.equ n64l = 3
.equ gccl = 2
.def n64_0 = r16
.def n64_1 = r17
.def n64_2 = r18
.def n64_3 = r19
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
    sbi DDRB, @0
    sbrs @1, 7
    rjmp send_0_%
    .if @0 == gcc
        nop
    .endif
    cbi DDRB, @0
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
    cbi DDRB, @0
    .if @0 == gcc
        nop
    .endif
    brne send_bit_%
.endm

; Bit bang N64 stop bit to the console.
.macro n64_send_stop
    nop
    sbi DDRB, n64
    rjmp n64_stop_wait
.endm

; Read a bit from N64 console.
.macro n64_read
    sbrs gcc_0, 0
    out OSCCAL, gcc_1
    lsl gcc_0
    in gcc_1, OSCCAL
    delay_1_us
    sbis PINB, n64
    inc gcc_0
    sbic PINB, n64
    inc gcc_1
    nop
    nop
    sbis PINB, n64
    dec gcc_1
.endm

; Read bits from gamecube controller.
.macro gcc_read_bits
    ldi n64_0, @1
; Read one bit.
read_bit_%:
    lsl @0
    nop
    nop
    nop
    delay_1_us
    sbis PINB, gcc
    inc @0
    dec n64_0
    nop
    nop
    nop
    brne read_bit_%
.endm

; Read a byte from gamecube controller.
.macro gcc_read
    gcc_read_bits @0, 7
.endm

; Reset vector.
.org 0x0000
    rjmp reset

; Pin change interrupt when N64 console sends a request.
.org 0x0002
    rjmp pcint0

; TIMER0_COMPA interrupt when it is time to poll gamecube controller.
.org 0x000a
    dec gcc_1
    brne poll_gcc
    reti
; Waited long enough to poll the controller.
poll_gcc:
    ldi gcc_1, 0x40
    ldi gcc_2, 0x00
    ldi gcc_3, 0x03
    send_byte gcc, gcc_1
    send_byte gcc, gcc_2
    send_byte gcc, gcc_3
    clr gcc_0
    sbi DDRB, gcc
    nop
    nop
    nop
    cbi DDRB, gcc
; Detect the start of the gamecube controller response.
wait_for_low:
    sbis PINB, gcc
    rjmp read
    dec gcc_0
    brne wait_for_low
; Read the gamecube response.
read:
    clr gcc_0
    nop
    nop
    sbis PINB, gcc
    sbr gcc_0, 0
    nop
    delay_1_us
    gcc_read_bits gcc_0, 7
    gcc_read gcc_1
    gcc_read n64_2
    gcc_read n64_3
    gcc_read gcc_2
    gcc_read gcc_3
    clr n64_0
    clr n64_1
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
    ldi gcc_0, 0x80
    out CLKPR, gcc_0
    ldi gcc_0, 0x01
    out CLKPR, gcc_0
    sbi PCMSK, n64
    ldi gcc_0, 0x20
    out GIMSK, gcc_0
    ldi gcc_0, 5
    out TCCR0B, gcc_0
    ldi gcc_0, 130
    out OCR0A, gcc_0
    sbi DDRB, n64l
    sbi DDRB, gccl
    clr n64_0
    clr n64_1
    clr n64_2
    clr n64_3
    ldi gcc_1, 5
    sei
; Sleep and let interrupts do the work.
main:
    sleep
    rjmp main

; React to N64 request.
pcint0:
    cbi PORTB, n64l
    cbi PORTB, gccl
    clr gcc_0
    in gcc_1, OSCCAL
    n64_read
    n64_read
    n64_read
    n64_read
    n64_read
    n64_read
    n64_read
    sbrs gcc_0, 0
    out OSCCAL, gcc_1
    tst gcc_0
    breq status
    cpi gcc_0, 0x7f
    breq status
    cpi gcc_0, 1
    breq poll
    reti
; Send status response.
status:
    sbi PORTB, n64l
    ldi gcc_1, 5
    ldi gcc_2, 0
    ldi gcc_3, 2
    nop
    nop
    nop
    nop
    nop
    send_byte n64, gcc_1
    send_byte n64, gcc_2
    send_byte n64, gcc_3
    n64_send_stop
; Send poll response.
poll:
    sbi PORTB, gccl
    clr gcc_0
    out TCNT0, gcc_0
    sbr gcc_0, 4
    out TIMSK, gcc_0
    send_byte n64, n64_0
    send_byte n64, n64_1
    send_byte n64, n64_2
    send_byte n64, n64_3
    n64_send_stop
; Releases the N64 data line and returns.
n64_stop_wait:
    delay_1_us
    cbi DDRB, n64
    reti
