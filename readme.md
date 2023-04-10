# World's Worst Sega TMSS Disabler in an ATTiny85

This project will disable the TMSS screen on a Sega Genesis. It was designed as a stupid weekend project and is not really something you can use commercially, although it does work. It is meant to be easy to install, and easy to uninstall. No trace cuts are required.

This method of disabling TMSS is nothing new. It has been tried before with success, but no working device or source code is in wide circulation for some reason. Given that the most common way of disabling TMSS involves cutting traces and logic gates (yours for only 15 quid!), we are long overdue for a more elegant solution.

## Stuff needed

* Sega Genesis with TMSS (Model 2 works)
* ATTiny85-20P
* An NPN transistor (I was lazy)
* Optionally, two LEDs and a 220 ohm resistor
* Soldery shit

## To build and flash the source

* Assemble with avra
* Use avrdude params -U lfuse:w:0xF1:m -U hfuse:w:0xDF:m -U efuse:w:0xFF:m
* Sorry about the horrible source code, I had never used AVR assembly before this project

## Assembly and installation

* ATTiny pin 5 to /CART_IN (cart connector pin B32)
* ATTiny pin 6 to transistor base
* /VRES (cart connector pin B27) to transistor collector
* Transistor emitter to GND
* ATTiny pin 7 to /CART_CE (cart connector pin B17)

## Compatibility

### Tested working

* USA Genesis 2 VA 1.8

### Not tested

* Literally everything else

### Not compatible

* Any Genesis that doesn't have TMSS (why would you try, anyway?)

## How TMSS works

Upon coming out of reset the TMSS ROM is mapped in place of the cartridge. The 68000 will initialize the hardware, copy code to RAM, and jump to it. It will enable the cartridge, read what it needs to read, and then disable the cartridge. If the TMSS ROM sees the 'SEGA' string in the ROM header, it displays "PRODUCED BY OR UNDER LICENSE FROM SEGA ENTERPRISES LTD", then jumps to the game. Otherwise, the 68000 will halt execution.

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

Since /CART_CE will be strobed at least once in this code block, we can take advantage of this.

## Theory of operation

The ATTiny85 checks if /CART is pulled low and will stop execution if it isn't (the FAIL light blinks forever). Otherwise, it sets up INT0 to fire on the falling edge of /CART_CE, and begins the "glitch loop". In the glitch loop, /VRES is pulled hard to ground via the transistor, resetting the 68000 to a predictable state. The code then waits for INT0 to fire; if it doesn't within a certain amount of time, it will retry several times before giving up (the FAIL light stays on).

As soon as INT0 fires, /VRES is driven low, then the program halts in a "success" state (SUCCESS light stays on). At this point, the glitch should have succeeded, and the Genesis should boot directly into the game.

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
