; Low level library for kernel, to e.g. print error diagnostics

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PanicMessage(n16 errorString) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PanicMessage:
  PUSH BP
  MOV BP, SP

  ; Output "LOG"
  MOV AL, 'L'
  OUT
  MOV AL, 'O'
  OUT
  MOV AL, 'G'
  OUT

  ; Output message

  MOV AL, [BP+4]
  MOV CL, AL
  MOV AL, [BP+5]
  MOV CH, AL

PanicMessage__Loop:
  MOV AL, [C]
  ADD AL, 0
  JZ PanicMessage__End

  OUT
  INC C
  JP PanicMessage__Loop

PanicMessage__End:

  ; Output '\n'
  MOV AL, 10
  OUT

  MOV SP, BP
  POP BP
  RET

; PanicValue(n16 
