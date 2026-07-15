local Util = {}

function Util.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[Util.deepCopy(key)] = Util.deepCopy(child)
	end
	return copy
end

function Util.reconcile(target, template)
	for key, defaultValue in pairs(template) do
		if target[key] == nil then
			target[key] = Util.deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(target[key]) == "table" then
			Util.reconcile(target[key], defaultValue)
		end
	end
	return target
end

function Util.findIndex(list, value)
	for index, item in ipairs(list) do
		if item == value then
			return index
		end
	end
	return nil
end

function Util.clampNumber(value, minimum, maximum, fallback)
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

return table.freeze(Util)
