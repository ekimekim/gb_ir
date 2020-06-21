include "ioregs.asm"
include "ring.asm"
include "hram.asm"


SECTION "Timer code", ROM0


InitTimer::
	; Set up timer to fire every 64us (2^14Hz) in double-speed mode (128 cycles).
	; Easiest way to do this is 4-cycle mode, with timer modulo of 32.
	ld A, TimerEnable | TimerFreq18
	ld [TimerControl], A
	ld A, 32
	ld [TimerModulo], A
	; Set up hram vars
	ld A, %11000010 ; initial value = no signal
	ld [LastSeen], A
	ld [CGBInfrared], A ; also set up IR to recieve signals
	xor A
	ld [CountLo], A
	ld [CountHi], A
	ret


; Interrupt fires every 128 cycles, so speed is important here.
; The hot path is no change, no count overflow.
; Cycle count on this path (inc initial jump here) is 37, so we're spending
; a bit under 30% of our cpu time here.
Timer::
	push AF
	push HL

	; check IR sensor
	ld HL, LastSeen
	ld A, [CGBInfrared]
	cp [HL] ; set z if unchanged
	jr nz, .changed

	; inc counter
	inc L ; HL = CountLo
	inc [HL] ; set z on overflow
	jr nz, .no_overflow
	inc L ; HL = CountHi
	inc [HL] ; set z on overflow
	jr nz, .no_overflow
	; on overflow of hi, just decrement again so hi stays at ff.
	; any time hi = ff, we consider it "unknown value >= ff00".
.no_overflow

	pop HL
	pop AF
	reti

.changed
	; More complex case. Update LastSeen, push Count to ring and reset it.
	ld [HL+], A ; set LastSeen to new value. set HL = CountLo.
	ld A, [HL+] ; get CountLo, set HL = CountHi

	push BC
	ld C, A ; C = CountLo
	ld B, [HL] ; B = CountHi

	; We're being unsafe here by not checking if ring is full, but meh. Shouldn't happen
	; in practice (famous last words).
	; It's not clear what we could do if it failed anyway.
	RingPushNoCheck CountsRing, 255, B
	RingPushNoCheck CountsRing, 255, C

	; Reset Count
	xor A
	ld [CountLo], A
	ld [CountHi], A

	pop BC
	pop HL
	pop AF
	reti
