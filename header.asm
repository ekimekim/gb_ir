include "ioregs.asm"
include "hram.asm"

; Warning: each of these sections can only be 8b long!
section "Restart handler 0", ROM0 [$00]
Restart0::
	jp HaltForever
section "Restart handler 1", ROM0 [$08]
Restart1::
	jp HaltForever
section "Restart handler 2", ROM0 [$10]
Restart2::
	jp HaltForever
section "Restart handler 3", ROM0 [$18]
Restart3::
	jp HaltForever
section "Restart handler 4", ROM0 [$20]
Restart4::
	jp HaltForever
section "Restart handler 5", ROM0 [$28]
Restart5::
	jp HaltForever
section "Restart handler 6", ROM0 [$30]
Restart6::
	jp HaltForever
section "Restart handler 7", ROM0 [$38]
Restart7::
	jp HaltForever

; Warning: each of these sections can only be 8b long!
section "VBlank Interrupt handler", ROM0 [$40]
; triggered upon VBLANK period starting
IntVBlank::
	reti
section "LCDC Interrupt handler", ROM0 [$48]
; Also known as STAT handler
; LCD controller changed state
IntLCDC::
	reti
section "Timer Interrupt handler", ROM0 [$50]
; A configurable amount of time has passed
IntTimer::
	; We do this inline for speed, even though it overruns the section.
	; We aren't going to use Serial or Joypad interrupts.
	; We have a budget of TimerModulo * 4 cycles, which right now is 64 cycles.
	; Our worst-case path right now is 43 cycles, not including however long interrupt servicing is.
	push AF
	push HL
	ld H, HIGH(Samples)
	ld A, [SampleBit]
	dec A
	ld [SampleBit], A
	ld A, [SampleIndex]
	ld L, A
	jr nz, .noNextIndex
	inc A
	jr z, .stopSampling ; when Index wraps, we're done. Don't take a sample, and disable timer interrupt.
	ld [SampleIndex], A ; [SampleIndex] += 1
	ld A, 8
	ld [SampleBit], A ; [SampleBit] = 7
.noNextIndex
	ld A, [CGBInfrared]
	cpl ; A = ~A
	rra
	rra ; shift A right twice, putting bit 1 into carry
	ld A, [HL] ; A = current sample at SampleIndex
	rla ; shift new reading from carry into saved value, pushing other saved values up
	ld [HL], A ; write back updated sample
	pop HL
	pop AF
	reti
.stopSampling
	ld A, [InterruptsEnabled]
	res 2, A ; disable timer int
	ld [InterruptsEnabled], A
	pop HL
	pop AF
	reti

section "Core Utility", ROM0
HaltForever::
	halt
	; halt can be recovered from after an interrupt or reset, so halt again
	jp HaltForever

section "Header", ROM0 [$100]
; This must be nop, then a jump, then blank up to 150
_Start:
	nop
	jp Start
_Header::
	ds 76 ; Linker will fill this in
