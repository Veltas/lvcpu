local Validate = require("Validate")

local SourceLine = {
	file = nil,
	line = nil,
	contents = nil
}

function SourceLine:New(obj)
	Validate(obj, {file = "string", line = "number", contents = "string"})
	setmetatable(obj, self)
	self.__index = self
	return obj
end

return SourceLine
