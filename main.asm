include "hram.asm"
include "ioregs.asm"
include "vram.asm"
include "longcalc.asm"
include "debug.asm"

SECTION "Stack", HRAM

StackBase:
	ds 64
Stack:


NUM_SAMPLES EQU 18
SECTION "Sample data", WRAM0
Samples::
	ds NUM_SAMPLES


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
	ld C, NUM_SAMPLES

.loop
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
	LongAdd DE, 32-4, DE ; DE += (32-4), ie. move DE to start of next row
	dec C
	jr nz, .loop

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
	; Populates Samples with time between rising edge of IR signal.
	; Achieves this by using the HW timer to track time while waiting for the IR value to change.

	; First, let's define the interrupt handler we want.
	; This will run each time the timer overflows.
	; Note this edits registers! Handle with care.
	; It also jumps out without returning on overflow, leaving 2 bogus stack entries.
	; At 2^18 clock rate, overflow takes 0.25s
PUSHS
SECTION "Timer interrupt", ROM0[$50]
	push AF ; save F from effects of inc B
	inc B
	jp z, SamplesOverflowed
	pop AF
	reti
POPS

; How much to add to the timer to account for the time between one sample being detected
; and the timer starting for the next one.
; Since timer units are 2^-18 = 8 cycles, this should be:
;   (num cycles from timer stop to timer start) / 8
; Currently 33 cycles, 33/8 = 4.125
TIMER_EXTRA EQU 4

	; For as long as interrupts are on and the timer is running, B will be incremented every
	; time the timer overflows. If B overflows, SamplesOverflowed will be jumped to.
	; Otherwise, you can then stop the timer then disable interrupts (not the other way, or
	; else a race can occur where B and TimerCounter are out of sync) and read (B, TimerCounter)
	; to get elapsed time.

	di
	ld A, IntEnableTimer
	ld [InterruptsEnabled], A
	xor A
	ld [TimerModulo], A
	ld HL, CGBInfrared
	ld DE, Samples
	ld C, NUM_SAMPLES

.sample
	xor A
	ld B, A
	ld [TimerCounter], A
	dec A ; A = ff
	ld H, A ; HL = CGBInfrared, since L is unchanged
	ld A, TimerEnable | TimerFreq18
	ld [TimerControl], A ; start timer
	ei

	; wait until no IR signal
.waitForZero
	ld A, [HL] ; A = xxxxxxIx
	rra ; A = xxxxxxxI
	rra ; puts I in carry - set = no signal
	jr nc, .waitForZero
	rla
	rla ; A = original again

	; wait until IR signal is different to A
.waitForRise
	REPT 28 ; this can be unrolled as much as we like as long as jr instrs still work
	cp [HL] ; unset z if [HL] has changed
	jr nz, .break ; break if changed. This is faster than looping if unchanged because jumps
	              ; that are taken take 1 cycle longer.
	ENDR 
	cp [HL] ; unset z if [HL] has changed
	jr z, .waitForRise ; loop
.break

	xor A
	ld [TimerControl], A ; stop timer
	di

	; [DE] = (B, [TimerCounter]) + TIMER_EXTRA
	ld A, [TimerCounter]
	add TIMER_EXTRA
	ld H, A
	ld A, 0 ; can't be xor A, this would affect flags
	adc B
	ld [DE], A
	inc DE
	ld A, H
	ld [DE], A
	inc DE

	; decrement count and loop
	dec C
	jr nz, .sample
	ret

SamplesOverflowed:
	pop AF
	pop AF ; clear two bogus stack entries
	ld A, $ff
	; fill remaining samples with $ffff
.loop
	ld [DE], A
	inc DE
	ld [DE], A ; [DE] = $ffff
	inc DE
	dec C
	jr nz, .loop
	ret ; note this returns from TakeSamples
