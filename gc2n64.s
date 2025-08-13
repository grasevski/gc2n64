; Adapter to convert gamecube controller to N64
.device attiny25
.equ PCMSK = 0x15
.equ PINB = 0x16
.equ DDRB = 0x17
.equ PORTB = 0x18
.equ WDTCR = 0x21
.equ CLKPR = 0x26
.equ GIMSK = 0x3b
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
    ldi @2, 8
; Bit bang one bit.
send_bit_%:
    sbi DDRB, @1
    sbrs @0, 7
    rjmp send_0_%
    .if @1 == gcc
        nop
    .endif
    cbi DDRB, @1
    rjmp send_end_%
; Bit bang a 0 bit.
send_0_%:
    nop
    nop
    nop
    .if @1 == gcc
        nop
    .endif
; Release the line and send another bit if required.
send_end_%:
    lsl @0
    dec @2
    nop
    nop
    .if @1 == gcc
        nop
        nop
    .endif
    cbi DDRB, @1
    .if @1 == gcc
        nop
    .endif
    brne send_bit_%
.endm

; Bit bang a byte to gamecube controller.
.macro gcc_send
    send_byte @0, gcc, n64_3
.endm

; Bit bang a byte to N64 console.
.macro n64_send
    send_byte @0, n64, gcc_0
.endm

; Bit bang N64 stop bit to the console.
.macro n64_send_stop
    nop
    sbi DDRB, n64
    rjmp n64_stop_wait
.endm

; Read bits from either N64 console or gamecube controller.
.macro read_bits
    ldi @2, @3
; Read one bit.
read_bit_%:
    lsl @1
    nop
    nop
    nop
    delay_1_us
    sbis PINB, @0
    inc @1
    dec @2
    nop
    nop
    nop
    brne read_bit_%
.endm

; Read a byte from either N64 console or gamecube controller.
.macro read_byte
    read_bits @0, @1, @2, 8
.endm

; Reset vector.
.org 0x0000
    rjmp reset

; Pin change interrupt when N64 console sends a request.
.org 0x0002
    rjmp pcint0

; Watchdog timer interrupt when it is time to poll gamecube controller.
.org 0x000c
    ldi n64_0, 0x40
    ldi n64_1, 0x00
    ldi n64_2, 0x03
    gcc_send n64_0
    gcc_send n64_1
    gcc_send n64_2
    nop
    sbi DDRB, gcc
    nop
    nop
    nop
    cbi DDRB, gcc
; Detect the start of the gamecube controller response.
wait_for_low:
    sbis PINB, gcc
    rjmp read
    dec gcc_1
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
    read_bits gcc, gcc_0, n64_0, 7
    read_byte gcc, gcc_1, n64_0
    read_byte gcc, n64_2, n64_0
    read_byte gcc, n64_3, n64_0
    read_byte gcc, gcc_2, n64_0
    read_byte gcc, gcc_3, n64_0
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
    sbi DDRB, n64l
    sbi DDRB, gccl
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
    delay_1_us
    read_bits n64, gcc_0, gcc_1, 7
    delay_1_us
    delay_1_us
    nop
    nop
    cpi gcc_0, 1
    brne status
    rjmp poll
; Send status response.
status:
    sbi PORTB, n64l
    ldi n64_0, 5
    ldi n64_1, 0
    ldi n64_2, 2
    nop
    nop
    n64_send n64_0
    n64_send n64_1
    n64_send n64_2
    n64_send_stop
; Send poll response.
poll:
    sbi PORTB, gccl
    ldi gcc_0, 0x18
    out WDTCR, gcc_0
    ldi gcc_0, 0x40
    out WDTCR, gcc_0
    n64_send n64_0
    n64_send n64_1
    n64_send n64_2
    n64_send n64_3
    n64_send_stop
; Releases the N64 data line and returns.
n64_stop_wait:
    delay_1_us
    cbi DDRB, n64
    reti
