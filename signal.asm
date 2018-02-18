
include "ioregs.asm"

; Code for detecting IR signals. Doesn't include any of the higher logic.

IR_OFF EQU 0xfe
IR_ON EQU 0xfc

; Tolerances for various times. Suffix indicates units, c is cycles.
TOL_PULSE_WAIT_8c EQU 128 ; 488us
TOL_PULSE_DURATION_8c EQU 18 ; 68us
TOL_SWEEP_WAIT_8c EQU 1136 ; 4333us

SECTION "Signal methods", ROM0


; Wait forever until next signal arrives and determine its duration.
; DOES NOT return how long until signal arrived.
; Duration is returned in B in units of 8 cycles (2^-18s).
; If duration is too long, discards signal and waits for next rise.
; Clobbers A, HL.
PollForAny::
	ld HL, CGBInfrared
	ld A, IR_OFF
	ld B, 0

	; Wait until there's NO signal so we can catch rising edge
.wait_for_zero
	cp [HL]
	jr nz, .wait_for_zero

	; Wait until there's a signal
.wait_for_rise
	cp [HL]
	jr z, .wait_for_rise

	; Signal started. We track duration in B. Note loop is 8 cycles.
.wait_for_fall
	inc B
	jr z, .wait_for_zero ; overflow duration, wait for the next one
	cp [HL]
	jr nz, .wait_for_fall

	ret


; Wait up to TOL_PULSE_WAIT for the next signal, and check its duration is over
; TOL_PULSE_DURATION. If so, returns duration in A. Otherwise returns 0 in A.
; Clobbers A, HL
PollForPulse::
	ld HL, CGBInfrared
	ld A, IR_OFF
	ld B, 0

	; Wait until signal starts. We track time in B. Note loop is 8 cycles.
.wait_for_rise
	inc B
	jr z, .fail
	cp [HL]
	jr z, .wait_for_rise

	ld B, 0
	; Wait until signal ends. We track duration in B. Note loop is 8 cycles.
.wait_for_fall
	inc B
	jr z, .fail
	cp [HL]
	jr nz, .wait_for_fall

	; Check if duration was acceptable
	ld A, B
	cp TOL_PULSE_DURATION_8c ; set c if B < acceptable duration
	jr nc, .success
.fail
	xor A
.success
	ret


; Wait for up to TOL_SWEEP_WAIT for the next signal. If one occurs, return
; its duration in A and the time until it occurred in DE, both in units of 8c.
; Otherwise A is 0.
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
	ld DE, TOL_SWEEP_WAIT_8c
IF HIGH(TOL_SWEEP_WAIT_8c) == 0 || LOW(TOL_SWEEP_WAIT_8c)
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
	xor A
	ret

.wait_for_fall
	inc B
	jr z, .fail ; fail if we overflow as this indicates a way too long duration.
	cp [HL]
	jr nz, .wait_for_fall

	; Now DE = (TOL_SWEEP_WAIT - actual wait) and B = duration. We need to convert DE.
	LongSub TOL_SWEEP_WAIT_8c, DE, DE ; DE = TOL_SWEEP_WAIT - DE = number of loops waited
	ld A, B
	ret
