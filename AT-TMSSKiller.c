/*/
Sega Genesis TMSS killer for ATTiny25/45/85
Original version: (c) 2023 würthless elektroniks
AVR C version: (c) 2025 villahed94
(you MUST run this in 16 MHz mode)
Fuses: L: 0xF1 , H: 0xDF
ATTiny25/45/85 pin configuration...
                 _____
from /MRES (B2)-|  u  |- VCC
      FAIL LED -|     |- from /CART_CE (B17)
   SUCCESS LED -|     |- to /VRES (B27)
           GND -|_____|- from /CART_IN (B32)

The reset lines on the Genesis are open-collector, hence why it's tri-stated until it's necessary to pull down. 

*/
#define F_CPU 16000000UL //AVR set at 16MHz to make it fast enough.
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <avr/sleep.h>

void nocart()
{
	while (1)
	{
		_delay_ms(500); //A delay to make the blink visible.
		PORTB=PORTB^0x80; //Blink LED to indicate no cart is present.
	}
}

void glitchloop()
{
	for(int i=0;i<11;i++){
	cli(); //Disable interrupts
	DDRB=(DDRB)|(1 << PB1); //Enabling the driver for PB1.
	PORTB=(PORTB)&(0 << PB1)|(1 << PB3); //PB1 low,PB3 on
	_delay_us(5); //VRES reset delay
	DDRB=0x18; //Tri-stating PB1 again.
	PORTB=(PORTB)&(0 << PB1)&(0 << PB3); //PB1,PB3 off
	sei(); //Enable Interrupts
	//_delay_ms(764); //Equivalent to the BurnCycles delay routine in the original.
	_delay_ms(50); //No need to wait for so long. 
	}
	cli(); //CART_CE never got strobed, give up.
	PORTB=PORTB|(1 << PB3); //Turn LED fail on.
	sleep_enable(); //Send the MCU to sleep.
	sleep_cpu();
	
}
void init(){
	
	/* 
	 setup port as follows
	 0 = /CART_IN (input)
	 1 = /VRES (tri-stated until required, then output.)
	 2 = /CART_CE (input)
	 3 = FAIL (output)
	*/
   	cli();
	DDRB=(0 << PB1)|(1 << PB3)|(1 << PB4); //Defining PB1 as input to drive its open collector input later
	if(PINB & (1<< PINB0)){ //Reading if there's a cartridge present.
		nocart(); //No cartridge found, bypass execution.
	}
		GIMSK=0x40; //Enable INT0 interrupt on falling edge at CART_CE
	    MCUCR=0x02; 
}

int main(void)
{
	init();
	glitchloop();
}

ISR(INT0_vect){ //ISR handler, when CART_CE goes low
	/*
	; the very first opcode to run when the interrupt fires
	; must be the one that drives /VRES low
	; or else the reset will happen way too late.
	*/
	DDRB=DDRB|(1 << PB1); //Enabling the output pin driver for PB1.
	PORTB=PORTB&(0 << PB1)|(1 << PB3); //Turn PB1 low,PB3 on
	cli(); //Clear interrupts globally.
	_delay_us(5); //VRes delay
	DDRB=0x18; //Tri-stating PB1 again.
	PORTB=PORTB&(0 << PB1)&(0 << PB3); //PB1 tri-stated,PB3 off
	PORTB=0x00|(1 << PB4); //Success LED on
	sleep_enable(); //Sending the MCU to sleep.
	sleep_cpu();
}