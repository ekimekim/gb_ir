include "hram.asm"
include "ioregs.asm"
include "vram.asm"
include "longcalc.asm"

SECTION "Stack", WRAM0

StackBase:
	ds 128
Stack:


SECTION "Sample data", WRAM0, ALIGN[8]

; Note: aligned
Samples::
	ds 18*20*8


SECTION "Main", ROM0


Start::
	; Disable LCD, audio
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	ld SP, Stack

	; Switch into double-speed mode
	ld A, 1
	ld [CGBSpeedSwitch], A
	stop

	; Init graphics tiles
	call GenerateTiles
	call InitBGPalette

	; Intialize IO register variables
	ld A, 16 ; One sample per 16*2^-19 = 2^-15, for a full sample length of 256*8*2^-15 = 1/16 sec
	ld [TimerModulo], A
	xor A ; Enable no interrupts - we'll enable timer specifically later.
	ld [InterruptsEnabled], A
	ei
	; Set up timer. Note since we're in double-speed mode the actual freq is 2^-19.
	ld A, TimerEnable | TimerFreq18
	ld [TimerControl], A
	; Intialize infrared sensor to always sense. Wasteful for power, but meh.
	ld A, %11000000
	ld [CGBInfrared], A
	; Turn on screen, use unsigned tilemap
	ld A, %10010000
	ld [LCDControl], A
	

.mainloop
	call TakeSamples
	call DisplaySamples
	call WaitForButton
	jr .mainloop


; Generates a tile for each possible value 0-256 indicating high-low for each bit in order.
GenerateTiles::
	ld HL, BaseTileMap
	ld B, 0
	; Each tile should look like this:
	;   00000000
	;   00000000
	;   hhhhhhhh
	;   00000000
	;   00000000
	;   llllllll
	;   00000000
	;   00000000
	; where h is on if the corresponding bit is, and l is on if it isn't. ie. the rows are:
	;   0, 0, index, 0, 0, ~index, 0, 0
	; To simplify things, we just repeat the values twice since we only care about 2 colors,
	; ie. our colors are 00 and 11.
.loop
	xor A
	ld [HL+], A
	ld [HL+], A ; 1st row = 0
	ld [HL+], A
	ld [HL+], A ; 2nd row = 0
	ld A, B
	ld [HL+], A
	ld [HL+], A ; 3rd row = index
	xor A
	ld [HL+], A
	ld [HL+], A ; 4th row = 0
	ld [HL+], A
	ld [HL+], A ; 5th row = 0
	ld A, B
	cpl ; A = ~B
	ld [HL+], A
	ld [HL+], A ; 6th row = ~index
	xor A
	ld [HL+], A
	ld [HL+], A ; 7th row = 0
	ld [HL+], A
	ld [HL+], A ; 8th row = 0
	inc B
	jr nz, .loop
	ret


InitBGPalette::
	ld A, 6 | $80 ; selects the palette 0, 11 color value, and enables autoincrement
	ld [TileGridPaletteIndex], A
	xor A
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A ; palette 0, 11 color value = 0, ie. black
	ret


; Copy rows of sample data into VRAM for display.
DisplaySamples::
	call WaitForVBlank
	xor A
	ld [LCDControl], A ; turn off screen

	ld DE, TileGrid
	ld HL, Samples
	ld B, 18
.outer
	ld C, 20
.inner
	push BC
	ld B, 0
REPT 8
	ld A, [HL+] ; A = raw sample, actual sample is inverted and in bit 1
	rra
	rra ; rotate until sample bit is in carry
	rl B ; rotate carry bit back out into B
ENDR
	ld A, B
	cpl ; invert, so 1 is a high reading
	ld [DE], A
	inc DE
	pop BC
	dec C
	jr nz, .inner
	LongAdd D,E, 0,12, D,E
	dec B
	jr nz, .outer
	; Turn on screen, use unsigned tilemap
	ld A, %10010000
	ld [LCDControl], A
	ret


WaitForVBlank:
	; first, wait until we AREN'T in vblank so we can capture the start
.loop1
	ld A, [LCDStatus]
	and %00000011
	cp 1
	jr z, .loop1
	; then wait until we are in vblank
.loop2
	ld A, [LCDStatus]
	and %00000011
	cp 1
	jr nz, .loop2
	ret


; Wait for any button to be pressed.
WaitForButton::
	xor A
	ld [JoyIO], A ; select both lines
	REPT 6
	nop ; wait for it to settle
	ENDR
.loop
	ld A, [JoyIO]
	and $0f
	cp $0f ; if any bits are 0 (!= 0f), a button was pressed
	jr z, .loop
	ret


TakeSamples::
	ld C, LOW(CGBInfrared)
	ld HL, Samples
	; A lot of our normal tricks for speed don't work well here, because samples need to be
	; a consistent timing apart. so eg. unrolling doesn't help since we are constrained by
	; the _longest_ time between samples.

	; This is the mother of all unrolls. But it works.
	; Takes one sample every 4 cycles.
	; Takes enough samples to fill the screen with info.
	; Total sample coverage time: 2^-21 * 4 * 18 * 20 * 8 = 2^-16 * 18 * 20 = 45 * 2^-13 ~= 5.5ms
	; This is a bit of a problem, since we aren't guarenteed to spot the 60Hz pattern.
	; It can be almost entirely fixed by expanding the display to cover the whole 32x32 tilegrid
	; and writing some code to scroll (total coverage would then be 15.625ms), but this will
	; do for now. We can always slow it down if we must!
REPT 18*20*8
	ld A, [C]
	ld [HL+], A
ENDR
	ret
