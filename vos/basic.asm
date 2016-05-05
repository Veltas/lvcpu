; OS basic utilities library

.include "string.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; u16 MultiplyU16(u16 x, u16 y) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns x*y

MultiplyU16:
  PUSH BP
  MOV BP, SP

  ; Store less significant part
  MOV AL, [BP+4]
  MOV CL, AL
  MOV AL, [BP+7]
  MOV AH, AL
  MOV AL, [BP+6]
  MUL A, CL
  PUSH A

  ; Calculate more significant part
  MOV AL, [BP+5]
  MOV CL, AL
  MOV AL, [BP+6]
  MUL AL, CL

  ; Multiply by 0x100
  MOV AH, AL
  MOV AL, 0

  ; Add all parts together
  POP C
  ADD A, C

  MOV SP, BP
  POP BP
  RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; i16 Multiply16(i16 x, i16 y) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns x*y

Multiply16:
  PUSH BP
  MOV BP, SP

  ; Space for one check flag isResultNegative
  ADD SP, -1

  ; Check if x is negative
  MOV AL, [BP+5]
  MOV AH, 128
  AND AH, AL
  ADD AH, 0
  JZ Multiply16__XNotNegative

  ; If so, then we must store negative of the number
  MOV CH, AL
  MOV AL, [BP+4]
  MOV CL, AL
  NEG C
  PUSH C
  JP Multiply16__XCheckEnd

Multiply16__XNotNegative:
  ; If not then we store the original number
  PUSH AL
  MOV AL, [BP+4]
  PUSH AL

Multiply16__XCheckEnd:
  ; Store the check flag
  MOV AL, AH
  MOV [BP-1], AL

  ; Check if y is negative
  MOV AL, [BP+7]
  MOV AH, 128
  AND AH, AL
  ADD AH, 0
  JZ Multiply16__YNotNegative

  ; If so, then we must store negative of the number
  MOV CH, AL
  MOV AL, [BP+6]
  MOV CL, AL
  NEG C
  PUSH C
  JP Multiply16__YCheckEnd

Multiply16__YNotNegative:
  ; If not then we store the original number
  PUSH AL
  MOV AL, [BP+6]
  PUSH AL

Multiply16__YCheckEnd:
  ; XOR the check flag
  MOV AL, [BP-1]
  XOR AL, AH
  JZ Multiply16__JustMultiply

  ; One number was negative, multiply then return negative
  CALL MultiplyU16
  NEG A
  MOV SP, BP
  POP BP
  RET

Multiply16__JustMultiply:
  ; Neither or both numbers were negative, just return result
  CALL MultiplyU16
  MOV SP, BP
  POP BP
  RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; i8 FindFirstSet(n8 inputByte) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns first set digit, or -1 if given 0


