; OS basic utilities library

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; n16 MemCopy(n16 dest, n16 source, n16 amount) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns dest

MemCopy:
	PUSH BP
	MOV BP, SP

	; Store copy of dest
	MOV AL, [BP+5]
	PUSH AL
	MOV AL, [BP+4]
	PUSH AL

	; Check amount to copy
	MOV AL, [BP+9]
	MOV AH, AL
	MOV AL, [BP+8]
	ADD A, 0

	JZ MemCopy__LoopEnd
MemCopy__LoopStart:
		; Remember loop counter
		PUSH A

		; Read memory to copy
		MOV AL, [BP+6]
		MOV CL, AL
		MOV AL, [BP+7]
		MOV CH, AL
		MOV AL, [C]
		PUSH AL

		; Increment source address
		INC C
		MOV AL, CL
		MOV [BP+6], AL
		MOV AL, CH
		MOV [BP+7], AL

		; Write memory
		MOV AL, [BP+4]
		MOV CL, AL
		MOV AL, [BP+5]
		MOV CH, AL
		POP AL
		MOV [C], AL

		; Increment dest address
		INC C
		MOV AL, CL
		MOV [BP+4], AL
		MOV AL, CH
		MOV [BP+5], AL

		; Check amount remaining to copy
		POP A
		ADD A, -1

		JNZ MemCopy__LoopStart
MemCopy__LoopEnd:

	; Load return value
	POP A

	MOV SP, BP
	POP BP
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; n16 MemSet(n16 start, n16 amount, n8 value) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Sets all of [start, start+amount) to value, returns start

MemSet:
	PUSH BP
	MOV BP, SP

	MOV AL, [BP+7]
	MOV AH, AL
	MOV AL, [BP+6]

	MOV SP, A

	MOV CL, 0xE0
	AND AL, CL

	MOV C, A

	MOV AL, [BP+5]
	MOV AH, AL
	MOV AL, [BP+4]

	ADD SP, A

	ADD C, 0
	JZ MemSet__1_2

	MOV AL, [BP+8]
	MOV AH, AL

MemSet__1_1:
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		PUSH A
		ADD C, -32
		JNZ MemSet__1_1
MemSet__1_2:

	MOV AL, [BP+6]
	MOV AH, 0x1F
	AND AH, AL

	MOV AL, [BP+8]

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


