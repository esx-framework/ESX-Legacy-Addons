---@alias VerifyType 'number' | 'boolean' | 'function' | 'table' | 'string' | 'nil' | 'array' | 'int' | 'uint' | 'float' | 'vector3' | 'vector4' | 'callable'

---Checks if value is an array (sequential integer keys)
---@param value any
---@return boolean
local function isArray(value)
	if type(value) ~= 'table' then
		return false
	end

	local i = 0
	for _ in pairs(value) do
		i = i + 1
		if value[i] == nil then
			return false
		end
	end
	return true
end

---Checks if value is callable (function or table with __call)
---@param value any
---@return boolean
local function isCallable(value)
	local valueType = type(value)
	if valueType == 'function' then
		return true
	end
	if valueType == 'table' then
		local mt = getmetatable(value)
		if mt and mt.__call then
			return true
		end
	end
	return false
end

---Verifies a single type
---@param value any
---@param validType VerifyType
---@return boolean
local function verifyType(value, validType)
	if validType == 'function' or validType == 'callable' then
		return isCallable(value)
	elseif validType == 'array' then
		return isArray(value)
	elseif validType == 'int' then
		return math.type(value) == 'integer'
	elseif validType == 'float' then
		return math.type(value) == 'float'
	elseif validType == 'uint' then
		return math.type(value) == 'integer' and value >= 0
	elseif validType == 'vector3' then
		return type(value) == 'vector3'
	elseif validType == 'vector4' then
		return type(value) == 'vector4'
	end
	return type(value) == validType
end

---Main verify function
---@param value any Value to check
---@param validTypes VerifyType[] | VerifyType Single type or array of types
---@param throwError? boolean If true, throws error on mismatch (only when Config.Debug is true)
---@return boolean match
function Verify(value, validTypes, throwError)
	local match = false

	if type(validTypes) == 'table' then
		for i = 1, #validTypes do
			if Verify(value, validTypes[i]) then
				match = true
				break
			end
		end
	else
		match = verifyType(value, validTypes)
	end

	if throwError and not match and Config.Debug then
		error(('[esx_shops] Type mismatch: expected %s, got %s (%s)'):format(
			type(validTypes) == 'table' and table.concat(validTypes, ' or ') or validTypes,
			type(value),
			tostring(value)
		))
	end

	return match
end

---Debug-only verify (only throws when Config.Debug is true)
---@param value any
---@param validTypes VerifyType[] | VerifyType
---@param throwError? boolean
---@return boolean
function VerifyDebug(value, validTypes, throwError)
	if not Config.Debug then
		return true
	end
	return Verify(value, validTypes, throwError)
end
