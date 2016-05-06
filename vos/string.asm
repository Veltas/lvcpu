; String and general memory manipulation library

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; n16 StringLength(n16 str) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns number of bytes preceding first 0 from str

StringLength:
  PUSH BP
  MOV BP, SP

  MOV A, [BP+4]
  MOV C, A

StringLength__1:
    MOV AL, [C]
    INC C
    ADD AL, 0
    JNZ StringLength__1

  DEC C
  MOV A, C

  MOV SP, BP
  POP BP
  RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; n16 StringCopy(n16 dest, n16 source) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns dest, copies data from source to dest: up to and including first 0

StringCopy:
  PUSH BP
  MOV BP, SP

  ; save start dest
  MOV A, [BP+4]
  PUSH A

  ; read byte
  MOV A, [BP+6]
  MOV C, A
  MOV AL, [C]

  ; check byte
  ADD AL, 0
  JZ StringCopy__1_2
StringCopy__1_1:
    ; store current byte
    PUSH AL

    ; save next read location
    INC C
    MOV A, C
    MOV [BP+6], A

    ; get write location
    MOV A, [BP+4]
    MOV C, A

    ; get current byte
    POP AL

    ; write byte
    MOV [C], AL

    ; save next write location
    INC C
    MOV A, C
    MOV [BP+4], A

    ; get read location
    MOV A, [BP+6]
    MOV C, A

    ; read byte
    MOV AL, [C]

    ; check byte
    ADD AL, 0
    JNZ StringCopy__1_1
StringCopy__1_2:

  ; write final byte
  MOV A, [BP+4]
  MOV C, A
  MOV AL, 0
  MOV [C], AL

  ; return start dest
  POP A
  MOV SP, BP
  POP BP
  RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; n16 MemCopy(n16 dest, n16 source, n16 amount) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Returns dest

MemCopy:
  PUSH BP
  MOV BP, SP

  ; Store copy of dest
  MOV A, [BP+4]
  PUSH A

  ; Check amount to copy
  MOV A, [BP+8]
  ADD A, 0
  JZ MemCopy__LoopEnd

MemCopy__LoopStart:
    ; Remember loop counter
    PUSH A

    ; Read memory to copy
    MOV A, [BP+6]
    MOV C, A
    MOV AL, [C]
    PUSH AL

    ; Increment source address
    INC C
    MOV A, C
    MOV [BP+6], A

    ; Write memory
    MOV A, [BP+4]
    MOV C, A
    POP AL
    MOV [C], AL

    ; Increment dest address
    INC C
    MOV A, C
    MOV [BP+4], A

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

  ; get amount (in SP)
  MOV A, [BP+6]
  MOV SP, A

  ; get amount to do in fast-loop (in C)
  MOV CL, 0xE0
  AND AL, CL
  MOV C, A

  ; add start address to SP (end of destination)
  MOV A, [BP+4]
  ADD SP, A

  ; check fast-loop counter
  ADD C, 0
  JZ MemSet__1_2

  ; load setting value twice in AL and AH
  MOV AL, [BP+8]
  MOV AH, AL

; the fast-loop
MemSet__1_1:
    ; write value 32 times, decrementing write position
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

    ; decrement and check counter
    ADD C, -32
    JNZ MemSet__1_1
MemSet__1_2:

  ; calculate remaining write amount in AH
  MOV AL, [BP+6]
  MOV AH, 0x1F
  AND AH, AL

  ; get byte value
  MOV AL, [BP+8]

  ; check remaining bytes
  ADD AH, 0
  JZ MemSet__2_2

MemSet__2_1:
    ; write AL and decrement write location
    PUSH AL

    ; decrement and check counter
    ADD AH, -1
    JNZ MemSet__2_1
MemSet__2_2:

  ; return dest
  MOV A, [BP+4]
  MOV SP, BP
  POP BP
  RET
