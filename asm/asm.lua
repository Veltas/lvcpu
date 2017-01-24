package.path = arg[0]:gsub("[^/]*$", "") .. "?.lua;" .. package.path

print = function () end
unpack = table.unpack

function table.maxn(t)
	local currentMax = 0
	for k, v in pairs(t) do
		if type(k) == "number" and k%1 == 0 then
			if k > currentMax then
				currentMax = k
			end
		end
	end
	return currentMax
end

local C_SourceFile = require("SourceFile")
local C_ObjectFile = require("ObjectFile")

local sourceFile = C_SourceFile:New{rootFilename = arg[1]}
local objectFile = C_ObjectFile:New{sourceFile = sourceFile}
objectFile:WriteBinary(arg[2])
