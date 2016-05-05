;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Memory allocation pool library ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; RECOMMENDED READING
; ===================
; These functions manipulate system state, they should not be called by
; userspace programs, but instead indirectly through their respective system
; calls.
;   Other than text segments, programs get data segments and stack space. All
; other memory either belongs to associated threads with thread data segments
; and thread stack space, or from this allocation pool.
;   This allocation pool is appropriate for getting memory that is of a
; runtime-dependant size. There are some limitations of the technique we use,
; especially that this is a system-wide pool which will get fragmented as time
; goes on.
;   This implementation does not get significantly slower over time,
; but the fragmentation may limit the amount of larger allocated blocks
; feasible after running for some time. This effect will occur slowly, but
; regularly restarting may be necessary depending on usage. My primary advice
; to limit this effect is to avoid starting programs in parallel if any of them
; are expected to run for the duration of your usage.
;   Bookkeeping information is kept close to the allocated memory bodies, which
; means overrunning the bounds may corrupt the state of the entire allocation
; pool. The allocation pool can sometimes detect such corruption, which results
; in a system panic with an appropriate error message, although such corruption
; can go undetected with unpredictable results.

; Allocation pool starts at 0x8000, and ends at 0xCFFF.
; 12288 bytes for allocation, each allocation has some overhead in this pool.

; Allocated memory layout: (body size is at least 4)
; 16-bit size of body
; n-byte body
; 16-bit 0

; Free (unallocated) memory layout:
; 16-bit address of next free space link for this list or 0 (if end)
; 16-bit address of previous free space link for this list or 0 (if beginning)
; 16-bit size of body (for allocated)
; (n-4)-byte unused space
; 16-bit address of start of this free space

; These addresses are 0 for empty, or point to start of first link.
; The lists enumerate free memory spaces that were previously allocated memory.
malloc_freeLists:
	; Size 1
	DB 0
	DB 0
	; Size 2+
	DB 0
	DB 0
	; Size 4+
	DB 0
	DB 0
	; Size 8+
	DB 0
	DB 0
	; Size 16+
	DB 0
	DB 0
	; Size 32+
	DB 0
	DB 0
	; Size 64+
	DB 0
	DB 0
	; Size 128+
	DB 0
	DB 0
	; Size 256+
	DB 0
	DB 0
	; Size 512+
	DB 0
	DB 0
	; Size 1024+
	DB 0
	DB 0
	; Size 2048+
	DB 0x00
	DB 0x80

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; malloc_AllocateLink(u16 link, u16 size) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Turns a link into an allocation

malloc_AllocateLink:
	PUSH BP
	MOV BP, SP

	MOV A, [BP+4]
	MOV C, A
	MOV A, [C]

	; Store next pointer, isLast
	PUSH A

	; Check next pointer, store isLast
	ADD A, 0
	JZ malloc_AllocateLink__1_1
		MOV AL, 0
		PUSH AL
		JP malloc_AllocateLink__1_2
malloc_AllocateLink__1_1:
		MOV AL, 1
		PUSH AL
malloc_AllocateLink__1_2:

	ADD C, 3
	MOV AL, [C]
	MOV AH, AL
	DEC C
	MOV AL, [C]

	; Store prev pointer, isFirst
	ADD A, 0
	PUSH A
	JZ malloc_AllocateLink__2_1
		MOV AL, 1
		PUSH AL
		JP malloc_AllocateLink__2_2
malloc_AllocateLink__2_1:
		PUSH AL
malloc_AllocateLink__2_2:

	; Store body length
	ADD C, 3
	MOV AL, [C]
	MOV AH, AL
	DEC C
	MOV AL, [C]
	PUSH A

	MOV AL, [BP-3]
	ADD AL, 0
	JZ malloc_AllocateLink__3_1
		MOV AL, [BP-2]
		MOV CL, AL
		MOV AL, [BP-1]
		MOV CH, AL
		MOV AL, 0
		MOV [C], AL
		INC C
		MOV [C], AL


	MOV SP, BP
	POP BP
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; u16 MemoryAllocate(u16 nBytes) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns address of allocated area size nBytes, or 0.

MemoryAllocate:
	
