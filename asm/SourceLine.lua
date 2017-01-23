local Validate = require("Validate")

local C_SourceLine = {
	file = nil,
	line = nil,
	contents = nil
}

function C_SourceLine:New(obj)
	Validate(obj, {file = "string", line = "number", contents = "string"})
	setmetatable(obj, self)
	self.__index = self
	return obj
end

return C_SourceLine
