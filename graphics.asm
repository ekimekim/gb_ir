include "hram.asm"
include "ioregs.asm"
include "longcalc.asm"

; These methods govern access to VRAM.
; We need to be careful when accessing VRAM during vblank, because timer interrupts
; could still fire at any moment.
; Our approach is to enqueue writes to a queue. During vblank, we do the next operation,
; then check we're still in vblank. If we are, it worked and can be dequeued. Otherwise,
; it needs to be left on the queue to be repeated later.

SECTION "Graphics ram", WRAM0

; GrpahicsQueue is a 256-entry ring.
; Head is the position to be next inserted.
; Tail is the position to be next read.
; When head == tail, ring is empty.
; When head == tail - 1, ring is full.
GraphicsQueueHead:
	db
GraphicsQueueTail:
	db

GraphicsQueueAddrs:
	ds 256 * 2

SECTION "Graphics Aligned RAM", WRAM0, ALIGN[8]

GraphicsQueueValues:
	ds 256


SECTION "Graphics methods", ROM0


GraphicsInit::
	; init queue
	xor A
	ld [GraphicsQueueHead], A
	ld [GraphicsQueueTail], A
	; set up LCDStatus and LCDYCompare to fire when LY == 0, ie. when vblank ends.
	ld [LCDYCompare], A
	ld A, %01000100 ; trigger on LY == LYC
	ld [LCDStatus], A
	; Enable vblank and lcd status interrupts
	ld A, [InterruptsEnabled]
	or %00000011
	ld [InterruptsEnabled], A
	ret


VBlankHandler::
	push AF
	push BC
	push DE
	push HL

	; Prevent further vblanks but otherwise let interrupts continue
	ld A, [InterruptsEnabled]
	res 0, A
	ld [InterruptsEnabled], A

	; Set up flag to tell us when vblank ends
	xor A
	ld [VBlankEnded], A
	ei

	ld HL, GraphicsQueueTail
	ld B, HIGH(GraphicsQueueValues)
	ld A, [HL+]
	ld C, A ; C = graphics tail. since Values is aligned, BC = offset into Values to read.
	; Note HL is now GraphicsQueueAddrs

	LongAddToA HL, HL ; HL = addrs + c
	ld A, C
	LongAddToA HL, HL ; HL = addrs + 2C, ie. HL = offset into Addrs to read.

	; Check if queue is empty
	ld A, [GraphicsQueueHead]
	cp C ; set z if head == tail and queue is empty
	jr z, .finish

.loop
	; Do one operation
	ld A, [HL+]
	ld D, A
	ld A, [HL+]
	ld E, A ; DE = next addr
	ld A, [BC]
	ld [DE], A ; write next value to next addr

	; Check if we're still in vblank
	ld A, [VBlankEnded]
	and A ; set z if we're still in vblank
	jr nz, .finish

	; Success - advance tail
	inc C ; set z on overflow
	jr z, .overflow ; since overflow is rare we optimize for the non-taken case

.post_overflow
	; Check if queue is empty
	ld A, [GraphicsQueueHead]
	cp C ; set z if head == tail and queue is empty
	jr nz, .loop

.finish

	; Write back updated tail value
	ld A, C
	ld [GraphicsQueueTail], A

	; Re-enable vblank, but also clear it in case there's one pending
	ld A, [InterruptFlags]
	res 0, A
	ld [InterruptFlags], A
	ld A, [InterruptsEnabled]
	set 0, A
	ld [InterruptsEnabled], A

	pop HL
	pop DE
	pop BC
	pop AF
	ret

.overflow
	; wrap HL on overflow
	ld HL, GraphicsQueueAddrs
	jr .post_overflow


; Enqueue a VRAM write of value B to DE.
; May block indefinitely until there is space in the queue.
; Clobbers A, C, HL.
GraphicsWrite::
	ld HL, GraphicsQueueHead
	ld A, [HL+] ; A = head. Note head can't change in interrupt, only tail.
	inc A
.wait_loop
	cp [HL] ; set z if head + 1 == tail, ie. we're full
	jr z, .wait_loop ; loop until we aren't full, as tail can be changed by interrupt
	ld C, A
	LongAddToA HL, HL ; HL += A, ie. HL = &tail + head + 1 = addrs + head
	ld A, C ; A = head + 1
	LongAddToA HL, HL ; HL += A, so now HL = addrs + 2*head + 1
	ld A, E
	ld [HL-], A ; set lower byte of addr and point HL at addrs + 2*head
	ld [HL], D ; set upper byte of addr
	ld H, HIGH(GraphicsQueueValues)
	ld L, C ; L = head + 1
	dec L ; L = head, ie. HL = values + head
	ld [HL], B ; set value
	ld A, C
	ld [GraphicsQueueHead], A ; set updated head. This must be last for interrupt safety.
	ret
