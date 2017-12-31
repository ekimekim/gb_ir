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
	ds 256


SECTION "Main", ROM0


Start::
	; Disable LCD, audio
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	ld SP, Stack

	; Switch into double-speed mode
	; TODO do we need to enable interrupts to leave STOP mode?
	ld A, 1
	ld [CGBSpeedSwitch], A
	stop

	; Init graphics tiles
	call GenerateTiles
	call InitBGMap
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


; set up BG tile flags so that the top 1 and bottom 2 rows, as well as all but the 4 left-most tiles
; of the 3rd bottom row, use an all-white palette (palette 2), whereas other tiles use palette 1,
; this gives us 256 tiles of display in just over 14 rows.
InitBGMap::
	ld A, 1
	ld [CGBVRAMBank], A ; switch to bank 1
	; A still = 1, which is also the value we want for flags - selects palette 1
	ld HL, TileGrid
	; D and E track rows and count within a row. We flip between A = 0 and 1 (use palette 0 or 1)
	; every time B hits zero. It starts at -20 so it flips one row in, then flips again
	; 256 tiles later.
	ld B, -20
	ld D, 18
.loop_outer
	ld E, 20
.loop_inner
	ld [HL+], A
	inc B
	jr nz, .no_flip
	rra ; bottom bit of A goes into carry
	ccf ; negate carry
	rla ; move negated bit back out of carry, so we've flipped bottom bit of A
.no_flip
	dec E
	jr nz, .loop_inner
	LongAddConst HL, 32-20 ; LongAddConst doesn't clobber A, and i'm lazy
	dec D
	jr nz, .loop_outer
	; switch VRAM bank back before returning
	xor A
	ld [CGBVRAMBank], A
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
	ld HL, TileGrid + 32 ; start at second row
	ld DE, Samples
	; Lazy way of handling vblank: Copy in 5 parts.
	REPT 4
	call WaitForVBlank
	call CopyRow
	call CopyRow
	call CopyRow
	ENDR
	call CopyRow
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

CopyRow:
	ld B, 20
.loop
	ld A, [DE]
	ld [HL+], A
	inc E
	ret z ; early exit if E wraps (which it will on the 15th call)
	dec B
	jr nz, .loop
	LongAdd H,L, 0,(32-20), H,L
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


; TakeSamples macros

NopFor: MACRO
REPT (\1)
	nop
ENDR
ENDM

TakeSamples::
	ld [StackSave], SP ; for safekeeping. We're going to abuse push as a 16-bit ldi.
	ld SP, Samples + 256
	ld HL, CGBInfrared ; more flexibility than ld A, [C] and just as fast
	; A lot of our normal tricks for speed don't work well here, because samples need to be
	; a consistent timing apart. so eg. unrolling doesn't help since we are constrained by
	; the _longest_ time between samples.
BUDGET EQU 8

	; First 2 bytes is a special case, no cleanup from prev round
	ld A, [HL]
	rra ; first time's a special case: just shift once and you're done
	ld B, A
	NopFor BUDGET - 4
REPT 6
	ld A, [HL]
	rra
	rra ; shift A right twice -> sample bit is now in carry flag
	rl B ; shift carry into B
	NopFor BUDGET - 6
ENDR
	ld A, [HL]
	rra ; first time's a special case: just shift once and you're done
	ld C, A
	NopFor BUDGET - 4
REPT 6
	ld A, [HL]
	rra
	rra ; shift A right twice -> sample bit is now in carry flag
	rl C ; shift carry into C
	NopFor BUDGET - 6
ENDR

	; Second and all subsequent blocks interleaves finally writing prev block
	; with doing samples
	ld D, [HL] ; no time to do anything with the sample, just shove it elsewhere for now
	push BC ; actually writes the last 16 samples
	NopFor BUDGET - 6
