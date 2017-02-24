local Validate = require("Validate")

local Instruction = {
	sourceLine = nil,
	type = nil,
	p1 = nil,
	p2 = nil,
	code = nil
}

function Instruction.New(class, self)
	Validate(self, {sourceLine = "table"})
	setmetatable(self, {__index = class})
	print(self)
	return self
end

local nParams = {
	NOP  = 0,
	ADD  = 2,
	SUB  = 2,
	INC  = 1,
	DEC  = 1,
	NEG  = 1,
	AND  = 2,
	OR   = 2,
	XOR  = 2,
	ROT  = 2,
	SFT  = 2,
	MUL  = 2,
	MOV  = 2,
	SWP  = 0,
	PUSH = 1,
	POP  = 1,
	JP   = 1,
	JZ   = 1,
	JC   = 1,
	JNZ  = 1,
	JNC  = 1,
	CALL = 1,
	INT  = 1,
	RET  = 0,
	IRET = 0,
	EIH  = 0,
	DIH  = 0,
	ESI  = 0,
	DSI  = 0,
	ECI  = 0,
	DCI  = 0,
	IN   = 0,
	OUT  = 0,
	STOP = 0,
	DB   = 1
}

local regNames = {
	AH = true,
	AL = true,
	A  = true,
	CH = true,
	CL = true,
	C  = true,
	SP = true,
	BP = true,
	F  = true,
	T  = true,
	IP = true,
	IC = true
}

local regNamesG8 = {
	AL = 0,
	AH = 1,
	CL = 2,
	CH = 3
}

local regNamesG16 = {
	A = 0,
	C = 1
}

local regNamesR16 = {
	A  = 0,
	C  = 1,
	SP = 2,
	BP = 3
}

local function NumToNBit(num, n)
	if num % 1 ~= 0 then
		return nil
	end
	local max = 1 << n
	if num < 0 then
		num = num + max
	end
	if not (num >= 0 and num < max) then
		return nil
	end
	return num
end

local function WordToReg(str)
	return regNames[str] and str
end

local function WordToLabel(str)
	return str:match("^([%a_][%w_]*)$")
end

local function WordToNum(str)
	return str:match("^([%+%-]?0[xX]%x+)$") or str:match("^([%+%-]?%d+)$")
end

local function WordToString(str)
	return str:match("^\"(.*)\"")
end

local function WordToChar(str)
	return str:match("^\'(.)\'$")
end

local codeGenerators = {
	NOP = function(self, references)
		return {0x00}
	end,
	ADD = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected p1 of ADD to be register")
		if regNamesG8[reg1] then
			if regNamesG8[p2] then
				return {0x01, 16 * regNamesG8[reg1] + regNamesG8[p2]}
			else
				local num = WordToNum(p2)
				local char = WordToChar(p2)
				if not num and not char then
					error("Expected g8 register or number for p2 in ADD")
				end
				if char then
					num = char:byte()
				end
				num = NumToNBit(tonumber(num), 8) or error("p2 in ADD was not an 8-bit value")
				return {0xE0 + regNamesG8[reg1], num}
			end
		elseif regNamesR16[reg1] then
			if regNamesR16[p2] then
				return {0x02, 16 * regNamesR16[reg1] + regNamesR16[p2]}
			else
				local num, char, label = WordToNum(p2), WordToChar(p2), WordToLabel(p2)
				if char then
					return {0xF0 + regNamesR16[reg1], NumToNBit(char:byte(), 8), 0}
				elseif label then
					references[self] = label
					return {0xF0 + regNamesR16[reg1], true, true}
				elseif num then
					num = NumToNBit(tonumber(num), 16)
					return {0xF0 + regNamesR16[reg1], num % 256, num // 256}
				else
					error("Expected r16 register, number or label for p2 in ADD")
				end
			end
		else
			error("ADD p1 must be g8 or r16 register")
		end
	end,
	SUB = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected p1 of SUB to be register")
		if regNamesG8[reg1] then
			if not regNamesG8[p2] then
				error("Expected p2 of SUB to be g8 register as well")
			end
			return {0x03, 16 * regNamesG8[reg1] + regNamesG8[p2]}
		elseif regNamesR16[reg1] then
			if not regNamesR16[p2] then
				error("Expected p2 of SUB to be r16 register as well")
			end
			return {0x04, 16 * regNamesR16[reg1] + regNamesR16[p2]}
		else
			error("SUB p1 must be g8 or r16 register")
		end
	end,
	INC = function(self, references, p1)
		if p1 ~= "C" then
			error("INC only valid with C register as parameter")
		end
		return {0x05}
	end,
	DEC = function(self, references, p1)
		if p1 ~= "C" then
			error("DEC only valid with C register as parameter")
		end
		return {0x06}
	end,
	NEG = function(self, references, p1)
		local reg1 = WordToReg(p1) or error("Expected register parameter to NEG")
		if regNamesG8[reg1] then
			return {0x07, regNamesG8[reg1]}
		elseif regNamesG16[reg1] then
			return {0x07, 0x10 + regNamesG16[reg1]}
		else
			error("NEG takes g8 or g16 registers as parameter")
		end
	end,
	AND = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected register for p1 of AND")
		if regNamesG8[reg1] then
			if regNamesG8[p2] then
				return {0x08, 16 * regNamesG8[reg1] + regNamesG8[p2]}
			end
		end
		error("AND takes g8 registers")
	end,
	OR = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected register for p1 of OR")
		if regNamesG8[reg1] then
			if regNamesG8[p2] then
				return {0x09, 16 * regNamesG8[reg1] + regNamesG8[p2]}
			end
		end
		error("OR takes g8 registers")
	end,
	XOR = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected register for p1 of XOR")
		if regNamesG8[reg1] then
			if regNamesG8[p2] then
				return {0x0A, 16 * regNamesG8[reg1] + regNamesG8[p2]}
			end
		end
		error("XOR takes g8 registers")
	end,
	ROT = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected register for p1 of ROT")
		if regNamesG8[reg1] then
			local num = WordToNum(p2) or error("p2 of ROT must be 3-bit value")
			num = NumToNBit(tonumber(num), 3) or error("p2 of ROT must be 3-bit value")
			return {0x0B, 16 * regNamesG8[reg1] + num}
		end
		error("ROT takes a g8 register and a 3-bit number")
	end,
	SFT = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected register for p1 of SFT")
		if regNamesG8[reg1] then
			local num = WordToNum(p2) or error("p2 of SFT must be 4-bit value")
			num = NumToNBit(tonumber(num), 4) or error("p2 of SFT must be 4-bit value")
			return {0x0C, 16 * regNamesG8[reg1] + num}
		end
		error("SFT takes a g8 register and a 4-bit number")
	end,
	MUL = function(self, references, p1, p2)
		local reg1 = WordToReg(p1) or error("Expected register for p1 of XOR")
		if regNamesG8[reg1] then
			if regNamesG8[p2] then
				return {0x0D, 16 * regNamesG8[reg1] + regNamesG8[p2]}
			end
		elseif reg1 == "A" then
			 if regNamesG8[p2] then
				return {0x0D, 16 * 4 + regNamesG8[p2]}
			end
		end
		error("MUL p1 should be A or a g8 register")
	end,
	MOV = function(self, references, p1, p2)
		local reg1 = WordToReg(p1)
		if reg1 then
			if regNamesG8[reg1] then
				if regNamesG8[p2] then
					return {0x20, 16 * regNamesG8[reg1] + regNamesG8[p2]}
				elseif WordToNum(p2) then
					local num = WordToNum(p2)
					num = NumToNBit(tonumber(num), 8) or error("MOV to g8 register takes 8-bit literal")
					return {0x80 + regNamesG8[reg1], num}
				elseif WordToChar(p2) then
					local char = WordToChar(p2)
					return {0x80 + regNamesG8[reg1], NumToNBit(char:byte(), 8)}
				elseif reg1 == "AL" then
					if p2 == "F" then
						return {0x22, 0x01}
					elseif p2 == "IC" then
						return {0x22, 0x02}
					elseif p2 == "T" then
						return {0x2B}
					end
					local bpoffset = p2:match("^%[BP([%+%-]%d+)%]$")
					if bpoffset then
						bpoffset = NumToNBit(tonumber(bpoffset), 8) or error("MOV BP offsets should be 8-bit signed values")
						return {0x23, bpoffset}
					elseif p2:find("^%[BP%]$") then
						return {0x23, 0}
					elseif p2:find("^%[C%]$") then
						return {0x24}
					end
				end
			elseif reg1 == "T" then
				if p2 == "AL" then
					return {0x2C}
				end
			elseif regNamesR16[reg1] then
				if regNamesR16[p2] then
					return {0x21, 16 * regNamesR16[reg1] + regNamesR16[p2]}
				elseif WordToNum(p2) then
					local num = WordToNum(p2)
					num = NumToNBit(tonumber(num), 16) or error("MOV to r16 register takes 16-bit literal")
					return {0x90 + regNamesR16[reg1], num % 256, num // 256}
				elseif WordToLabel(p2) then
					local label = WordToLabel(p2)
					references[self] = label
					return {0x90 + regNamesR16[reg1], true, true}
				elseif WordToChar(p2) then
					local char = WordToChar(p2)
					return {0x90 + regNamesR16[reg1], NumToNBit(char:byte(), 8), 0}
				elseif reg1 == "A" then
					local bpoffset = p2:match("^%[BP([%+%-]%d+)%]$")
					if p2 == "IP" then
						return {0x22, 0x03}
					elseif bpoffset then
						bpoffset = NumToNBit(tonumber(bpoffset), 8) or error("MOV BP offsets should be 8-bit signed values")
						return {0x29, bpoffset}
					elseif p2:find("^%[BP%]$") then
						return {0x29, 0}
					elseif p2:find("^%[C%]$") then
						return {0x2A}
					end
				end
			end
		elseif p1:find("^%[BP[%+%-]?%d*%]$") then
			local bpoffset = p1:match("^%[BP([%+%-]%d+)%]$")
			if bpoffset then
				bpoffset = WordToNum(bpoffset) or error("MOV to BP offset takes 8-bit offset: a number")
				bpoffset = NumToNBit(tonumber(bpoffset), 8) or error("MOV to BP offset requires 8-bit offset")
				if p2 == "AL" then
					return {0x25, bpoffset}
				elseif p2 == "A" then
					return {0x2D, bpoffset}
				end
			elseif p1:find("^%[BP%]$") then
				if p2 == "AL" then
					return {0x25, 0}
				elseif p2 == "A" then
					return {0x2D, 0}
				end
			end
		elseif p1:find("^%[C%]$") then
			if p2 == "AL" then
				return {0x26}
			elseif p2 == "A" then
				return {0x2E}
			end
		end
		error("Malformed MOV statement")
	end,
	SWP = function(self, references)
		return {0x28}
	end,
	PUSH = function(self, references, p1)
		local reg1 = WordToReg(p1) or error("PUSH argument should be register")
		if regNamesG8[p1] then
			return {0xA0 + regNamesG8[p1]}
		elseif regNamesR16[p1] then
			return {0xB0 + regNamesR16[p1]}
		end
		error("PUSH takes g8 or r16 register")
	end,
	POP = function(self, references, p1)
		local reg1 = WordToReg(p1) or error("POP argument should be register")
		if regNamesG8[p1] then
			return {0xC0 + regNamesG8[p1]}
		elseif regNamesR16[p1] then
			return {0xD0 + regNamesR16[p1]}
		end
		error("POP takes g8 or r16 register")
	end,
	JP = function(self, references, p1)
		local num = WordToNum(p1)
		local label = WordToLabel(p1)
		if num then
			num = NumToNBit(tonumber(num), 16) or error("JP takes 16-bit values")
			return {0x40, num % 256, num // 256}
		elseif label then
			references[self] = label
			return {0x40, true, true}
		end
		error("JP takes 16-bit literal or label")
	end,
	JZ = function(self, references, p1)
		local num = WordToNum(p1)
		local label = WordToLabel(p1)
		if num then
			num = NumToNBit(tonumber(num), 16) or error("JZ takes 16-bit values")
			return {0x41, num % 256, num // 256}
		elseif label then
			references[self] = label
			return {0x41, true, true}
		end
		error("JZ takes 16-bit literal or label")
	end,
	JC = function(self, references, p1)
		local num = WordToNum(p1)
		local label = WordToLabel(p1)
		if num then
			num = NumToNBit(tonumber(num), 16) or error("JC takes 16-bit values")
			return {0x42, num % 256, num // 256}
		elseif label then
			references[self] = label
			return {0x42, true, true}
		end
		error("JC takes 16-bit literal or label")
	end,
	JNZ = function(self, references, p1)
		local num = WordToNum(p1)
		local label = WordToLabel(p1)
		if num then
			num = NumToNBit(tonumber(num), 16) or error("JNZ takes 16-bit values")
			return {0x43, num % 256, num // 256}
		elseif label then
			references[self] = label
			return {0x43, true, true}
		end
		error("JNZ takes 16-bit literal or label")
	end,
	JNC = function(self, references, p1)
		local num = WordToNum(p1)
		local label = WordToLabel(p1)
		if num then
			num = NumToNBit(tonumber(num), 16) or error("JNC takes 16-bit values")
			return {0x44, num % 256, num // 256}
		elseif label then
			references[self] = label
			return {0x44, true, true}
		end
		error("JNC takes 16-bit literal or label")
	end,
	CALL = function(self, references, p1)
		local num = WordToNum(p1)
		local label = WordToLabel(p1)
		if num then
			num = NumToNBit(tonumber(num), 16) or error("CALL takes 16-bit literals")
			return {0x48, num % 256, num // 256}
		elseif label then
			references[self] = label
			return {0x48, true, true}
		elseif p1:find("^%[A%]$") then
			return {0x49}
		end
		error("Bad CALL format")
	end,
	INT = function(self, reference, p1)
		local num = WordToNum(p1) or error("INT takes an 8-bit literal")
		num = NumToNBit(tonumber(p1)) or error("INT takes an 8-bit literal")
		return {0x4A, num}
	end,
	RET = function(self, reference)
		return {0x4B}
	end,
	IRET = function(self, reference)
		return {0x4C}
	end,
	EIH = function(self, reference)
		return {0x50}
	end,
	DIH = function(self, reference)
		return {0x51}
	end,
	ESI = function(self, reference)
		return {0x52}
	end,
	DSI = function(self, reference)
		return {0x53}
	end,
	ECI = function(self, reference)
		return {0x54}
	end,
	DCI = function(self, reference)
		return {0x55}
	end,
	IN = function(self, reference)
		return {0x60}
	end,
	OUT = function(self, reference)
		return {0x61}
	end,
	STOP = function(self, reference)
		return {0x70}
	end,
	DB = function(self, reference, p1)
		local contents = self.sourceLine.contents:match("^%s+%u%u+%s+(.-)$") or error("DB given without data")
		if WordToString(contents) then
			local stringContents = WordToString(contents)
			local resultData = {}
			for i = 1, #stringContents do
				resultData[i] = stringContents:sub(i, i):byte()
			end
			return resultData
		elseif WordToChar(p1) then
			local char = WordToChar(p1)
			return {char:byte()}
		elseif WordToNum(p1) then
			local num = WordToNum(p1)
			num = NumToNBit(tonumber(num), 8) or error("DB only takes 8-bit literals")
			return {num}
		elseif WordToLabel(p1) then
			local label = WordToLabel(p1)
			reference[self] = label
			return {true, true}
		end
		error("DB takes a string, char, or 8-bit literal")
	end
}

local function LineToInstructionType(str)
	return str:match("^%s+(%u%u+)")
end

local function LineToParams1(str)
	return str:match("^%s+%u%u+%s+(%S+)")
end

local function LineToParams2(str)
	return str:match("^%s+%u%u+%s+(%S+)%s*,%s*(%S+)")
end

function Instruction:LoadFromLine(references)
print(self.type)
	self.type = LineToInstructionType(self.sourceLine.contents)
	if not self.type then
		return false
	elseif not nParams[self.type] then
		error("Given unrecognised instruction " .. self.type)
	end
	if nParams[self.type] == 1 then
		self.p1 = LineToParams1(self.sourceLine.contents)
	elseif nParams[self.type] == 2 then
		self.p1, self.p2 = LineToParams2(self.sourceLine.contents)
	end
	self.code = codeGenerators[self.type](self, references, self.p1, self.p2)
	return true
end

return Instruction
