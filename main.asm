include "hram.asm"
include "ioregs.asm"
include "vram.asm"
include "longcalc.asm"
include "debug.asm"

SECTION "Stack", HRAM

StackBase:
	ds 64
Stack:


NUM_SAMPLES EQU 8192
; Note: Samples extends across both WRAM0 and WRAMX
SECTION "Sample data", WRAM0[$c000]
Samples::
	ds 4096
SECTION "Sample data 2", WRAMX[$d000], BANK[1]
Samples2::
	ds NUM_SAMPLES + (-4096)


SECTION "Main", ROM0


Start::
	; Disable LCD, audio
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	ld SP, Stack

	; Switch into double-speed mode, set up ram bank
	ld A, 1
	ld [CGBSpeedSwitch], A
	stop
	ld A, BANK(Samples2)
	ld [CGBWRAMBank], A

	; Init graphics tiles
	call LoadTiles
	call InitBGPalette
	call ClearScreen

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

SetSamples: MACRO
	ld HL, Samples + \1
	ld B, \2
.loop\@
	ld A, [HL]
	xor %00000010
	ld [HL+], A
	dec B
	jr nz, .loop\@
ENDM
;	SetSamples 512, 16
	

	call ProcessSamples
	call DisplaySamples
	call WaitForButton
	jr .mainloop


InitBGPalette::
	ld A, 6 | $80 ; selects the palette 0, 11 color value, and enables autoincrement
	ld [TileGridPaletteIndex], A
	xor A
	ld [TileGridPaletteData], A
	ld [TileGridPaletteData], A ; palette 0, 11 color value = 0, ie. black
	ret


; Zero the screen (kind of - our zero value is " ")
ClearScreen::
	ld A, " "
	ld HL, TileGrid
	ld BC, 32*32
.loop
	ld [HL+], A
	dec C
	jr nz, .loop
	dec B
	jr nz, .loop
	ret


; Convert samples from raw form to something useful
ProcessSamples::
	; HL tracks read pointer, DE tracks write pointer.
	; Since DE moves much slower than HL, we just assume they won't conflict.
	; We also assume DE will never overflow Samples array.
	; In this way we replace samples as a list of raw results, with samples as a list of runs
	; (db value, dw length). values are 0 or 1. $ff is terminator.
	ld HL, Samples
	ld DE, Samples
	; BC counts run length
	; A tracks current value
	jr .start
.next
	ld A, B
	ld [DE], A
	inc DE
	ld A, C
	ld [DE], A
	inc DE ; [DE] = BC and increment DE
.start
	ld A, [HL]
	ld B, A ; temp storage, BC is about to be reset anyway. can't re-read from HL because in first
	        ; loop DE will overwrite it.
	cpl
	and %00000010
	rra ; A = ~(bit 1 of A)
	ld [DE], A ; write value of next entry
	ld A, B ; restore A as raw value
	inc DE
	ld BC, 0
.loop
	inc BC
	inc HL
	push AF
	LongCP HL, Samples + NUM_SAMPLES ; set z if HL has reached end of Samples
	jr z, .popAndBreak
	pop AF
	cp [HL] ; compare A to new sample
	jr z, .loop ; if equal, continue counting
	jr .next
.popAndBreak
	pop AF
.break
	ld A, B
	ld [DE], A
	inc DE
	ld A, C
	ld [DE], A
	inc DE ; [DE] = BC and increment DE
	ld A, $ff
	ld [DE], A ; write terminator
	ret


; Takes 4-bit value in A and returns a hex digit index
_NibbleToDigit:
	add "0"
	cp "9" + 1 ; set c if <= "9"
	jr c, .lessThan10
	add "a" - ("9"+1) ; adjust so that values 10-15 map to a-f
.lessThan10
	ret



; Copy rows of sample data into VRAM for display.
DisplaySamples::
	call WaitForVBlank
	xor A
	ld [LCDControl], A ; turn off screen

	call ClearScreen

	ld HL, Samples
	ld DE, TileGrid

.loop
	ld A, [HL+]
	cp $ff
	jr z, .break ; terminator value hit, break
	add "0" ; value is 0 or 1, so this is all that's needed
	ld [DE], A
	inc DE
	inc DE ; leave a space
REPT 2
	ld A, [HL+]
	ld B, A
	and $f0
	swap A
	call _NibbleToDigit
	ld [DE], A
	inc DE
	ld A, B
	and $0f
	call _NibbleToDigit
	ld [DE], A
	inc DE
ENDR
	LongAdd DE, 32-6, DE ; DE += (32-6), ie. move DE to start of next row
	LongCP DE, TileGrid + 32*32 ; set z if we've hit the last row
	jr nz, .loop
.break
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

	; Takes one sample every 8 cycles.
	; Total coverage = 8192 samples * 8 cycles/sample = 2^12 * 2^3 = 2^15 cycles = 2^-6 seconds
	; Below loop has some weird counting behaviour - we need to -1 as it runs over the count by 1,
	; but also +256 because the high byte has an off-by-one error.
	ld DE, NUM_SAMPLES + 256 - 1
.loop
	ld A, [C]
	ld [HL+], A
	dec E
	jr nz, .loop ; 8 cycles if we take the loop
	dec E ; 8th cycle of prev sample window - dec E again to account for next sample
	ld A, [C]
	ld [HL+], A
	dec D
	jr nz, .loop ; note the dec D window is also 8 cycles
	ret
