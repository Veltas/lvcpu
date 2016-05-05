; Lemongrab OS

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

  ; Start system stack
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
  MOV SP, 0xFDFF
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

; INT 0x40 - System call
.org 0x0C00
  MOV C, vos_systemCallTable
  ADD C, A
  MOV A, [C]
  CALL [A]
  IRET

;;;;;;;;;;;;;;;;;;;;
; Main System Code ;
;;;;;;;;;;;;;;;;;;;;
.org 0x1000

vos_systemCallTable:
;  DB MemoryAllocate

vos_invalidInstructionError:
  DB "Invalid instruction error!"
  DB 0

vos_doubleFaultError:
  DB "Double fault error!"
  DB 0

.include "low.asm"
;.include "malloc.asm"
.include "basic.asm"

; Positioned assembly files must go at bottom of this file
.include "malloc_pool.asm"
