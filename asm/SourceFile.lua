local Validate = require("Validate")

local SourceLine = require("SourceLine")

local SourceFile = {
	rootFilename = nil,
	lines = nil
}

local function LoadFile(filename, sourceLines, insertIndex)
	insertIndex = insertIndex or 1
	local currentIndex = insertIndex
	local lineNumber = 1
	for line in io.lines(filename) do
		if line:find("^%.include%s+\"[^\"]+\"") then
			local includedFile = line:match("^%.include%s+\"([^\"]+)\"")
			_, currentIndex = LoadFile(includedFile, sourceLines, currentIndex)
		elseif not line:find("^%s*$") then
			local sourceLine = SourceLine:New{
				file = filename,
				line = lineNumber,
				contents = line
			}
			table.insert(sourceLines, currentIndex, sourceLine)
			currentIndex = currentIndex + 1
		end
		lineNumber = lineNumber + 1
	end
	return insertIndex, currentIndex
end

function SourceFile:New(obj)
	Validate(obj, {rootFilename = "string"})
	self.__index = self
	setmetatable(obj, self)
	obj.lines = {}
	LoadFile(obj.rootFilename, obj.lines)
	return obj
end

return SourceFile
