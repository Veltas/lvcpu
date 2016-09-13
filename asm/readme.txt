The lvcpu assembler
===================

Assembly instructions are based on the architecture summarised in cpu/arch.txt,
for example:

	add a, 43

Which adds 43 to the 16-bit A register.

Comments begin with a ; and finish at the end of the line.

Textual copy code in from another file with .include "path"

Labels
======

Labels can be given as C-style identifiers which are not assembly instruction
names, or register names (in any case).

Labels are declared by giving their names, and following by a colon:

	main:

Which declares a label called main, at the current code position.

You can specify the current code position with an .org directive:

	.org 0x3D0E

And you can make a label absolute, for position independent code, with the
.absolute directive:

	.absolute kernel_call
	kernel_call:

Parameters
==========

Instructions expect up to 2 parameters, which can be registers (referred to
as their 1-2 letter names, case insensitively), 8-bit numbers, 16-bit numbers,
or addressed locations (and addressed locations with offsets).

8-bit numbers
-------------

8-bit number parameters are a sum of these components:

Decimal literals -- 42
Hexadecimal literals -- 0x4F
Character literals -- 'A'
Labels

Additionally, #(added labels) - #(subtracted labels) must be 0.
(for this calculation absolute labels are ignored)

If the resultant value is not in the range [-128, 255], then an error will be
raised.

16-bit numbers
--------------

16-bit number parameters are a sum of these components:

Decimal literals -- 42
Hexadecimal literals -- 0x4F
Character literals -- 'A'
Labels

Additionally, #(added labels) - #(subtracted labels) must be 0 or 1
(for this calculation absolute labels are ignored)

If the resultant value is not a 16-bit signed or unsigned number it will be
truncated. If the #a-#s label calculation is 1 in position independent code,
then this value will be among those modified in the displacement step of
loading the code.

Addressed location with offset
------------------------------

When a parameter is an addressed location with an offset, you can specify
without any offset (to mean offset 0):

	[BP]

Or specify with any 8-bit number parameter:

	[BP + 3]
	[BP + lb1 - lb2]
	[BP + lb1 - lb2 - 5]
