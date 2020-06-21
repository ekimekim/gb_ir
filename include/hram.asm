IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

; Previous value of IR register, to check if it's changed
LastSeen rb 1
; Count of ticks since last change
CountLo rb 1
CountHi rb 1

; Tracks where on screen we're writing to next
GraphicsPos rb 1

ENDC
