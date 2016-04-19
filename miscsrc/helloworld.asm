.org 0x0000

  MOV C, helloWorld
  MOV AL, [C]
  ADD AL, 0
  JZ l2
l1:
  OUT
  INC C
  MOV AL, [C]
  ADD AL, 0
  JNZ l1
l2:
  STOP

helloWorld:
  DB "Hello, world!"
  DB 0x0A
  DB 0
