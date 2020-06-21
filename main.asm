include "ioregs.asm"
include "ring.asm"

Section "Stack", WRAM0

StackBase:
	ds 128
Stack::

; CountsRing stores (big-endian) 16-bit counts in ticks between IR transitions.
Section "CountsRing", WRAM0

CountsRing::
	RingDeclare 255

Section "Main", ROM0

Start::

	; Disable LCD and audio.
	; Disabling LCD must be done in VBlank.
	; On hardware start, we have about half a normal vblank, but this may depend on the hardware variant.
	; So this has to be done quick!
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	; Use core stack
	ld SP, Stack

	; Enter double speed mode
	ld A, 1
	ld [CGBSpeedSwitch], A
	stop

	; Init things
	call InitGraphics
	call InitTimer

	; Turn on screen
	ld HL, LCDControl
	set 7, [HL]
	; Clear pending interrupts
	xor A
	ld [InterruptFlags], A
	; Go
	ei

.main
	halt
	jp .main
