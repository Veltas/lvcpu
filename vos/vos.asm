; Veltas OS

; Calling convention:
; All registers are scratch other than SP and BP.
; Arguments are pushed onto stack in reverse order.
; Return value or return pointer (if any) is given in A or AL.
; Caller removes arguments from stack.

; Interrupt mode convention:
; Shadow registers can change indeterminately while interrupts are enabled.
; Disabling interrupts will disable most hardware functions and the clock
; interrupt.

;;;;;;;;;;;;;
; Boot code ;
;;;;;;;;;;;;;
.org 0x0000

	; Start stack at end of memory
	MOV SP, 0xFFFF



	; Load interrupt table and enable interrupt handling
	MOV AL, 1
	MOV T, AL
	EIH

;;;;;;;;;;;;;;;;;;;
; Interrupt table ;
;;;;;;;;;;;;;;;;;;;
; INT 0x00 - Invalid instruction error
.org 0x0800
	MOV A, vos_invalidInstructionError
	PUSH A
	CALL PanicMessage
	STOP

; INT 0x01 - Instruction counter zero
.org 0x0810
	SWP
	PUSH A

	POP A
	SWP
	IRET

; INT 0x02 - Memory error
.org 0x0820
	STOP

; INT 0x03 - Double fault error
.org 0x0830
	MOV A, vos_doubleFaultError
	PUSH A
	CALL PanicMessage
	STOP

; INT 0x04 - Step interrupt
.org 0x0840
	IRET

;;;;;;;;;;;;;;;;
; Main OS Code ;
;;;;;;;;;;;;;;;;
.org 0x1000 ; Main OS code

vos_invalidInstructionError:
	DB "Invalid instruction error!"
	DB 0

vos_doubleFaultError:
	DB "Double fault error!"
	DB 0

.include "low.asm"

.include "basic.asm"
