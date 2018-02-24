; Generated from gbos/assets/font.json, plus additional hand-processing

include "macros.asm"
include "vram.asm"

SECTION "Tile data", ROM0

TileData::

ds $20 * 16 ; first char of font is ' ' = $20, each char is 16 bytes

dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000

dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00000000
dw `00003000
dw `00000000
dw `00000000

dw `00303000
dw `00303000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000

dw `00000000
dw `00303000
dw `03333300
dw `00303000
dw `03333300
dw `00303000
dw `00000000
dw `00000000

dw `00003000
dw `00033330
dw `00303000
dw `00033300
dw `00003030
dw `00333300
dw `00003000
dw `00000000

dw `03300000
dw `30030300
dw `03303000
dw `00030330
dw `00303003
dw `00000330
dw `00000000
dw `00000000

dw `00033300
dw `00300000
dw `00300000
dw `00033003
dw `00300330
dw `00033003
dw `00000000
dw `00000000

dw `00003000
dw `00003000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000

dw `00003000
dw `00030000
dw `00300000
dw `00300000
dw `00030000
dw `00003000
dw `00000000
dw `00000000

dw `00030000
dw `00003000
dw `00000300
dw `00000300
dw `00003000
dw `00030000
dw `00000000
dw `00000000

dw `00303030
dw `00033300
dw `00333330
dw `00033300
dw `00303030
dw `00000000
dw `00000000
dw `00000000

dw `00000000
dw `00003000
dw `00003000
dw `00333330
dw `00003000
dw `00003000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00003000
dw `00030000
dw `00000000

dw `00000000
dw `00000000
dw `00000000
dw `00333300
dw `00000000
dw `00000000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00003000
dw `00000000
dw `00000000

dw `00000030
dw `00000300
dw `00003000
dw `00030000
dw `00300000
dw `03000000
dw `00000000
dw `00000000

dw `00003300
dw `00030030
dw `00300003
dw `00300003
dw `00030030
dw `00003300
dw `00000000
dw `00000000

dw `00003000
dw `00033000
dw `00003000
dw `00003000
dw `00003000
dw `00033300
dw `00000000
dw `00000000

dw `00333300
dw `03000030
dw `00000300
dw `00033000
dw `00300000
dw `03333330
dw `00000000
dw `00000000

dw `00333300
dw `03000030
dw `00000300
dw `00033000
dw `03000030
dw `00333300
dw `00000000
dw `00000000

dw `00003000
dw `00033000
dw `00303000
dw `03003000
dw `03333300
dw `00003000
dw `00000000
dw `00000000

dw `03333330
dw `03000000
dw `03333300
dw `00000030
dw `03000030
dw `00333300
dw `00000000
dw `00000000

dw `00333300
dw `03000000
dw `03333300
dw `03000030
dw `03000030
dw `00333300
dw `00000000
dw `00000000

dw `03333330
dw `00000300
dw `00003000
dw `00030000
dw `00300000
dw `03000000
dw `00000000
dw `00000000

dw `00333300
dw `03000030
dw `00333300
dw `03000030
dw `03000030
dw `00333300
dw `00000000
dw `00000000

dw `00333300
dw `03000030
dw `03000030
dw `00333330
dw `00000030
dw `00333300
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00003000
dw `00000000
dw `00000000
dw `00003000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00003000
dw `00000000
dw `00000000
dw `00003000
dw `00030000
dw `00000000

dw `00000000
dw `00000330
dw `00033000
dw `03300000
dw `00033000
dw `00000330
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `03333330
dw `00000000
dw `03333330
dw `00000000
dw `00000000
dw `00000000

dw `00000000
dw `03300000
dw `00033000
dw `00000330
dw `00033000
dw `03300000
dw `00000000
dw `00000000

dw `00333000
dw `03000300
dw `00000300
dw `00033000
dw `00000000
dw `00030000
dw `00000000
dw `00000000

dw `00000000
dw `00033330
dw `00300030
dw `03003330
dw `03003030
dw `00303330
dw `00030000
dw `00003330

dw `00033000
dw `00033000
dw `00300300
dw `00333300
dw `03000030
dw `03000030
dw `00000000
dw `00000000

dw `03333000
dw `03000300
dw `03333000
dw `03000300
dw `03000300
dw `03333000
dw `00000000
dw `00000000

dw `00333000
dw `03000300
dw `30000000
dw `30000000
dw `03000300
dw `00333000
dw `00000000
dw `00000000

dw `03333000
dw `03000300
dw `03000300
dw `03000300
dw `03000300
dw `03333000
dw `00000000
dw `00000000

dw `03333300
dw `03000000
dw `03333000
dw `03000000
dw `03000000
dw `03333300
dw `00000000
dw `00000000

dw `03333300
dw `03000000
dw `03333000
dw `03000000
dw `03000000
dw `03000000
dw `00000000
dw `00000000

dw `00333000
dw `03000300
dw `30000000
dw `30033300
dw `03000300
dw `00333000
dw `00000000
dw `00000000

dw `03000030
dw `03000030
dw `03333330
dw `03000030
dw `03000030
dw `03000030
dw `00000000
dw `00000000

dw `00333330
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00333330
dw `00000000
dw `00000000

dw `00033300
dw `00000300
dw `00000300
dw `00000300
dw `03000300
dw `00333000
dw `00000000
dw `00000000

dw `03000300
dw `03003000
dw `03030000
dw `03330000
dw `03003000
dw `03000300
dw `00000000
dw `00000000

dw `03000000
dw `03000000
dw `03000000
dw `03000000
dw `03000000
dw `03333330
dw `00000000
dw `00000000

dw `03000003
dw `03300033
dw `03030303
dw `03003003
dw `03000003
dw `03000003
dw `00000000
dw `00000000

dw `03000030
dw `03300030
dw `03030030
dw `03003030
dw `03000330
dw `03000030
dw `00000000
dw `00000000

dw `00033300
dw `00300030
dw `00300030
dw `00300030
dw `00300030
dw `00033300
dw `00000000
dw `00000000

dw `03333000
dw `03000300
dw `03333000
dw `03000000
dw `03000000
dw `03000000
dw `00000000
dw `00000000

dw `00033300
dw `00300030
dw `00300030
dw `00300030
dw `00300030
dw `00033300
dw `00000030
dw `00000000

dw `03333000
dw `03000300
dw `03333000
dw `03030000
dw `03003000
dw `03000300
dw `00000000
dw `00000000

dw `00033300
dw `00300030
dw `00030000
dw `00003300
dw `00300030
dw `00033300
dw `00000000
dw `00000000

dw `03333333
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00000000
dw `00000000

dw `03000030
dw `03000030
dw `03000030
dw `03000030
dw `03000030
dw `00333300
dw `00000000
dw `00000000

dw `30000003
dw `03000030
dw `03000030
dw `00300300
dw `00300300
dw `00033000
dw `00000000
dw `00000000

dw `03000003
dw `03000003
dw `03003003
dw `03030303
dw `03300033
dw `03000003
dw `00000000
dw `00000000

dw `03000030
dw `00300300
dw `00033000
dw `00033000
dw `00300300
dw `03000030
dw `00000000
dw `00000000

dw `03000003
dw `00300030
dw `00030300
dw `00003000
dw `00003000
dw `00003000
dw `00000000
dw `00000000

dw `03333330
dw `00000300
dw `00003000
dw `00030000
dw `00300000
dw `03333330
dw `00000000
dw `00000000

dw `00333000
dw `00300000
dw `00300000
dw `00300000
dw `00300000
dw `00333000
dw `00000000
dw `00000000

dw `03000000
dw `00300000
dw `00030000
dw `00003000
dw `00000300
dw `00000030
dw `00000000
dw `00000000

dw `00333000
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00333000
dw `00000000
dw `00000000

dw `00030000
dw `00303000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `03333330
dw `00000000
dw `00000000

dw `00030000
dw `00003000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000
dw `00000000

dw `00000000
dw `00333300
dw `00000030
dw `00333330
dw `03000330
dw `00333030
dw `00000000
dw `00000000

dw `03000000
dw `03000000
dw `03333300
dw `03000030
dw `03300030
dw `03033300
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00033300
dw `00300000
dw `00300000
dw `00033300
dw `00000000
dw `00000000

dw `00000030
dw `00000030
dw `00333330
dw `03000030
dw `03000330
dw `00333030
dw `00000000
dw `00000000

dw `00000000
dw `00333300
dw `03000030
dw `03333330
dw `03000000
dw `00333300
dw `00000000
dw `00000000

dw `00000000
dw `00033000
dw `00030000
dw `00333000
dw `00030000
dw `00030000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00330300
dw `03003300
dw `03000300
dw `00330300
dw `00000300
dw `00333000

dw `00300000
dw `00300000
dw `00333000
dw `00300300
dw `00300300
dw `00300300
dw `00000000
dw `00000000

dw `00003000
dw `00000000
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00000000
dw `00000000

dw `00003000
dw `00000000
dw `00033000
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `03330000

dw `00300000
dw `00300000
dw `00300300
dw `00303000
dw `00330000
dw `00303300
dw `00000000
dw `00000000

dw `00030000
dw `00030000
dw `00030000
dw `00030000
dw `00030000
dw `00033000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `03300330
dw `03033030
dw `03000030
dw `03000030
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00303330
dw `00330030
dw `00300030
dw `00300030
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00333300
dw `03000030
dw `03000030
dw `00333300
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `03033300
dw `03300030
dw `03000030
dw `03333300
dw `03000000
dw `03000000

dw `00000000
dw `00000000
dw `00333030
dw `03000330
dw `03000030
dw `00333330
dw `00000030
dw `00000030

dw `00000000
dw `00000000
dw `00303300
dw `00330030
dw `00300000
dw `00300000
dw `00000000
dw `00000000

dw `00000000
dw `00033300
dw `00300000
dw `00033000
dw `00000300
dw `00333000
dw `00000000
dw `00000000

dw `00000000
dw `00030000
dw `00333300
dw `00030000
dw `00030000
dw `00033000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00300030
dw `00300030
dw `00300330
dw `00033030
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `03000030
dw `03000030
dw `00300300
dw `00033000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `30000003
dw `30000003
dw `03033030
dw `03300330
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `03000030
dw `00300300
dw `00033000
dw `03300330
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `03000030
dw `00300030
dw `00030300
dw `00003000
dw `00030000
dw `03300000

dw `00000000
dw `00000000
dw `00333300
dw `00003000
dw `00030000
dw `00333300
dw `00000000
dw `00000000

dw `00033300
dw `00030000
dw `00330000
dw `00330000
dw `00030000
dw `00033300
dw `00000000
dw `00000000

dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00003000
dw `00000000

dw `00333000
dw `00003000
dw `00003300
dw `00003300
dw `00003000
dw `00333000
dw `00000000
dw `00000000

dw `00000000
dw `00000000
dw `00000000
dw `00330030
dw `03003300
dw `00000000
dw `00000000
dw `00000000

dw `33333333
dw `33333333
dw `33333333
dw `33333333
dw `33333333
dw `33333333
dw `33333333
dw `33333333

EndTileData:
TILE_DATA_SIZE EQU EndTileData - TileData


SECTION "Tile data methods", ROM0

LoadTiles::
	ld DE, BaseTileMap
	ld HL, TileData
	ld BC, TILE_DATA_SIZE
	LongCopy
	ret
