local function Validate(obj, validationTable)
  if type(obj) ~= "table" then
    error("Failed validation, expected table")
  end
  for k, v in pairs(validationTable) do
    if type(v) == "table" then
      if type(obj[k]) ~= "table" then
        error("Failed validation, expected field "..tostring(k).." to be table.")
      end
      Validate(obj[k], v)
    else
      if type(obj[k]) ~= v then
        error("Failed validation, " .. tostring(k) .. " field should be " .. v .. " type.")
      end
    end
  end
end

return Validate
