include "hram.asm"
include "ioregs.asm"
include "vram.asm"
include "longcalc.asm"
include "debug.asm"

SECTION "Stack", WRAM0

StackBase:
	ds 64
Stack:

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

	; Init graphics tiles and queues
	call GraphicsInit
	call LoadTiles
	call InitBGPalette
	call ClearScreen

	; Intialize IO register variables
	ld A, IntEnableVBlank | IntEnableLCDC ; we'll enable timer later
	ld [InterruptsEnabled], A
	xor A
	ld [TimerModulo], A
	ld A, TimerEnable | TimerFreq14 ; Set up timer for 64 cycles (2^15Hz)
	ld [TimerControl], A
	; Intialize infrared sensor to always sense. Wasteful for power, but meh.
	ld A, %11000000
	ld [CGBInfrared], A
	; Turn on screen, use unsigned tilemap
	ld A, %10010000
	ld [LCDControl], A

	call OutOfSync ; get in sync with infrared signals and enable interrupts

.mainloop
	call Display
	call WaitForUpdate
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


; Block until next update to location
WaitForUpdate::
	xor A
	ld [Updated], A
.loop
	halt
	ld A, [Updated]
	and A ; set z if 0
	jr z, .loop
	ret


; Takes 4-bit value in A and returns a hex digit index
NibbleToDigit:
	add "0"
	cp "9" + 1 ; set c if <= "9"
	jr c, .lessThan10
	add "a" - ("9"+1) ; adjust so that values 10-15 map to a-f
.lessThan10
	ret

; Writes byte A in hex to DE and advance DE.
; Clobbers B, C, HL.
_WriteByte:
	ld C, A
	and $f0
	swap A
	call NibbleToDigit
	push BC
	ld B, A
	call GraphicsWrite
	pop BC
	inc DE
	ld A, B
	and $0f
	ld B, A
	call GraphicsWrite
	inc DE
	ret


Display::

; These macros: addr to read, row, column

WriteByte: MACRO
	ld A, [\1]
	ld DE, (\2 * 32 + \3)
	call _WriteByte
ENDM

WriteWord: MACRO
	ld DE, (\2 * 32 + \3)
	ld A, [\1]
	call _WriteByte
	ld A, [(\1) + 1]
	call _WriteByte
ENDM

	; For debugging, we're going to display intermediate values as well as final products.
	; First row: DataPtr, FirstIsYaw
	; SPACE
	; Rows 3-6: Duration, Angle, (Yaw/Pitch)(0/1)
	; SPACE
	; Row 8: Forward, Side, Height

	WriteByte LocDataPtr, 1, 1 ; 1-2
	WriteByte FirstIsYaw, 1, 4 ; 4-5

	WriteByte LocDurations + 0, 3, 1 ; 1-2
	WriteByte LocDurations + 1, 4, 1 ; 1-2
	WriteByte LocDurations + 2, 5, 1 ; 1-2
	WriteByte LocDurations + 3, 6, 1 ; 1-2

	WriteWord LocAngles + 0, 3, 4 ; 4-7
	WriteWord LocAngles + 1, 4, 4 ; 4-7
	WriteWord LocAngles + 2, 5, 4 ; 4-7
	WriteWord LocAngles + 3, 6, 4 ; 4-7

	WriteWord Yaw0,   3, 9 ; 9-12
	WriteWord Pitch0, 4, 9 ; 9-12
	WriteWord Yaw1,   5, 9 ; 9-12
	WriteWord Pitch1, 6, 9 ; 9-12

	WriteWord Forward, 8, 1  ; 1-4
	WriteWord Side,    8, 6  ; 6-9
	WriteWord Height,  8, 11 ; 11-14

	ret
