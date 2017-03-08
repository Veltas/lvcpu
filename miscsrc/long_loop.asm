; This program loops for a long time, for profiling the CPU simulator
; 1006247425 clock cycles

	MOV C, 0x09FF

loop1:
		MOV A, 0xFFFF
loop2:
			ADD A, -1
			JNZ loop2
		ADD C, -1
		JNZ loop1
	STOP
