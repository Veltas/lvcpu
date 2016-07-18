-- vim: syntax=lua:

local function Integer(n: value)
  assert(type(n) == "number")
  local i = math.tointeger(n)
  assert(i)
  return i
end

local function Number(n: value)
  assert(type(n) == "number")
  return n
end

local function String(str: value)
  assert(type(str) == "string")
  return str
end

local function ToBinary(val: integer)
  local bin: {boolean} = {false,false,false,false,false,false,false,false}
  for digit = 8,1,-1 do
    if val >= 128 then
      bin[digit] = true
    end
    val = val*2 - (bin[digit] and 256 or 0)
  end
  return bin
end

local function FromBinary(bin: {boolean})
  local unit, result = 1, 0
  for digit = 1,8 do
    if bin[digit] then
      result = result+unit
    end
    unit = unit*2
  end
  return result
end

local targetRate = Number(arg[1])

-- Memory size in kB
local memorySize = Integer(tonumber(arg[2])) * 1024

local inFile = io.open(String(arg[3]), "rb")
local outFile = io.open(String(arg[4]), "wb")

assert(inFile)
assert(outFile)

inFile:setvbuf("no")
outFile:setvbuf("no")

local binFile = io.open(String(arg[5]), "rb")
assert(binFile)

if arg[6] ~= "dump" then
  print = function (...) end
end

local memory: {integer} = {}
for i = 1, memorySize do
  memory[i] = 0
end

local powerOn = true

local reg = {
  AL = 0,
  AH = 0,
  CL = 0,
  CH = 0,
  F = 0,
  SP = 0,
  BP = 0,

  AL_ = 0,
  AH_ = 0,
  CL_ = 0,
  CH_ = 0,
  F_ = 0,
  SP_ = 0,
  BP_ = 0,

  T = 0,
  IC = 0,
  IP = 0,

  interruptLevel = 0,
  interruptHandling = false,
  clockInterrupt = false,
  --stepInterrupt = true,
}

local regLookup: {string: integer|boolean} = {}
setmetatable(regLookup, {__index = reg}, {__newindex = reg})

local clockPeriod = 1 / targetRate
local timeSample = os.clock()

local function SyncClock()
  while os.clock() - timeSample < clockPeriod do
  end
  timeSample = os.clock()
end

local function ReadMem(address: integer)
  if address >= memorySize then
    return 0
  else
    return Integer(memory[address + 1])
  end
end

local function WriteMem(address: integer, value: integer)
  if address < memorySize then
    memory[address + 1] = value
  end
end

local function AdvanceCpu()
  SyncClock()
  local result = ReadMem(reg.IP)
  reg.IP = (reg.IP + 1) % 65536
  return result
end

local reg8Names: {string} = {
  [0] = "AL",
  [1] = "AH",
  [2] = "CL",
  [3] = "CH"
}

local reg16Names: {string} = {
  [0] = "A",
  [1] = "C",
  [2] = "SP",
  [3] = "BP"
}

local function InvalidInstruction()
  if reg.interruptHandling then
    reg.interruptLevel = reg.interruptLevel + 1
    if reg.interruptLevel >= 3 then
      powerOn = false; return
    end
    local nextInstruction = reg.IP
    reg.AL_ = nextInstruction // 256
    reg.AH_ = nextInstruction % 256
    local code = reg.interruptLevel == 1 and 0x00 or 0x03
    reg.IP = (2048 * reg.T + 16 * code) % 65536
  end
end

local instructions: {() -> ()} = {
  [0x00] = function () -- NOP
  end,
  [0x01] = function () -- ADD g8, g8
    local param = AdvanceCpu()
    local reg1, reg2 = param // 16, param % 16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction()
      return
    end
    local result = Integer(regLookup[String(reg8Names[reg1])]) + Integer(regLookup[String(reg8Names[reg2])])
    local flags = result >= 256 and 2 or 0
    result = result % 256
    regLookup[String(reg8Names[reg1])] = result
    reg.F = flags + (regLookup[String(reg8Names[reg1])] == 0 and 1 or 0)
  end,
  [0x02] = function () -- ADD r16, r16
    local param = AdvanceCpu()
    local reg1, reg2 = math.floor(param / 16), param % 16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction()
      return
    end
    local reg2Value = 0
    if reg2 == 0 then
      reg2Value = 256 * reg.AH + reg.AL
    elseif reg2 == 1 then
      reg2Value = 256 * reg.CH + reg.CL
    elseif reg2 == 2 then
      reg2Value = reg.SP
    elseif reg2 == 3 then
      reg2Value = reg.BP
    end
    local reg1Value = 0
    if reg1 == 0 then
      reg1Value = 256 * reg.AH + reg.AL
      local result = reg1Value + reg2Value
      local flags = result >= 65536 and 2 or 0
      result = result % 65536
      reg.F = flags + (result == 0 and 1 or 0)
      reg.AH, reg.AL = result // 256, result % 256
    elseif reg1 == 1 then
      reg1Value = 256 * reg.CH + reg.CL
      local result = reg1Value + reg2Value
      local flags = result >= 65536 and 2 or 0
      result = result % 65536
      reg.F = flags + (result == 0 and 1 or 0)
      reg.CH, reg.CL = result // 256, result % 256
    elseif reg1 == 2 then
      reg1Value = reg.SP
      local result = reg1Value + reg2Value
      local flags = result >= 65536 and 2 or 0
      result = result % 65536
      reg.F = flags + (result == 0 and 1 or 0)
      reg.SP = result
    elseif reg1 == 3 then
      reg1Value = reg.BP
      local result = reg1Value + reg2Value
      local flags = result >= 65536 and 2 or 0
      result = result % 65536
      reg.F = flags + (result == 0 and 1 or 0)
      reg.BP = result
    end
  end,
  [0x03] = function () -- SUB g8, g8
    local param = AdvanceCpu()
    local reg1, reg2 = param // 16, param % 16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction()
      return
    end
    local result = Integer(regLookup[String(reg8Names[reg1])]) - Integer(regLookup[String(reg8Names[reg2])])
    result = result % 256
    regLookup[String(reg8Names[reg1])] = result
    reg.F = regLookup[String(reg8Names[reg1])] == 0 and 1 or 0
  end,
  [0x04] = function () -- SUB r16, r16
    local param = AdvanceCpu()
    local reg1, reg2 = param // 16, param % 16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction()
      return
    end
    local reg2Value = 0
    if reg2 == 0 then
      reg2Value = 256 * reg.AH + reg.AL
    elseif reg2 == 1 then
      reg2Value = 256 * reg.CH + reg.CL
    elseif reg2 == 2 then
      reg2Value = reg.SP
    elseif reg2 == 3 then
      reg2Value = reg.BP
    end
    local reg1Value = 0
    if reg1 == 0 then
      reg1Value = 256 * reg.AH + reg.AL
      local result = reg1Value - reg2Value
      result = result % 65536
      reg.F = (result == 0 and 1 or 0)
      reg.AH, reg.AL = result // 256, result % 256
    elseif reg1 == 1 then
      reg1Value = 256 * reg.CH + reg.CL
      local result = reg1Value - reg2Value
      result = result % 65536
      reg.F = (result == 0 and 1 or 0)
      reg.CH, reg.CL = result // 256, result % 256
    elseif reg1 == 2 then
      reg1Value = reg.SP
      local result = reg1Value - reg2Value
      result = result % 65536
      reg.F = (result == 0 and 1 or 0)
      reg.SP = result
    elseif reg1 == 3 then
      reg1Value = reg.BP
      local result = reg1Value - reg2Value
      result = result % 65536
      reg.F = (result == 0 and 1 or 0)
      reg.BP = result
    end
  end,
  [0x05] = function() -- INC C
    local result = (256*reg.CH + reg.CL + 1) % 65536
    reg.CH, reg.CL = result//256, result%256
  end,
  [0x06] = function() -- DEC C
    local result = (256*reg.CH + reg.CL - 1) % 65536
    reg.CH, reg.CL = result//256, result%256
  end,
  [0x07] = function() -- NEG g8 | NEG g16
    local param = AdvanceCpu()
    local regType, regParam = param//16, param%16
    if regType == 0 then
      if regParam > 3 then
        InvalidInstruction(); return
      end
      local index = String(reg8Names[regParam])
      regLookup[index] = (-Integer(regLookup[index]))%256
    elseif regType == 1 then
      if regParam > 1 then
        InvalidInstruction(); return
      elseif regParam == 0 then
        local result = (-(256*reg.AH+reg.AL)) % 65536
        reg.AH, reg.AL = result//256, result%256
      elseif regParam == 1 then
        local result = (-(256*reg.CH+reg.CL)) % 65536
        reg.CH, reg.CL = result//256, result%256
      end
    else
      InvalidInstruction(); return
    end
  end,
  [0x08] = function () -- AND g8, g8
    local param = AdvanceCpu()
    local reg1, reg2 = param//16, param%16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction(); return
    end
    local i1, i2 = String(reg8Names[reg1]), String(reg8Names[reg2])
    local bin1, bin2 = ToBinary(Integer(regLookup[i1])), ToBinary(Integer(regLookup[i2]))
    for i = 1,8 do
      bin1[i] = bin1[i] and bin2[i]
    end
    regLookup[i1] = FromBinary(bin1)
  end,
  [0x09] = function () -- OR g8, g8
    local param = AdvanceCpu()
    local reg1, reg2 = param//16, param%16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction(); return
    end
    local i1, i2 = String(reg8Names[reg1]), String(reg8Names[reg2])
    local bin1, bin2 = ToBinary(Integer(regLookup[i1])), ToBinary(Integer(regLookup[i2]))
    for i = 1,8 do
      bin1[i] = bin1[i] or bin2[i]
    end
    regLookup[i1] = FromBinary(bin1)
  end,
  [0x0A] = function () -- XOR g8, g8
    local param = AdvanceCpu()
    local reg1, reg2 = param//16, param%16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction(); return
    end
    local i1, i2 = String(reg8Names[reg1]), String(reg8Names[reg2])
    local bin1, bin2 = ToBinary(Integer(regLookup[i1])), ToBinary(Integer(regLookup[i2]))
    for i = 1,8 do
      bin1[i] = bin1[i] ~= bin2[i]
    end
    regLookup[i1] = FromBinary(bin1)
  end,
  [0x0B] = function () -- ROT g8, u3
    local param = AdvanceCpu()
    local regParam, num = param//16, param%16
    if regParam > 3 or num > 7 then
      InvalidInstruction(); return
    end
    local index = String(reg8Names[regParam])
    local bin, result = ToBinary(Integer(regLookup[index])), ToBinary(0)
    for i = 1,8 do
      result[(i+num-1)%8+1] = bin[i]
    end
    regLookup[index] = FromBinary(result)
  end,
  [0x0C] = function () -- SFT g8, i4
    local param = AdvanceCpu()
    local regParam, num = param//16, param%16
    if regParam > 3 then
      InvalidInstruction(); return
    end
    local index = String(reg8Names[regParam])
    local bin, result = ToBinary(Integer(regLookup[index])), ToBinary(0)
    if num < 8 then
      for i = 1,8-num do
        result[num+i] = bin[i]
      end
    else
      num = num - 16
      for i = 1,8-num do
        result[i] = bin[i+num]
      end
    end
    regLookup[index] = FromBinary(result)
  end,
  [0x0D] = function () -- MUL g8, g8 | MUL A, g8
    local param = AdvanceCpu()
    local reg1, reg2 = param//16, param%16
    if reg1 > 4 or reg2 > 3 then
      InvalidInstruction(); return
    end
    local num1 = 0
    if reg1 == 4 then
      num1 = 256*reg.AH + reg.AL
    else
      num1 = Integer(regLookup[String(reg8Names[reg1])])
    end
    local num2 = Integer(regLookup[String(reg8Names[reg1])])
    local result = num1 * num2
    reg.F = result >= 65536 and 2 or 0
    result = result%65536
    reg.AH, reg.AL = result//256, result%256
  end,
  [0x20] = function () -- MOV g8, g8
    local param = AdvanceCpu()
    local reg1, reg2 = param//16, param%16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction(); return
    end
    regLookup[String(reg8Names[reg1])] = Integer(regLookup[String(reg8Names[reg2])])
  end,
  [0x21] = function () -- MOV r16, r16
    local param = AdvanceCpu()
    local reg1, reg2 = param//16, param%16
    if reg1 > 3 or reg2 > 3 then
      InvalidInstruction(); return
    end
    if reg1 == 0 then
      if reg2 == 1 then
        reg.AH = reg.CH
        reg.AL = reg.CL
      elseif reg2 > 1 then
        reg.AH = Integer(regLookup[String(reg16Names[reg2])])//256
        reg.AL = Integer(regLookup[String(reg16Names[reg2])])%256
      end
    elseif reg1 == 1 then
      if reg2 == 0 then
        reg.CH = reg.AH
        reg.CL = reg.AL
      elseif reg2 > 1 then
        reg.CH = Integer(regLookup[String(reg16Names[reg2])])//256
        reg.CL = Integer(regLookup[String(reg16Names[reg2])])%256
      end
    else
      if reg2 == 0 then
        regLookup[String(reg16Names[reg1])] = 256*reg.AH + reg.AL
      elseif reg2 == 1 then
        regLookup[String(reg16Names[reg1])] = 256*reg.CH + reg.CL
      else
        regLookup[String(reg16Names[reg1])] = Integer(regLookup[String(reg16Names[reg2])])
      end
    end
  end,
  [0x22] = function () -- MOV AL, F | MOV AL, IC | MOV AL, IP
    local param = AdvanceCpu()
    if param == 0 or param > 3 then
      InvalidInstruction(); return
    end
    if param == 1 then
      reg.AL = reg.F
    elseif param == 2 then
      reg.AL = reg.IC
    elseif param == 3 then
      reg.AH, reg.AL = reg.IP//256, reg.IP%256
    end
  end,
  [0x2B] = function () -- MOV AL, T
    reg.AL = reg.T
  end,
  [0x2C] = function () -- MOV T, AL
    reg.T = reg.AL
  end,
  [0x23] = function () -- MOV AL, [BP+i8]
    local param = AdvanceCpu()
    if param >= 128 then
      param = param-256
    end
    reg.AL = ReadMem((reg.BP + param) % 65536)
  end,
  [0x29] = function () -- MOV A, [BP+i8]
    local param = AdvanceCpu()
    if param >= 128 then
      param = param-256
    end
    reg.AL = ReadMem((reg.BP + param) % 65536)
    reg.AH = ReadMem((reg.BP + param + 1) % 65536)
  end,
  [0x24] = function () -- MOV AL, [C]
    reg.AL = ReadMem(256*reg.CH+reg.CL)
  end,
  [0x2A] = function () -- MOV A, [C]
    reg.AL = ReadMem(256*reg.CH+reg.CL)
    reg.AH = ReadMem((256*reg.CH+reg.CL+1) % 65536)
  end,
  [0x25] = function () -- MOV [BP+i8], AL
    local param = AdvanceCpu()
    if param >= 128 then
      param = param-256
    end
    WriteMem((reg.BP + param) % 65536, reg.AL)
  end,
  [0x2B] = function () -- MOV [BP+i8], A
    local param = AdvanceCpu()
    if param >= 128 then
      param = param-256
    end
    WriteMem((reg.BP + param) % 65536, reg.AL)
    WriteMem((reg.BP + param + 1) % 65536, reg.AH)
  end,
  [0x26] = function () -- MOV [C], AL
    WriteMem(256*reg.CH+reg.CL, reg.AL)
  end,
  [0x2C] = function () -- MOV [C], A
    WriteMem(256*reg.CH+reg.CL, reg.AL)
    WriteMem((256*reg.CH+reg.CL+1) % 65526, reg.AH)
  end,
  [0x28] = function () -- SWP
    local temp = 0
    temp = reg.AH; reg.AH = reg.AH_; reg.AH_ = temp
    temp = reg.AL; reg.AL = reg.AL_; reg.AL_ = temp
    temp = reg.CH; reg.CH = reg.CH_; reg.CH_ = temp
    temp = reg.CL; reg.CL = reg.CL_; reg.CL_ = temp
    temp = reg.SP; reg.SP = reg.SP_; reg.SP = temp
    temp = reg.BP; reg.BP = reg.BP_; reg.BP = temp
    temp = reg.F; reg.F = reg.F_; reg.F_ = temp
  end,
  [0x40] = function () -- JP n16
    local p1 = AdvanceCpu()
    local p2 = AdvanceCpu()
    reg.IP = p1+256*p2
  end,
  [0x41] = function () -- JZ n16
    local p1 = AdvanceCpu()
    local p2 = AdvanceCpu()
    if reg.F == 1 or reg.F == 3 then
      reg.IP = p1+256*p2
    end
  end,
  [0x42] = function () -- JC n16
    local p1 = AdvanceCpu()
    local p2 = AdvanceCpu()
    if reg.F == 2 or reg.F == 3 then
      reg.IP = p1+256*p2
    end
  end,
  [0x43] = function () -- JNZ n16
    local p1 = AdvanceCpu()
    local p2 = AdvanceCpu()
    if reg.F == 0 or reg.F == 2 then
      reg.IP = p1+256*p2
    end
  end,
  [0x44] = function () -- JNC n16
    local p1 = AdvanceCpu()
    local p2 = AdvanceCpu()
    if reg.F == 0 or reg.F == 1 then
      reg.IP = p1+256*p2
    end
  end,
  [0x48] = function () -- CALL n16
    local p1 = AdvanceCpu()
    local p2 = AdvanceCpu()
    reg.SP = (reg.SP-2)%65536
    WriteMem(reg.SP, reg.IP%256)
    WriteMem((reg.SP+1)%65536, reg.IP//256)
    reg.IP = (p1+256*p2)%65536
  end,
  [0x49] = function () -- CALL [A]
    reg.SP = (reg.SP-2)%65536
    WriteMem(reg.SP, reg.IP%256)
    WriteMem((reg.SP+1)%65536, reg.IP//256)
    reg.IP = 256*reg.AH+reg.AL
  end,
  [0x4A] = function () -- INT n8
    local param = AdvanceCpu()
    if reg.interruptHandling then
      if not (param >= 0x40 and param <= 0x7F) then
        InvalidInstruction(); return
      end
      if reg.interruptLevel == 0 then
        reg.interruptLevel = 1
      end
      reg.AH_ = reg.IP//256
      reg.AL_ = reg.IP%256
    end
  end,
  [0x4B] = function () -- RET
    local returnAddress = ReadMem(reg.SP) + 256*ReadMem((reg.SP+1)%65536)
    reg.SP = (reg.SP+2)%65536
    reg.IP = returnAddress
  end,
  [0x4C] = function () -- IRET
    if reg.interruptLevel > 0 then
      reg.interruptLevel = reg.interruptLevel - 1
    end
    reg.IP = (256*reg.AH_+reg.AL_)%65536
  end,
  [0x50] = function () -- EIH
    reg.interruptHandling = true
  end,
  [0x51] = function () -- DIH
    reg.interruptHandling = false
  end,
  [0x52] = function () -- ECI
    reg.clockInterrupt = true
  end,
  [0x53] = function () -- DCI
    reg.clockInterrupt = false
  end,
  [0x54] = function () -- ESI
    --reg.stepInterrupt = true
  end,
  [0x55] = function () -- DSI
    --reg.stepInterrupt = false
  end,
  [0x60] = function () -- IN
    local input = inFile
    assert(input)
    local readChar = input:read(1)
    local readByte = 255
    if readChar then
      readByte = Integer(string.byte(String(readChar)))
    end
    reg.AL = readByte%256
  end,
  [0x61] = function () -- OUT
    local output = outFile
    assert(output)
    output:write(string.char(reg.AL))
  end,
  [0x70] = function () -- STOP
    powerOn = false
  end
}

local shortInstructions: {(integer) -> ()} = {
  [0x8] = function (firstByte: integer) -- MOV g8, n8
    local regParam = firstByte - 8*16
    local param = AdvanceCpu()
    if regParam > 3 then
      InvalidInstruction(); return
    end
    regLookup[String(reg8Names[regParam])] = param
  end,
  [0x9] = function (firstByte: integer) -- MOV r16, n16
    local regParam = firstByte - 9*16
    local p1 = AdvanceCpu()
    local p2 = AdvanceCpu()
    local param = p1+p2*256
    if regParam > 3 then
      InvalidInstruction(); return
    end
    if regParam == 0 then
      reg.AH, reg.AL = p2, p1
    elseif regParam == 1 then
      reg.CH, reg.CL = p2, p1
    else
      regLookup[String(reg16Names[regParam])] = param
    end
  end,
  [0xA] = function (firstByte: integer) -- PUSH g8
    local regParam = firstByte - 0xA*16
    if regParam > 3 then
      InvalidInstruction(); return
    end
    reg.SP = (reg.SP-1)%65536
    WriteMem(reg.SP, Integer(regLookup[String(reg8Names[regParam])]))
  end,
  [0xB] = function (firstByte: integer) -- PUSH r16
    local regParam = firstByte - 0xB*16
    if regParam > 3 then
      InvalidInstruction(); return
    end
    reg.SP = (reg.SP-2)%65536
    if regParam == 0 then
      WriteMem(reg.SP, reg.AL)
      WriteMem((reg.SP+1)%65536, reg.AH)
    elseif regParam == 1 then
      WriteMem(reg.SP, reg.CL)
      WriteMem((reg.SP+1)%65536, reg.CH)
    else
      local val = Integer(regLookup[String(reg16Names[regParam])])
      WriteMem(reg.SP, val%256)
      WriteMem((reg.SP+1)%65536, val//256)
    end
  end,
  [0xC] = function (firstByte: integer) -- POP g8
    local regParam = firstByte - 0xC*16
    if regParam > 3 then
      InvalidInstruction(); return
    end
    regLookup[String(reg8Names[regParam])] = ReadMem(reg.SP)
    reg.SP = (reg.SP+1)%65536
  end,
  [0xD] = function (firstByte: integer) -- POP r16
    local regParam = firstByte - 0xD*16
    if regParam > 3 then
      InvalidInstruction(); return
    end
    if regParam == 0 then
      reg.AL = ReadMem(reg.SP)
      reg.AH = ReadMem((reg.SP+1)%65536)
    elseif regParam == 1 then
      reg.CL = ReadMem(reg.SP)
      reg.CH = ReadMem((reg.SP+1)%65536)
    else
      regLookup[String(reg16Names[regParam])] = ReadMem(reg.SP) + 256*ReadMem((reg.SP+1)%65536)
    end
    reg.SP = (reg.SP+2)%65536
  end,
  [0xE] = function (firstByte: integer) -- ADD g8, n8
    local regParam = firstByte - 0xE*16
    local num = AdvanceCpu()
    if regParam > 3 then
      InvalidInstruction(); return
    end
    local result = Integer(regLookup[String(reg8Names[regParam])]) + num
    reg.F = result > 256 and 2 or 0
    result = result % 256
    reg.F = reg.F + (result == 0 and 1 or 0)
    regLookup[String(reg8Names[regParam])] = result
  end,
  [0xF] = function (firstByte: integer) -- ADD r16, n16
    local regParam = firstByte - 0xF*16
    local num1 = AdvanceCpu()
    local num2 = AdvanceCpu()
    local num = num1+256*num2
    if regParam > 3 then
      InvalidInstruction(); return
    end
    if regParam == 0 then
      local result = 256*reg.AH+reg.AL + num
      reg.F = result > 65536 and 2 or 0
      result = result % 65536
      reg.AH, reg.AL = result//256, result%256
    elseif regParam == 1 then
      local result = 256*reg.CH+reg.CL + num
      reg.F = result > 65536 and 2 or 0
      result = result % 65536
      reg.CH, reg.CL = result//256, result%256
    else
      local result = 256*reg.CH+reg.CL + num
      reg.F = result > 65536 and 2 or 0
      result = result % 65536
      regLookup[String(reg16Names[regParam])] = result
    end
  end
}

-- Load start of memory with given file
local currentMemPosition = 0
local readChar = binFile:read(1)
while readChar and currentMemPosition < memorySize do
  local readByte = Integer(string.byte(String(readChar)))
  WriteMem(currentMemPosition, readByte)
  currentMemPosition = currentMemPosition + 1
  readChar = String(binFile:read(1))
end

if currentMemPosition == memorySize then
  error("Memory too small for given program")
end

-- Run the CPU
while powerOn do
  if reg.interruptHandling then
    -- Trigger clock interrupts
    if reg.clockInterrupt and reg.IC == 0 and reg.interruptLevel == 0 then
      reg.interruptLevel = 1
      reg.AH_, reg.AL_ = reg.IP//256, reg.IP%256
      reg.IP = 2048*reg.T + 16
    end
  end
  -- Execute instruction
  local function f(v: integer) return ("%.2x"):format(v) end
  local function ff(v: integer) return ("%.4x"):format(v) end
  print("AH:"..f(reg.AH).." AL:"..f(reg.AL).." CH:"..f(reg.CH).." CL:"..f(reg.CL))
  print("SP:"..ff(reg.SP).." BP:"..ff(reg.BP).." F:"..f(reg.F))
  print("IP:"..ff(reg.IP).." IC:"..f(reg.IC).." il:"..tostring(reg.interruptLevel))
  local currentByte = AdvanceCpu()
  print(("%.2x\n"):format(currentByte))
  local currentInstruction, currentShortInstruction = instructions[currentByte], shortInstructions[currentByte//16]
  if currentInstruction then
    currentInstruction()
  elseif currentShortInstruction then
    currentShortInstruction(currentByte)
  else
    InvalidInstruction()
  end
  reg.IC = (reg.IC+1)%256
end
