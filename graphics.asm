
include "macros.asm"
include "vram.asm"


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
	ret


VBlank::
	ret
