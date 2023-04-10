;
; sega genesis tmss killer for attiny85
; (you MUST run this in 16 MHz mode)
;
; attiny85 pin configuration...
;               _____
;         n/c -|  u  |- VCC
;    FAIL LED -|     |- from /CART_CE (B17)
; SUCCESS LED -|     |- to transistor
;         GND -|_____|- from /CART_IN (B32)
;
; see readme.md please.

	.include "tn85def.inc"

	.cseg
	.org 0x0000
	rjmp Start
	rjmp Irq
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here
	rjmp _should_not_be_here


_should_not_be_here:
	reti


;
; Interrupt handler, to fire when /CART_CE goes low.
;
Irq:
	; the very first opcode to run when the interrupt fires
	; must be the one that drives /VRES low
	; or else the reset will happen way too late.
	out PORTB,r28		; PB1 goes high, driving transistors on
	cli			; kill interrupts
	rcall ResetBurnCycles   ; wait a few cycles for /RESET to kick in
	out PORTB,r27           ; PB1 goes low, transistors turn off

	; indicate "success"
	ldi r20,(1 << PB4)
	out PORTB,r20
	
	; go into coma
	sleep
_irq_halt_loop:
	rjmp _irq_halt_loop     ; in case chip accidentally awakes

;
; Entry point down here
;
Start:
	; disable interrupts during init
	cli

	; setup port as follows
	; 0 = /CART_IN (input)
	; 1 = /VRES (output via transistor)
	; 2 = /CART_CE (input)
	; 3 = FAIL (output)
	; 4 = SUCCESS (output)
	ldi r26,(1 << PB1)|(1 << PB3)|(1 << PB4)
	out DDRB,r26
	
	; r27 = all outputs off
	; r28 = PB1 high (driving transistor)
	;       PB3 high (pulsing FAIL light to indicate the chip is working)
	eor r27,r27
	ldi r28,(1 << PB1)|(1 << PB3)

	; first, check /CART
	; if no cart is enabled, stop
	in r20,PINB
	andi r20,(1 << PB0)
	breq _continue_setup

	; blink FAIL light over and over
	; to indicate no cart inserted
	ldi r25,16
_cart_not_present:
	ldi r24,0b00001000
	out PORTB,r24
	rcall BurnCycles
	eor r24,r24
	out PORTB,r24
	rcall BurnCycles
	rjmp _cart_not_present

_continue_setup:
	; setup interrupts
	; INT0 is set to fire on falling edge of /CART_CE
	ldi r24,(1<<INT0)
	out GIMSK,r24
	ldi r24,0b00000010
	out MCUCR,r24

	ldi r24,10
_glitch_loop:
	cli
	out PORTB,r28         ; kick transistor pair on, pulling /VRES hard to ground
	rcall ResetBurnCycles ; wait for reset to take effect
	out PORTB,r27         ; de-assert /VRES
	sei                   ; turn interrupts on
	rcall BurnCycles      ; wait for /CART_CE to fall
	dec r24               ; if it doesn't in time, retry
	brne _glitch_loop

	; /CART_CE never got strobed; give up.
	cli
	ldi r24,0b00001000    ; turn FAIL LED on
	out PORTB,r24
	sleep
_fail_halt:
	rjmp _fail_halt       ; in case chip accidentally awakes

BurnCycles:
	ldi r20,0x3F
_loop_r0:
	ldi r21,0x7F
_loop_r1:
	ldi r22,0xFF
_loop_r2:
	dec r22
	brne _loop_r2
	dec r21
	brne _loop_r1
	dec r20
	brne _loop_r0
	ret

ResetBurnCycles:
	; this number of cycles MUST be precise.
	; if this design is refactored to eliminate the transistor pair
	; (which is trivial to do)
	; then this isn't too much of a problem because the VDP will
	; automatically de-assert /VRES.
	;
	; if you use the transistor pair and strobe /VRES (or ANY reset
	; line) low for too long an amount of time, it will hold the entire
	; system in reset and the Genesis will probably come out of reset
	; in a glitched state, or with TMSS re-enabled.
	; since the /VRES signal is controlled by the VDP, it may be
	; that too much current is drawn from the VDP, and keeping the
	; transistor pair turned on for too long can only mean bad news.
	ldi r22,25
_rbc_loop_r2:
	dec r22
	brne _rbc_loop_r2
	ret
