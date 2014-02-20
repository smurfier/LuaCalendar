Scroll = {
	Position = 1,
	ItemHeight = 0,
	Folders = {},
}

Variables = {
	Style = 'Default',
	DayLabels = '',
	HideLastWeek = 0,
	EventFile = '#**@**#Calendars\\Holidays.xml',
	LabelText = '',
	LeadingZeroes = 0,
	MonthLabels = '',
	StartOnMonday = 0,
	NextFormat = '',
	ShowMoonPhases = 1,
	MoonColor = '',
	ShowEvents = 1,
	DisableScroll = 0,
}

function Initialize()
	if SKIN:GetVariable('MoonColor') == '' then
		SKIN:Bang('!SetOption', 'MoonColorFill', 'LineColor', '0,0,0,1')
	end
end -- Initialize

function Update()
	local fullpath = SKIN:GetVariable('EventFile'):match('^([^|]+)')
	if not fullpath then -- No EventFile
		return ''
	elseif fullpath:match('%.') then -- With file extension
		return fullpath:match('(.-)[^\\/]-%.[^%.]*$')
	else -- No file extension
		return fullpath:match('(.+)[/\\]$') .. '\\'
	end
end -- Update

function SetColor(name, color)
	if name == 'MoonColor' then
		SKIN:Bang('!SetOption', 'MoonColorFill', 'LineColor', '#*MoonColor*#')
	end
	SKIN:Bang('!SetVariable', name, color)
	SKIN:Bang('!Update')
end -- SetColor

-- ========== START SCROLLBOX ==========

function DrawItems()
	local cpos = TablePosition(Scroll.Folders, SKIN:GetVariable('Style'), function(input) return input.folder end)

	for i = 1, 4 do
		local tpos = i - 1 + Scroll.Position
		if tpos >= cpos then tpos = tpos + 1 end -- Skip the current style

		for k, v in pairs{
			Text = Scroll.Folders[tpos].name,
			ToolTipTitle = Scroll.Folders[tpos].author,
			ToolTipText = Scroll.Folders[tpos].info,
		} do SKIN:Bang('!SetOption', 'ScrollLine' .. i, k, v) end
	end

	SKIN:Bang('!SetOption', 'StyleCurrent', 'Text', Scroll.Folders[cpos].name)
	SKIN:Bang('!SetOption', 'TopBar', 'H', Scroll.ItemHeight * (Scroll.Position - 1))
	SKIN:Bang('!SetOption', 'BotBar', 'H', Scroll.ItemHeight * (#Scroll.Folders - Scroll.Position - 4))
	SKIN:Bang('!Update')
end -- DrawItems

function UnpackList(input)
	for _, word in ipairs(delim(input)) do
		local temp = {folder = word, name = word, author = '', info = '',}
		local ini = ReadIni(SKIN:ReplaceVariables(('#@#Styles\\%s\\meta.txt'):format(word)))
		if ini.metadata then
			temp = {
				folder = word,
				name = ini.metadata.name or word,
				author = ini.metadata.author and ('Created by ' .. ini.metadata.author) or '',
				info = ini.metadata.info or '',
			}
		end
		table.insert(Scroll.Folders, temp)
	end

	Scroll.ItemHeight = 60 / (#Scroll.Folders - 1)
	SKIN:Bang('!SetOption', 'MidBar', 'H', 4 * Scroll.ItemHeight)
	DrawItems()
end -- UnpackList

function ScrollUp()
	Scroll.Position = Scroll.Position == 1 and 1 or (Scroll.Position - 1)
	DrawItems()
end -- ScrollUp

function ScrollDown()
	if #Scroll.Folders > 4 then
		local max = #Scroll.Folders - 4
		Scroll.Position = Scroll.Position == max and max or (Scroll.Position + 1)
	end
	DrawItems()
end -- ScrollDown

function SetStyle(input)
	SKIN:Bang('!HideMeterGroup', 'Scroll')

	local npos = TablePosition(Scroll.Folders, SKIN:GetMeter(input):GetOption('Text'), function(temp) return temp.name end)
	if npos then
		MessageOutput()
		SKIN:Bang('!SetVariable', 'Style', Scroll.Folders[npos].folder)
		DrawItems()
	end
end -- SetStyle

-- ========== END SCROLLBOX ==========

function Save()
	MessageOutput()
	file = SKIN:ReplaceVariables('#@#Settings.inc')
	for k, _ in pairs(Variables) do
		SKIN:Bang('!WriteKeyValue', 'Variables', k, Encode(SKIN:GetVariable(k):gsub('#([^#]+)#', '#*%1*#')), file)
	end
	SKIN:Bang('!Refresh', 'LuaCalendar')
end -- Save

function Defaults()
	for k, v in pairs(Variables) do SKIN:Bang('!SetVariable', k, v) end
	MessageOutput('Click Save to confirm Defaults')
	DrawItems()
end -- Defaults

function CheckUpdate()
	local ini = ReadIni(SKIN:ReplaceVariables('#ROOTCONFIGPATH#LuaCalendar.ini'))
	local CurrentVersion = tonumber(SKIN:GetMeasure('UpdateVersion'):GetStringValue():match('<version>(.+)</version>'))

	if ini.metadata and CurrentVersion then
		local LocalVersion = tonumber(ini.metadata.version)
		if LocalVersion < CurrentVersion then
			SKIN:Bang('!SetOption', 'UpdateMeter', 'Text', 'An Update is Available: v' .. CurrentVersion)
		elseif CurrentVersion < LocalVersion then
			SKIN:Bang('!SetOption', 'UpdateMeter', 'Text', 'Thanks for testing the Beta!')
		end
	end
end -- CheckUpdate

function CheckDayLabels(input)
	if lengthcheck(input, 7, 'DayLabels must have seven days.') then
		SKIN:Bang('!SetVariable', 'DayLabels', input)
	end
end -- CheckDayLabels

function CheckMonthLabels(input)
	if lengthcheck(input, 12, 'MonthLabels must have twelve months.') then
		SKIN:Bang('!SetVariable', 'MonthLabels', input)
	end
end -- CheckMonthLabels

function CheckMLFormat(input)
	if varcheck(input, {'mname', 'year', 'today', 'month'}, 'Invalid LabelText variable {$%s}') then
		SKIN:Bang('!SetVariable', 'LabelText', input)
	end
end -- CheckMLFormat

function CheckELFormat(input)
	if varcheck(input, {'day', 'desc'}, 'Invalid NextFormat variable {$%s}') then
		SKIN:Bang('!SetVariable', 'NextFormat', input)
	end
end -- CheckELFormat

function SetEvents(path)
	SKIN:Bang('!SetVariable', 'EventFile', Encode(path))
	SKIN:Bang('!Update')
end -- SetEvents

-- ========== HELPER FUNCTIONS ==========

function Encode(line)
	for _, var in ipairs{'@', 'ROOTCONFIGPATH', 'SKINSPATH'} do
		local value = SKIN:GetVariable(var)
		line = line:gsub(value, ('#*%s*#'):format(var))
	end

	return line
end -- Encode

function lengthcheck(line, num, msg)
	MessageOutput()
	SKIN:Bang('!HideMeterGroup', 'Scroll')

	local temp = delim(line)
	if #temp == num or input == '' then
		MessageOutput()
		return true
	else
		MessageOutput(msg)
	end
end -- lengthcheck

function varcheck(input, list, msg)
	MessageOutput()
	SKIN:Bang('!HideMeterGroup', 'Scroll')
	
	for word in input:gmatch('{%$([^}]+)}') do
		if not TablePosition(list, word:lower(), function(temp) return temp:lower() end) then
			MessageOutput(msg:format(word))
			break
		end
	end
	return true
end -- varcheck

function MessageOutput(input)
	SKIN:Bang('!SetOption', 'Message', 'Text', input or ' ')
end -- MessageOutput

function TablePosition(tbl, key, func)
	for i, v in ipairs(tbl) do
		if (func and func(v) or v) == key then
			return i
		end
	end
	return nil
end -- TablePosition

function delim(input)
	local temp = {}
	for word in input:gmatch('[^|]+') do table.insert(temp, word) end
	return temp
end -- delim

function ReadIni(inputfile)
	local file = io.open(inputfile, 'r')
	local tbl, section = {}
	if file then
		local num = 0
		for line in file:lines() do
			num, line = (num + 1), line:gsub('\t', ' ')
			if not line:match('^%s-;') then
				local key, command = line:match('^([^=]+)=(.+)')
				if line:match('^%s-%[.+%]') then
					section = line:lower():match('^%s-%[([^%]]+)')
					if not tbl[section] then tbl[section] = {} end
				elseif key and command and section then
					tbl[section][key:lower():match('^%s*(%S*)%s*$')] = command:match('^%s*(.-)%s*$')
				elseif #line > 0 and section and not key or command then
					print(num .. ': Invalid property or value.')
				end
			end
		end
		if not section then print('No sections found in ' .. inputfile) end
		file:close()
	end
	return tbl
end -- ReadIni