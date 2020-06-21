include "ioregs.asm"


SECTION "Timer code", ROM0


InitTimer::
	; Set up timer to fire every 64us (2^14Hz) in double-speed mode (128 cycles).
	; Easiest way to do this is 4-cycle mode, with timer modulo of 32.
	ld A, TimerEnable | TimerFreq18
	ld [TimerControl], A
	ld A, 32
	ld [TimerModulo], A
	ret


; Interrupt fires every 128 cycles, so speed is important here.
Timer::
	reti
