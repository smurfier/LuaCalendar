Scroll = {
	Position = 1,
	ItemHeight = 0,
	Folders = {},
}

-- Double encode all variables used in values
-- #**Variable**#
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

function SetColor(Variable, Color)
	if Variable == 'MoonColor' then
		SKIN:Bang('!SetOption', 'MoonColorFill', 'LineColor', '#*MoonColor*#')
	end
	SKIN:Bang('!SetVariable', Variable, Color)
	SKIN:Bang('!Update')
end -- SetColor

-- ========== START SCROLLBOX ==========

function DrawItems()
	local CurrentPosition = TablePosition(Scroll.Folders, SKIN:GetVariable('Style'), function(input) return input.folder end)

	for i = 1, 4 do
		local tpos = i - 1 + Scroll.Position
		if tpos >= CurrentPosition then -- Skip the current style
			tpos = tpos + 1
		end
		
		local MeterProperties = {
			Text = Scroll.Folders[tpos].name,
			ToolTipTitle = Scroll.Folders[tpos].author,
			ToolTipText = Scroll.Folders[tpos].info,
		}
		
		local MeterName = 'ScrollLine' .. i
		for Option, Value in pairs(MeterProperties) do
			SKIN:Bang('!SetOption', MeterName, Option, Value)
		end
	end

	SKIN:Bang('!SetOption', 'StyleCurrent', 'Text', Scroll.Folders[CurrentPosition].name)
	SKIN:Bang('!SetOption', 'TopBar', 'H', Scroll.ItemHeight * (Scroll.Position - 1))
	SKIN:Bang('!SetOption', 'BotBar', 'H', Scroll.ItemHeight * (#Scroll.Folders - Scroll.Position - 4))
	SKIN:Bang('!Update')
end -- DrawItems

function UnpackList(input)
	local StyleList, Resources = delim(input), SKIN:GetVariable('@')
	
	for _, StyleName in ipairs(StyleList) do
		local ini = ReadIni(SKIN:ReplaceVariables(string.format('%sStyles\\%s\\meta.txt', Resources, StyleName)))
		local temp
		if ini.metadata then
			temp = {
				folder = StyleName,
				name = ini.metadata.name or StyleName,
				author = ini.metadata.author and ('Created by ' .. ini.metadata.author) or '',
				info = ini.metadata.info or '',
			}
		else
			temp = {
				folder = StyleName,
				name = StyleName,
				author = '',
				info = '',
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
	local SettingsFile = SKIN:ReplaceVariables('#@#Settings.inc')
	for Name, _ in pairs(Variables) do
		local Double = SKIN:GetVariable(Name):gsub('#([^#]+)#', '#*%1*#') -- Encode existing variables to prevent them from being evaluated
		SKIN:Bang('!WriteKeyValue', 'Variables', Name, Encode(Double), SettingsFile)
	end
	SKIN:Bang('!Refresh', 'LuaCalendar')
end -- Save

function Defaults()
	for Variable, Value in pairs(Variables) do
		SKIN:Bang('!SetVariable', Variable, Value)
	end
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
	local Names = {'@', 'ROOTCONFIGPATH', 'SKINSPATH'}
	for _, Variable in ipairs(Names) do
		local value = SKIN:GetVariable(Variable)
		line = line:gsub(value, string.format('#*%s*#', Variable))
	end

	return line
end -- Encode

function lengthcheck(line, num, ErrorMessage)
	MessageOutput()
	SKIN:Bang('!HideMeterGroup', 'Scroll')

	local temp = delim(line)
	if #temp == num or line == '' then
		MessageOutput()
		return true
	else
		MessageOutput(ErrorMessage)
	end
end -- lengthcheck

function varcheck(input, list, ErrorMessage)
	MessageOutput()
	SKIN:Bang('!HideMeterGroup', 'Scroll')
	
	for word in input:gmatch('{%$([^}]+)}') do
		if not TablePosition(list, word:lower(), function(temp) return temp:lower() end) then
			MessageOutput(ErrorMessage:format(word))
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
	for word in input:gmatch('[^|]+') do
		table.insert(temp, word)
	end
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
					if not tbl[section] then
						tbl[section] = {}
					end
				elseif key and command and section then
					tbl[section][key:lower():match('^%s*(%S*)%s*$')] = command:match('^%s*(.-)%s*$')
				elseif #line > 0 and section and not key or command then
					print(num .. ': Invalid property or value.')
				end
			end
		end
		if not section then
			print('No sections found in ' .. inputfile)
		end
		file:close()
	end
	return tbl
end -- ReadIni