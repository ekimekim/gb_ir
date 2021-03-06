include "constants.asm"
include "hram.asm"
include "ioregs.asm"
include "longcalc.asm"
include "debug.asm"

; Code for detecting IR signals. Doesn't include any of the higher logic.

IR_OFF EQU $fe
IR_ON EQU $fc

SECTION "Signal methods", ROM0


; Wait forever for a signal, and check its duration is over
; TOL_PULSE_DURATION. If so, returns duration in A. Otherwise keep looping until you succeed.
; Clobbers A, B, HL.
PollForPulseForever::
	push BC
.start
	ld A, 8
	ld [WindowX], A
	ld A, 136
	ld [WindowY], A

	ld HL, CGBInfrared
	ld A, IR_OFF
	ld B, 0
	ld C, 6

	; Wait until there's NO signal so we can catch rising edge
.wait_for_zero
	cp [HL]
	jr nz, .wait_for_zero

	; Wait until there's a signal. B counts to 256 every time we want to increment the window position.
.wait_for_rise
	inc B
	jr z, .inc_window
.inc_window_ret
	cp [HL]
	jr z, .wait_for_rise

	ld B, 0
	; Signal started. We track duration in B. Note loop is 8 cycles.
.wait_for_fall
	inc B
	jr z, .start ; overflow duration, wait for the next one
	cp [HL]
	jr nz, .wait_for_fall

	ld A, $ff
	ld [WindowX], A

	; Check if duration was acceptable
	ld A, B
	cp TOL_PULSE_DURATION_8c ; set c if B < acceptable duration
	jr c, .start ; try again

	pop BC
	ret

.inc_window
	dec C
	jr nz, .inc_window_ret
	ld C, 6
	ld A, [WindowX]
	inc A
	ld [WindowX], A
	ld A, IR_OFF
	jr .inc_window_ret


; Wait up to TOL_PULSE_WAIT for the next signal, and check its duration is over
; TOL_PULSE_DURATION. If so, returns duration in A. Otherwise returns 0 in A.
; Clobbers A, B, HL
PollForPulse::
	ld HL, CGBInfrared
	ld A, IR_OFF
	ld B, 0

	; Wait until signal starts. We track time in B. Note loop is 8 cycles.
.wait_for_rise
	inc B
	jr z, .fail_no_signal
	cp [HL]
	jr z, .wait_for_rise

	ld B, 0
	; Wait until signal ends. We track duration in B. Note loop is 8 cycles.
.wait_for_fall
	inc B
	jr z, .fail_too_long
	cp [HL]
	jr nz, .wait_for_fall

	; Check if duration was acceptable
	ld A, B
	cp TOL_PULSE_DURATION_8c ; set c if B < acceptable duration
	jr nc, .success
	Debug "Pulse was too short"
	IncStat StatPulseTooShort
.fail
	Debug "PollForPulse failed"
	xor A
.success
	ret
.fail_no_signal
	Debug "Failed to find pulse"
	IncStat StatPulseNoSignal
	jr .fail
.fail_too_long
	Debug "Pulse was too long"
	IncStat StatPulseTooLong
	jr .fail


; Wait for up to TOL_SWEEP_WAIT for the next signal. If one occurs, return
; its duration in A and the time until it occurred in DE, both in units of 8c.
; Otherwise A is 0 and DE is TOL_SWEEP_WAIT
; If duration is longer than ff we just return ff.
; Note the longest this function can run is just over TOL_SWEEP_WAIT + 2048c.
; Clobbers all but C.
PollForSweep::
	ld HL, CGBInfrared
	ld A, IR_OFF
	; Once the signal is detected, B will count how long it lasts
	ld B, 0
	; DE counts down with number of loops waited.
	; Note neither D or E can be zero or there are bugs! We cop out of fixing this by
	; simply disallowing bad values.
	; We also adjust for a further bug by adding 1 to D and dealing with it later.
	ld DE, TOL_SWEEP_WAIT_8c + 256
IF TOL_SWEEP_WAIT_8c / 256 == 0 || TOL_SWEEP_WAIT_8c % 256 == 0
	FAIL "TOL_SWEEP_WAIT_8c cannot have 0 in upper or lower byte."
ENDC

	; Inner loop is 8 cycles. Each 256 iterations we take 3 cycles extra.
	; So to be perfectly accurate the final cycle count is DE + 3D/256 but since that's
	; much less than 1 cycle even at the longest time, we ignore it.
.wait_for_rise
	cp [HL]
	jr nz, .wait_for_fall
	dec E
	jr nz, .wait_for_rise
	dec D
	jr nz, .wait_for_rise
	; if we got here, time ran out without a signal
.fail
	Debug "Failed to find sweep"
	ld DE, TOL_SWEEP_WAIT_8c
	xor A
	ret

.wait_for_fall
	inc B
	jr z, .overflow
	cp [HL]
	jr nz, .wait_for_fall
.break

	; Unless E == 0, D is 1 greater than it should be. Adjust for that.
	ld A, E
	and A ; set z if A == 0
	jr z, .no_adjust
	dec D
.no_adjust
	; Now DE = (TOL_SWEEP_WAIT - actual wait) and B = duration. We need to convert DE.
	LongSub TOL_SWEEP_WAIT_8c, DE, DE ; DE = TOL_SWEEP_WAIT - DE = number of loops waited
	ld A, B
	ret

.overflow
	dec B ; B = ff
	jr .break
