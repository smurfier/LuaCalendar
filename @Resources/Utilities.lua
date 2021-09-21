function Delim(input, Separator) -- Separates an input string by a delimiter
	local tbl = {}
	
	if type(input) ~= 'string' then
		print(string.format('Delim: Input must be a string. Received %s instead', type(input)))
		return {}
	end

	if not MultiType(Separator, 'nil|string') then
		print(string.format('Delim: Input #2 must be a string. Received %s instead. Using default value.', type(Separator)))
		Separator = '|'
	end
	
	local MatchPattern = string.format('[^%s]+', Separator or '|')
	
	for word in string.gmatch(input, MatchPattern) do
		table.insert(tbl, word:match('^%s*(.-)%s*$'))
	end

	return tbl
end -- Delim

Case = {
	lower = function(line)
		return line:lower()
	end,

	upper = function(line)
		return line:upper()
	end,

	title = function(line)
		local temp = function(first, rest)
			return first:upper() .. rest:lower()
		end
		return line:gsub('(%S)(%S*)', temp)
	end,

	sentence = function(line)
		local temp = function(sentence)
			local space, first, rest = sentence:match('(%s*)(.)(.*)')	
			return space .. first:upper() .. rest:lower():gsub("%si([%s'])", ' I%1')
		end
		return line:gsub('[^.!?]+', temp)
	end,

	none = function(line)
		return line
	end
} -- Case

-- Allow for existing but empty options and variables
Get = {
	Option = function(option, default)
		local input = SELF:GetOption(option)
		if input == '' then
			return default or ''
		else
			return input
		end
	end, -- GetOption
	
	NumberOption = function(option, default)
		return tonumber(SELF:GetOption(option)) or default or 0
	end, -- GetNumberOption
	
	Variable = function(option, default)
		local input = SKIN:GetVariable(option) or ''
		if input == '' then
			return default or ''
		else
			return input
		end
	end, -- GetVariable
	
	NumberVariable = function(option, default)
		local input = SKIN:GetVariable(option) or ''
		if input == '' then
			return default or 0
		else
			return SKIN:ParseFormula(input) or default or 0
		end
	end -- GetNumberVariable
} -- Get

function MultiType(input, types) -- Test an input against multiple types
	return not not types:find(type(input))
end -- MultiType

function indexof(t, value) -- Search a table for the first instance of a value
	for key, item in pairs(t) do
		if type(item) ~= type(value) then
			-- Do Nothing
		elseif item == value then
			return key
		end
	end
	return -1
end -- indexof

function includes(t, value)
	for key, item in pairs(t) do
		if (type(item) == type(value)) and (item == value) then
			return true
		end
	end
	return false
end