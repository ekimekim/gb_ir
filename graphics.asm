
include "macros.asm"
include "vram.asm"
include "hram.asm"


SECTION "Graphics Data", ROM0

FontData:
include "assets/font.asm"
FontDataEnd:


SECTION "Graphics Code", ROM0

InitGraphics::
	; load font data into tile map
	ld HL, FontData
	ld DE, BaseTileMap + $20 ; start from space, lined up with ascii
	ld BC, FontDataEnd - FontData
	LongCopy
	; init GraphicsPos
	xor A
	ld [GraphicsPos], A
	ret


; max number of value pairs to display per vblank before we risk
; running out of time.
MAX_PER_VBLANK EQU 4 ; could probably be larger


VBlank::
	push AF
	push BC
	push DE
	push HL

	ld B, MAX_PER_VBLANK
	ld A, [GraphicsPos]
	ld C, A

.pairs_loop

	; try to grab a new value, set z if not available
	RingPop CountsRing, 255, D
	jr z, .break

	; write first two chars
	call WriteHex

	; grab the second value, they're always written in pairs
	RingPopNoCheck CountsRing, 255, D

	; write second two chars
	call WriteHex

	inc C ; add a space

	; check if we need to start a new line
	ld A, 31
	and C ; A = C % 32
	cp 20 ; set z if we're at 20 and should start a new line
	jr nz, .no_new_line
	ld A, 12
	add C
	ld C, A ; C += 12, bringing it to start of next line. Wraps back to first line after 8 lines.
.no_new_line

	dec B ; set z if we need to stop now
	jr nz, .pairs_loop
.break

	ld A, C
	ld [GraphicsPos], A

	pop HL
	pop DE
	pop BC
	pop AF
	ret
