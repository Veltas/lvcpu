local Validate = require("Validate")

local C_Instruction = require("Instruction")

local C_ObjectFile = {
  sourceFile = nil,
  bytes = nil,
  labels = nil,
  references = nil
}

local function CompileProgram(self)
  local bytes, labels, references = self.bytes, self.labels, self.references
  local target = 1
  for _, sourceLine in ipairs(self.sourceFile.lines) do
    ---[[
    xpcall(function ()
    --]]
      if not sourceLine.contents:find("^%s*;") then
        if sourceLine.contents:find("^.org%s+") then
          local orgPoint = sourceLine.contents:match("^.org%s+([%xx]+)")
          orgPoint = tonumber(orgPoint) or error("Given org point is not a number")
          target = orgPoint + 1
        elseif sourceLine.contents:find("^[_%a][_%w]*:") then
          local label = sourceLine.contents:match("^([_%a][_%w]*):")
          labels[label] = target-1
        else
          local instruction = C_Instruction:New{sourceLine = sourceLine}
print(instruction.sourceLine.contents)
          if instruction:LoadFromLine(references) then
            if references[instruction] then
              references[instruction] = {references[instruction], target}
            end
            for i, byte in ipairs(instruction.code) do
              assert(not bytes[target + i-1], "Overlapping bytes at address "..(target+i-1))
              assert(target + i <= 65536, "Program out of bounds")
              bytes[target + i-1] = byte
            end
            target = target + #instruction.code
          else
            error("Not a recognised instruction")
          end
        end
      end
    ---[[
    end,
    function (msg)
      io.stderr:write("Error encountered " .. sourceLine.file .. ":" .. sourceLine.line .. ":\n")
      io.stderr:write(msg .. "\n")
      os.exit()
    end)
    --]]
  end
end

function C_ObjectFile:New(obj)
  Validate(obj, {sourceFile = "table"})
  self.__index = self
  setmetatable(obj, self)
  obj.bytes = {}
  obj.labels = {}
  obj.references = {}
  CompileProgram(obj)
  return obj
end

local function LinkProgram(self)
  local bytes, labels, references = self.bytes, self.labels, self.references
  for _, refPair in pairs(references) do
    local label, target = unpack(refPair)
    local labelPos = labels[label] or error("Referenced label "..label.." not found")
    bytes[target+1] = labels[label]%256
    bytes[target+2] = math.floor(labels[label]/256)
  end
end

function C_ObjectFile:WriteBinary(filename)
  LinkProgram(self)
  local outFile = io.open(filename, "wb") or error("Failed to open "..filename)
  for i = 1, table.maxn(self.bytes) do
    assert(self.bytes[i] ~= true, "Program is not linked")
    outFile:write(string.char(self.bytes[i] or 0))
    print(self.bytes[i] or 0)
  end
  outFile:close()
end

return C_ObjectFile
