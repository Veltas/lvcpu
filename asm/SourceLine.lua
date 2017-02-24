local Validate = require("Validate")

local SourceLine = {
	file = nil,
	line = nil,
	contents = nil
}

function SourceLine.New(class, self)
	Validate(self, {file = "string", line = "number", contents = "string"})
	setmetatable(self, {__index = class})
	return self
end

return SourceLine
