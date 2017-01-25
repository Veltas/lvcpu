local function Validate(obj, validationTable, recLevel)
	recLevel = recLevel or 0
	if type(obj) ~= "table" then
		error("Expected table", 3 + recLevel)
	end
	for k, v in pairs(validationTable) do
		if type(v) == "table" then
			if type(obj[k]) ~= "table" then
				error("Expected field "..tostring(k).." to be table.", 3 + recLevel)
			end
			Validate(obj[k], v, recLevel + 1)
		else
			if type(obj[k]) ~= v then
				error("Field " .. tostring(k) .. " expects " .. v, 3 + recLevel)
			end
		end
	end
end

return Validate
