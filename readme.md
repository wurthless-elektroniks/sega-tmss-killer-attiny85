# Tiny Sega TMSS Disabler in an ATTinyX5 (AVR C Version)

This project will disable the TMSS screen on a Sega Genesis. It is meant to be easy to install, and easy to uninstall. No trace cuts are required.

Given that the most common way of disabling TMSS involves cutting traces and logic gates or using a switch to enable and disabling the mod when using add-ons such as the Sega-CD, it was time to automate the process.

This AVR C version was made out of curiosity and as a way to improve upon the original by making the code easier to understand using AVR C (which will make it more accessible to the Arduino crowd), and eliminating the use of the transistor which could cause damage to the ASICs in the long term.
Loops were made tighter (we don't need to wait for the interrupts for too long) and timed in accordance to the original using the simulator in Atmel Studio.

The transistor was removed because it could cause long term issues driving the reset too hard to GND. Instead the open-collector nature of the reset pin is preserved and the modchip only activates when it's time to work. 

## Stuff needed
* Sega Genesis with TMSS
* An ATTinyX5 MCU (I used an ATTiny85-20S)
* Optionally, two LEDs and a 220 ohm resistor
* Soldering skills

## To build and flash the source
 Code can be used in any Atmel AVR IDE or even the Arduino IDE. Paste the C code into it and compile for ATTiny85.
* Set fuses as follows:
  * For avrdude, use params -U lfuse:w:0xF1:m -U hfuse:w:0xDF:m -U efuse:w:0xFF:m
  * For Xgpro, see here (https://github.com/wurthless-elektroniks/sega-tmss-killer-attiny85/issues/1) for fusesettings 
* You MUST set the fuses correctly or else this won't work.

## Assembly and installation

Installation is fairly straightforward:
* ATTiny pin 1 to /MRES (cart connector pin B2)
* This is for Everdrives or other flashcarts that toggle Master Reset when coming in and out of special modes like SMS or SCD.
* ATTiny pin 5 to /CART_IN (cart connector pin B32)
* ATTiny pin 6 to /VRES (cart connector pin B27) 
* ATTiny pin 7 to /CART_CE (cart connector pin B17)
* ATTiny pin 4 to GND
* ATTiny pin 8 to VCC

Optionally:
* ATTiny pin 2 to the "FAIL" status LED
* ATTiny pin 3 to the "SUCCESS" status LED

**If you are using an Everdrive:** If hard reset is turned on in the Everdrive software, you will still see the TMSS screen before the game runs.
To avoid this, tie the ATTiny's /RESET pin to /MRES (cart connector B2). The bypass should work fine without it.

## Compatibility

This should work with all TMSS consoles. TMSS is present on Genesis and Mega Drive systems from Model 1 hardware revision VA6 onwards. (All Model 2 and Model 3 systems have TMSS as standard.)

### Tested, confirmed working
* 315-5402/5433-based consoles (tested: Model 1 VA6).
* 315-5487/5660-based consoles (tested: Model 2 VA3).
* 315-5700/5708-based consoles (tested: Model 2 VA1).
* 315-5960/6123 GOAC-based consoles (tested: Model 2 VA4).
* Sega CD: Since the Sega CD only boots when no cartridge is inserted, this mod will not interfere with the Sega CD boot process. (Tested with Model 1 and Model 2 NA SCD)
* 32X: Works as any plain Genesis cartridge.
* Sega CD with Flashcarts. Since the mod takes itself off the bus once it's done, no interference is caused with flashcarts that do write to SCD.
* Sega Power Base Converter/SMS compatibility mode: Works with Power Base converter and Everdrives in SMS mode. Since MRES is also being wired now, it will bypass TMSS once it gets out of SMS mode and into Genesis mode.
  
## How TMSS works

The Genesis I/O chip controls the initial system state based on the /CART and /M3 pins of the cartridge connector. If /CART is high, the system tries to boot from the expansion connector. If /CART is low but /M3 is also low, the system boots in SMS compatibility mode. Otherwise, the system assumes that a cartridge is present, and the 68000 is released from reset with the TMSS ROM mapped in memory by the I/O chip.

The 68000 executes the TMSS ROM, which performs basic hardware initialization and then copies code to RAM. The stub code in RAM briefly enables the cartridge to check if 'SEGA' is present at $100. If so, it displays "PRODUCED BY OR UNDER LICENSE FROM SEGA ENTERPRISES LTD", then enables the cartridge permanently and jumps to the game. Otherwise, the TMSS code puts the Genesis into an infinite loop.

The relevant code that enables and disables the cartridge (from [here](https://wiki.megadrive.org/index.php?title=TMSS)):

    test_cart:
    		bset	#0, (a3)	| a3 = 0xA14101, Disable TMSS rom and enable cart
    		cmp.l	(0x100).w, d7	| Compare ROM offset 0x100 with	'SEGA'
    		beq.s	_cart_ok
    		cmp.l	(0x100).w, d4	| Compare ROM offset 0x100 with	' SEG'
    		bne.s	loc_302
    		cmpi.b	#0x41, (0x104).w | 'A' | Look for the missing 'A'
    		beq.s	_cart_ok
    loc_302:
    		bclr	#0, (a3)	| Disable cart and enable TMSS rom

The weakness with how TMSS is implemented, however, is that the value of $A14101 persists between soft resets. So, if we reset the 68000 in the short period of time where the cartridge is enabled, then  TMSS will stay locked out and the Genesis will boot the game directly.

## Theory of operation

The ATTiny85 checks if /CART is pulled low and will stop execution if it isn't (the FAIL light blinks forever).
Since the reset pins on the Genesis are open collectors, we have the ATTiny on high-Z to prevent bus conflicts when not in use.
Otherwise, it sets up INT0 to fire on the falling edge of /CART_CE, and begins the "glitch loop". In the glitch loop, /VRES is pulled low, resetting the 68000 to a predictable state. The code then waits for INT0 to fire; if it doesn't within a certain amount of time, it will retry several times before giving up (the FAIL light stays on).
As soon as /CART_CE falls, INT0 fires, /VRES is pulsed, then the program halts in a "success" state (SUCCESS light stays on). At this point, the glitch should have succeeded, and the Genesis should boot directly into the game.
At this point, the ATTiny removes itself from the bus and resets operate normally until a Master Reset or power cycle is initiated and the process starts again. 

## Known improvements
* The ATTiny85 is overpowered, overspecced, and overpriced for what this mod involves. This code could be ported to a cheaper AVR chip, or converted to some other cheap microcontroller.

## Acknowledgements
* würthless elektroniks for the original idea on AVR.
* lidnariq on nesdev for actually trying this
* TmEE (Tiido Priimagi)
* Jorge Nuno
* DUSTINODELLO (32mbit) for the hint on the open-collector nature of the reset pins.

## License
Public domain
