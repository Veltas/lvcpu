; This program loops for a long time, for profiling the CPU simulator
; 100270849 clock cycles

	MOV C, 0xFF

loop1:
		MOV A, 0xFFFF
loop2:
			ADD A, -1
			JNZ loop2
		ADD C, -1
		JNZ loop1
	STOP
