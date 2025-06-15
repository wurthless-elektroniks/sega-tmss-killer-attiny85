# DEPRECATED/HISTORICAL PROJECT ONLY

Further development [here](https://github.com/villahed94/sega-tmss-killer-attiny85-avrc).

This code was thrown together in a weekend, and it's nice that it got picked up by the community, but it's old, and crappy, and outdated.

# World's Worst Sega TMSS Disabler in an ATTinyX5

This project will disable the TMSS screen on a Sega Genesis. It was designed as a stupid weekend project and is not really something you can use commercially, although it does work. It is meant to be easy to install, and easy to uninstall. No trace cuts are required.

This method of disabling TMSS is nothing new. It has been tried before with success, but no working device or source code is in wide circulation for some reason. Given that the most common way of disabling TMSS involves cutting traces and logic gates (yours for only 15 quid!), we are long overdue for a more elegant solution.

**ConsolesUnleashed has made a PCB version of this mod, see [here](https://github.com/consolesunleashed/sega-mega-drive-tmss-disable) for Gerbers and other stuff.**

## Stuff needed

* Sega Genesis with TMSS
* An ATTinyX5 MCU (I use ATTiny85-20P or ATTiny25-20P)
* An NPN transistor (I was lazy)
* Optionally, two LEDs and a 220 ohm resistor
* Soldery shit

## To build and flash the source

* Assemble with avra
* Set fuses as follows:
  * For avrdude, use params -U lfuse:w:0xF1:m -U hfuse:w:0xDF:m -U efuse:w:0xFF:m
  * For Xgpro, see here (https://github.com/wurthless-elektroniks/sega-tmss-killer-attiny85/issues/1) for fusesettings 
* You MUST set the fuses correctly or else this won't work.
* Sorry about the horrible source code, I had never used AVR assembly before this project

## Assembly and installation

Installation is fairly straightforward:

* ATTiny pin 5 to /CART_IN (cart connector pin B32)
* ATTiny pin 6 to transistor base
* /VRES (cart connector pin B27) to transistor collector
* Transistor emitter to GND
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

* 315-5433-based consoles (tested: Model 1 VA6)
* 315-5660-based consoles (tested: Model 2 VA1.8)

### Untested, but probably working

* Sega CD: Since the Sega CD only boots when no cartridge is inserted, this mod will not interfere with the Sega CD boot process.
* Sega Power Base Converter/SMS compatibility mode: In SMS compatibility mode /VRES is pulled low by the I/O chip at all times, which prevents the 68000 from running. This mod only pulls /VRES low, which should not interfere with SMS mode operation, but I can't confirm this yet.

### Untested, don't know if it would work

* One-chip consoles, particularly later Model 2s and all Model 3s: There might be protection against something externally pulling /VRES low. I don't have a Model 3 on hand to test.
* Sega Nomad

### Not compatible

* Any Genesis that doesn't have TMSS (why would you try, anyway?)

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

The ATTiny85 checks if /CART is pulled low and will stop execution if it isn't (the FAIL light blinks forever). Otherwise, it sets up INT0 to fire on the falling edge of /CART_CE, and begins the "glitch loop". In the glitch loop, /VRES is pulled hard to ground via the transistor, resetting the 68000 to a predictable state. The code then waits for INT0 to fire; if it doesn't within a certain amount of time, it will retry several times before giving up (the FAIL light stays on).

As soon as /CART_CE falls, INT0 fires, /VRES is pulsed, then the program halts in a "success" state (SUCCESS light stays on). At this point, the glitch should have succeeded, and the Genesis should boot directly into the game.

## Why the transistor?

The NPN transistor involved in this design exists because I had spent too much time trying to get the chip to pull the /VRES line low and went for the Rube Goldberg approach to get the thing done before the weekend was over. The code (and associated PCB) could easily be refactored to eliminate the use of the transistor, but it was far easier to implement in software.

## Known improvements

* The transistor could be removed in favor of simply having the ATTiny85 pulling /VRES low on its own. I tried this, but it didn't seem to work.
* The ATTiny85 is overpowered, overspecced, and overpriced for what this mod involves. This code could and should be ported to a cheaper AVR chip, or converted to some other cheap microcontroller.

## Acknowledgements

* lidnariq on nesdev for actually trying this
* TmEE also says some guy called Jorge Nuno tried this also
* Greets to furrtek, caius, plutiedev and bigclivedotcom for no particular reason

## License

Public domain
