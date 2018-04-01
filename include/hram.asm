RSSET $ff80

; This gets set to 0 when location values are updated.
; Set it to 1 then watch it to know when to react to changes.
Updated rb 1

; Yaw and pitch values. Range from 0 to $470 or $ffff if unknown.
; One for each lighthouse, though which is which is liable to change.
Yaw0 rw 1
Pitch0 rw 1
Yaw1 rw 1
Pitch1 rw 1

; For convenience, the averages of (Yaw0,Yaw1), and (Pitch0,Pitch1),
; with correct behaviour if only one of them is valid, etc.
; $ffff if neither valid.
YawAvg rw 1
PitchAvg rw 1

; Positional coordinates from TODO to TODO (sign?) or TODO if unknown:
;	Forward: Perpendicular distance from the line between the two base stations,
;		level with the ground.
;		Alternately, movement forward and back.
;	Side: Perpendicular distance from the mid-line equidistant from the two base stations.
;		Alternately, movement from side to side.
;	Height: Perpendicular distance from the line between the two base stations, perpendicular
;		to the ground.
;		Alternately, movement up and down.
Forward rw 1
Side rw 1
Height rw 1

; Used by vblank handler, set by LCD Stat to tell when vblank is over.
; Set to 0 at start of vblank and set to 1 when it ends.
VBlankEnded rb 1

; Stats intended for debugging. These count various events.
StatOutOfSync rb 1
StatPulseNoSignal rb 1
StatPulseTooShort rb 1
StatPulseTooLong rb 1
StatRoundsInSync rb 1

IncStat: MACRO
	ld A, [\1]
	inc A
	ld [\1], A
ENDM
