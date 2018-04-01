include "hram.asm"
include "ioregs.asm"
include "vram.asm"
include "longcalc.asm"
include "debug.asm"

SECTION "Stack", WRAM0

StackBase:
	ds 64
Stack:


SECTION "Guard", ROMX[$7fff], BANK[1]

rst 0

SECTION "Main", ROM0


Start::
	; Disable LCD, audio
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	; Init as much of RAM as possible to "rst 0" to catch bad jumps
	ld A, $c7

;	ld HL, $c000 ; c000-c300
;	ld B, 128 + 64
;.loop
;	REPT 4
;	ld [HL+], A
;	ENDR
;	dec B
;	jr nz, .loop

	ld HL, $c000
	ld B, 127 ; 128 loops * 64 per loop = $2000 = $c000 - $dfff
	ld [HL+], A
.wramloop
	REPT 64
	ld [HL+], A
	ENDR
	dec B
	jr nz, .wramloop

	ld HL, $ff80
	ld B, 127
.hramloop
	ld [HL+], A
	dec B
	jr nz, .hramloop

	; c300 = ff forces the bad behaviour
	ld A, $ff
	ld [$c300], A
	ld [$c301], A

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
	call InitSound

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
	; Turn on screen, window on alt tile grid, window on, use unsigned tilemap
	ld A, %11110000
	ld [LCDControl], A

	call OutOfSync ; get in sync with infrared signals and enable interrupts

.mainloop
	call Display
	call WaitForUpdate
	call UpdateSound
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

	; Top row of window should be fully black
	ld HL, AltTileGrid
	ld B, 20
	ld A, $7f
.loop2
	ld [HL+], A
	dec B
	jr nz, .loop2

	ret


; Block until next update to location
WaitForUpdate::
	ld A, 1
	ld [Updated], A
.loop
	halt
	ld A, [Updated]
	and A ; set z if 0
	jr nz, .loop
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
	ld A, C
	and $0f
	call NibbleToDigit
	ld B, A
	call GraphicsWrite
	inc DE
	ret


Display::

; These macros: addr to read, row, column

WriteByte: MACRO
	ld A, [\1]
	ld DE, (TileGrid + \2 * 32 + \3)
	call _WriteByte
ENDM

WriteWord: MACRO
	ld DE, (TileGrid + \2 * 32 + \3)
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
	; SPACE
	; Row 10: Graphics Queue Head and Tail
	; SPACE
	; Row 12: Debug stats: out of sync, pulse no signal, pulse too long, pulse too short
	; SPACE
	; SPACE
	; Row 15: average yaw, average pitch

	WriteByte LocDataPtr, 1, 1 ; 1-2
	WriteByte FirstIsYaw, 1, 4 ; 4-5

	WriteByte LocDurations + 0, 3, 1 ; 1-2
	WriteByte LocDurations + 1, 4, 1 ; 1-2
	WriteByte LocDurations + 2, 5, 1 ; 1-2
	WriteByte LocDurations + 3, 6, 1 ; 1-2

	WriteWord LocAngles + 0, 3, 4 ; 4-7
	WriteWord LocAngles + 2, 4, 4 ; 4-7
	WriteWord LocAngles + 4, 5, 4 ; 4-7
	WriteWord LocAngles + 6, 6, 4 ; 4-7

	WriteWord Yaw0,   3, 9 ; 9-12
	WriteWord Pitch0, 4, 9 ; 9-12
	WriteWord Yaw1,   5, 9 ; 9-12
	WriteWord Pitch1, 6, 9 ; 9-12

	WriteWord Forward, 8, 1  ; 1-4
	WriteWord Side,    8, 6  ; 6-9
	WriteWord Height,  8, 11 ; 11-14

	WriteByte GraphicsQueueHead, 10, 1 ; 1-2
	WriteByte GraphicsQueueTail, 10, 4 ; 4-5

	WriteByte StatOutOfSync, 12, 1
	WriteByte StatPulseNoSignal, 12, 4
	WriteByte StatPulseTooLong, 12, 7
	WriteByte StatPulseTooShort, 12, 10

	WriteWord YawAvg,   15, 1 ; 1-4
	WriteWord PitchAvg, 15, 6 ; 6-9

	ret


InitSound::
	ld A, %10000000
	ld [SoundControl], A
	ld A, %01110111
	ld [SoundVolume], A
	ld A, %00010001
	ld [SoundMux], A
	xor A
	ld [SoundCh1Control], A ; ensure it's off for now
	ld [SoundCh1Sweep], A
	ld A, %11110000 ; max vol, no envelope
	ld [SoundCh1Volume], A
	ret


; If yaw is known, play a tone with freq dependent on yaw
UpdateSound::
	ld A, [YawAvg]
	inc A ; set z if A was ff
	jr nz, .sound_on

	; disable sound
	xor A
	ld [SoundCh1Control], A
	ret

.sound_on
	; set freq value = YawAvg + 800 = 109Hz to 2114Hz
	ld A, [YawAvg]
	ld H, A
	ld A, [YawAvg + 1]
	ld L, A
	ld DE, 800
	add HL, DE
	ld A, L
	ld [SoundCh1FreqLo], A
	ld A, H
	and %00000111
	or %10000000 ; start playing forever
	ld [SoundCh1Control], A
	ret
