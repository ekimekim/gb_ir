include "constants.asm"
include "hram.asm"
include "ioregs.asm"
include "longcalc.asm"
include "debug.asm"

; Code for determining our location. This covers the high level logic.

; Macro that sets up the timer to fire after (\1 - A) units of 64 cycles,
; then calls handler \2.
; Interrputs must be disabled.
; Clobbers A.
SetTimer: MACRO
	sub (\1) ; A = A-\1, ie. timer must increment (\1-A) times to overflow
	ld [TimerCounter], A
	; Just in case, let's also clear any previously pending timer
	ld A, [InterruptFlags]
	res 2, A ; reset timer flag
	ld [InterruptFlags], A
	ld A, HIGH(\2)
	ld [TimerTrampolineHigh], A
	ld A, LOW(\2)
	ld [TimerTrampolineLow], A
ENDM

SECTION "Location data", WRAM0

; Trampoline to direct timer interrupt to a chosen handler.
; First byte must be $c3 (for opcode jp nnmm == c3 mm nn)
TimerTrampolineExec::
	db
TimerTrampolineLow:
	db
TimerTrampolineHigh:
	db

; The ptr is 0-3 and indicates the next entry to write in Angles and Durations
LocDataPtr::
	db
; Each word is an angle from 0 to 1136 or ffff for unknown
LocAngles::
	ds 2*4
; Each byte is a duration from 1 to ff or 0 for unknown
LocDurations::
	ds 4

; This saturating, signed counter is used to track whether LocAngles[0] is more likely
; to be a pitch or a yaw. Positive means yaw.
FirstIsYaw::
	db

SECTION "Location methods", ROM0


; Disables the location reporter. You must call OutOfSync to re-init.
LocationStop::
	; Literally all we do is stop the timer interrupt that drives everything.
	xor A
	ld [TimerControl], A
	ret


; This is both a reset and initialization routine.
; It will set up the location reporter and begin operating.
; Clobbers A, B, HL
OutOfSync::
	di

	Debug "Out of Sync"

	; increment count
	ld A, [StatOutOfSync]
	inc A
	ld [StatOutOfSync], A

	; init timer trampoline
	ld A, $c3
	ld [TimerTrampolineExec], A
	; init things to 0
	xor A
	ld [LocDataPtr], A
	ld [FirstIsYaw], A
	ld [LocDurations], A
	ld [LocDurations + 1], A
	ld [LocDurations + 2], A
	ld [LocDurations + 3], A
	dec A
	; init things to ff
	ld B, 2*4
	ld HL, LocAngles
.init_angles
	ld [HL+], A
	dec B
	jr nz, .init_angles

	; Block until we have a pulse candidate
	call PollForPulseForever ; A = duration in units of 8c

	; Convert units of 8c to units of 64c by shifting right 3 times
	and %11111000 ; we're rotating so we need to zero the stuff that will end up at the top
	rrca
	rrca
	rrca

	; The timer size doesn't let us sleep the entire duration to the next expected pulse,
	; so we instead sleep until sweep window as normal, but install a dummy handler to simply
	; go to sleep again.
	SetTimer TIME_PULSE_TO_SWEEP_64c, _OutOfSyncDummyHandler

	; Enable timer interrupt
	ld A, [InterruptsEnabled]
	set 2, A
	ld [InterruptsEnabled], A

	reti

_OutOfSyncDummyHandler:
	push AF
	Debug "Out of sync dummy handler"
	xor A
	SetTimer TIME_SWEEP_TO_PULSE_64c, PulseHandler
	pop AF
	reti


; The simpler handler, it polls for the sweep, marks down the measurements, then sets timer
; for when the pulse is expected.
SweepHandler:
	push AF
	push BC
	push DE
	push HL
	Debug "Sweep handler"
	call PollForSweep ; DE = wait, A = duration or 0 on fail
	Debug "Poll for sweep finished"
	and A ; set z if failed
	jr z, .failed
	ld B, A

	ld A, [LocDataPtr]
	LongAddToA LocDurations, HL ; HL = LocDuration + LocDataPtr
	ld [HL], B ; set duration

	ld A, [LocDataPtr]
	add A
	LongAddToA LocAngles, HL ; HL = LocAngles + 2*LocDataPtr
	ld A, D
	ld [HL+], A
	ld [HL], E ; [HL] = DE, set angle

	ld A, B
.failed
	; First, we get total time elapsed since sweep start as duration + wait
	LongAddToA DE, DE
	ld A, E ; faster, and we want final result in A
	; Now we need to convert from 8c to 64c by shifting DA right 3 times
	REPT 3
	srl D
	rra
	ENDR
	; Note our result can be up to (1136+255)/8 = 173, which is less than TIME_SWEEP_TO_PULSE.
	; So we don't need to worry about underflow here.
	SetTimer TIME_SWEEP_TO_PULSE_64c, PulseHandler
	pop HL
	pop DE
	pop BC
	pop AF
	reti


; The pulse handler re-syncs to the pulse, sets up for the next sweep,
; goes over the gathered data and possibly publishes an updated location.
PulseHandler:
	push AF
	push BC
	push HL
	Debug "Pulse handler"
	call PollForPulse ; sets A = duration, or 0 if no pulse
	and A ; set z if no pulse

	jr nz, .success
	; Didn't get a pulse within tolerance, we must be out of sync
	call OutOfSync
	pop HL
	pop BC
	pop AF
	reti
.success

	; Convert units of 8c to units of 64c by shifting right 3 times
	and %11111000 ; we're rotating so we need to zero the stuff that will end up at the top
	rrca
	rrca
	rrca
	; Set timer to begin sweep window later.
	; We still have more work to do here but it will easily be done in time.
	SetTimer TIME_PULSE_TO_SWEEP_64c, SweepHandler

	IncStat StatRoundsInSync

	; Rotate the data pointer
	ld A, [LocDataPtr]
	inc A
	and %00000011 ; mod 4
	ld [LocDataPtr], A

	push DE

	; Change FirstIsYaw counter depending on what we can glean from durations.
	; We do this by checking each possible pair (0,1), (1,2), (2,3) and (3,0).
	; For each one that looks right (yaw longer than pitch), we increment counter in that direction,
	; ie. positive for (0,1) and (2,3), negative for (1,2) and (3,0).
	; If it looks wrong, we increment in the opposite direction.
	; We skip any durations that aren't valid (are 0)
	ld B, 0 ; count changes
	ld HL, LocDurations

; helper macro, \1 is which duration to consider, \2/\3 is inc/dec or dec/inc depending on
; if it should change B positively if yaw, or negatively.
_CheckDuration: MACRO
	ld A, [HL+] ; A = dur N, HL points at N+1
IF \1 == 3
	; repoint HL back to start
	ld HL, LocDurations
ENDC
	and A ; set z if dur N == 0
	jr z, .skip\@
	ld C, A
	ld A, [HL]
	and A ; set z if dur N+1 == 0
	jr z, .skip\@
	cp C ; set c if dur N+1 < dur N, ie. dur N is probably a yaw
	jr c, .is_yaw\@
	\3 B ; is not yaw, move B in opposite direction
	jr .skip\@
.is_yaw\@
	\2 B ; is yaw, move B in direction
.skip\@
ENDM

	_CheckDuration 0, inc, dec
	_CheckDuration 1, dec, inc
	_CheckDuration 2, inc, dec
	_CheckDuration 3, dec, inc

	; B is now the sum of the above results, let's apply it.
	; This is a signed addition with saturation.
	ld A, [FirstIsYaw]
	cp 128 ; set c if A is <128, ie. is positive
	jr c, .positive
	; negative
	add B
	; now check for underflow by checking value is still >= 128
	cp 128 ; set c if A <128
	jr nc, .yaw_calc_done
	ld A, 128
	jr .yaw_calc_done
.positive
	add B
	; now check for overflow by checking value is still < 128
	cp 128 ; set c if A <128
	jr c, .yaw_calc_done
	ld A, 127
.yaw_calc_done
	ld [FirstIsYaw], A

	; Now we know which way around things are, we can publish (if available)
	; the two pitches and yaws.
	ld HL, LocAngles
	ld C, LOW(Yaw0)

	; note A still = FirstIsYaw
	cp 128 ; set c if positive
	jr c, .start_at_first
	inc HL
	inc HL ; point HL at slot 1 to start, not slot 0
.start_at_first

	ld B, 3*2 ; copy 6 bytes first
.publish_angles_loop
	ld A, [HL+]
	ld [C], A
	inc C
	dec B
	jr nz, .publish_angles_loop
	; now check if we need to wrap to first slot
	ld A, [FirstIsYaw]
	cp 128 ; set c if positive, nc if we need to wrap
	jr c, .no_wrap
	ld HL, LocAngles
.no_wrap
	ld A, [HL+]
	ld [C], A
	inc C
	ld A, [HL]
	ld [C], A

	; Now we can try to calculate our 3d location
	call TryCalculatePosition

	; Finally, indicate an update occurred
	xor A
	ld [Updated], A

	pop DE
	pop HL
	pop BC
	pop AF
	reti


TryCalculatePosition::
	ret ; TODO
