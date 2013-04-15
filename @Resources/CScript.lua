-- LuaCalendar v4.2 by Smurfier (john@smurfier.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Settings.Color = 'FontColor'
	Settings.HideLastWeek = GetNumberOption('HideLastWeek') > 0
	Settings.LeadingZeroes = GetNumberOption('LeadingZeroes') > 0
	Settings.StartOnMonday = GetNumberOption('StartOnMonday') > 0
	Settings.LabelFormat = GetOption('LabelText', '{$MName}, {$Year}')
	Settings.NextFormat = GetOption('NextFormat', '{$day}: {$desc}')
	Settings.Locale = GetNumberOption('UseLocalMonths') > 0
	Settings.MonthNames = Delim(GetOption('MonthLabels'))
	-- Weekday labels text
	SetLabels(Delim(GetOption('DayLabels', 'S|M|T|W|T|F|S')))
	--Events File
	LoadEvents(ExpandFolder(Delim(GetOption('EventFile'))))
end -- Initialize

function Update()
	CombineScroll(0)

	-- If in the current month or if browsing and Month changes to that month, set to Real Time
	if (Time.stats.inmonth and Time.show.month ~= Time.curr.month) or ((not Time.stats.inmonth) and Time.show.month == Time.curr.month and Time.show.year == Time.curr.year) then
		Move()
	end
	
	if Time.show.month ~= Time.old.month or Time.show.year ~= Time.old.year then -- Recalculate and Redraw if Month and/or Year changes
		Time.old = {month = Time.show.month, year = Time.show.year, day = Time.curr.day}
		Events()
		Draw()
	elseif Time.curr.day ~= Time.old.day then -- Redraw if Today changes
		Time.old.day = Time.curr.day
		Draw()
	end
	
	return ReturnError()
end -- Update

function CombineScroll(input)
	if input and not Scroll then
		Scroll = input
	elseif Scroll ~= 0 and input == 0 then
		Move(Scroll / math.abs(Scroll))
		Scroll = 0
	else
		Scroll = Scroll + input
	end
end

Settings = setmetatable({}, {
	__index = {
		Name = 'LuaCalendar', -- String
		Color = '', -- String
		Range = 'month', -- String
		HideLastWeek = false, -- Boolean
		LeadingZeroes = false, -- Boolean
		StartOnMonday = false, -- Boolean
		LabelFormat = '{$MName}, {$Year}', -- String
		NextFormat = '{$day}: {$desc}', -- String
		Locale = false, -- Boolean
		MonthNames = {}, -- Table
	},
	__newindex = function(_, key, value)
		local tbl = getmetatable(Settings).__index
		if tbl[key] ~= nil then
			if type(value) == type(tbl[key]) then
				rawset(Settings, key, value)
			else
				ErrMsg(nil, 'Invalid Setting type. %s expected, received %s instead.', type(tbl[key]), type(value))
			end
		else
			ErrMsg(nil, 'Setting does not exist: %s', key)
		end
	end}
) -- Settings

Meters = setmetatable({}, {
	__index = {
		Labels = { -- Week Day Labels
			Name = 'l%d',
			Styles = {
				Normal = 'LblTxtSty',
				First = 'LblTxtStart',
				Current = 'LblCurrSty',
			},
		},
		Days = { -- Month Days
			Name = 'mDay%d',
			Styles = {
				Normal = 'TextStyle',
				FirstDay = 'FirstDay',
				NewWeek = 'NewWk',
				Current = 'CurrentDay',
				LastWk = 'LastWeek',
				PrevMnth = 'PreviousMonth',
				NxtMnth = 'NextMonth',
				Wknd = 'WeekendStyle',
				Holiday = 'HolidayStyle',
			},
		},
	},
}) -- Meters

Time = { -- Used to store and call date functions and statistics
	curr = setmetatable({}, {__index = function(_, index) return os.date('*t')[index] end,}),
	old = {day = 0, month = 0, year = 0,},
	show = {month = 0, year = 0,},
	stats = setmetatable({inmonth = true,}, {__index = function(_, index)
		local tstart = os.time{day = 1, month = Time.show.month, year = Time.show.year, isdst = false,}
		local nstart = os.time{day = 1, month = (Time.show.month % 12 + 1), year = (Time.show.year + (Time.show.month == 12 and 1 or 0)), isdst = false,}
		
		return ({
			clength = ((nstart - tstart) / 86400),
			plength = (tonumber(os.date('%d', tstart - 86400))),
			startday = rotate(tonumber(os.date('%w', tstart))),
		})[index]
	end,}),
} -- Time

Range = setmetatable({ -- Makes allowance for either Month or Week ranges
	month = {
		formula = function(input) return input - Time.stats.startday end,
		days = 42,
		week = function() return math.ceil((Time.curr.day + Time.stats.startday) / 7) end,
	},
	week = {
		formula = function(input) return Time.curr.day +((input - 1) - rotate(Time.curr.wday - 1)) end,
		days = 7,
		week = function() return 1 end,
		nomove = true,
	},
	}, { __index = function(tbl, index) return ErrMsg(tbl.month, 'Invalid Range: %s', index) end,
}) -- Range

function MLabels(input) -- Makes allowance for Month Names
	if Settings.Locale then
		os.setlocale('', 'time')
		return os.date('%B', os.time{year = 2000, month = input, day = 1})
	elseif Settings.MonthNames then
		return Settings.MonthNames[input] or ErrMsg(input, 'Not enough indices in MonthNames')
	else
		return input
	end
end -- MLabels

function Delim(input, sep) -- Separates an input string by a delimiter
	test(type(input) == 'string', 'Delim: input must be a string. Received %s instead', type(input))
	if sep then test(type(sep) == 'string', 'Delim: sep must be a string. Received %s instead', type(sep)) end
	local tbl = {}
	for word in input:gmatch('[^' .. (sep or '|') .. ']+') do table.insert(tbl, word:match('^%s*(.-)%s*$')) end
	return tbl
end -- Delim

function ExpandFolder(input) -- Makes allowance for when the first value in a table represents the folder containing all objects.
	test(type(input) == 'table', 'ExpandFolder: input must be a table. Received %s instead.', type(input))
	if #input > 1 then
		local folder = table.remove(input, 1)
		if not folder:match('[/\\]$') then folder = folder .. '\\' end
		for k, v in ipairs(input) do input[k] = SKIN:MakePathAbsolute(folder .. v) end
	end
	return input
end -- ExpandFolder

function SetLabels(tbl) -- Sets weekday labels
	local res = test(type(tbl) == 'table', 'SetLabels must receive a table')
	if res then res = test(#tbl >= 7, 'SetLabels must receive a table with seven indicies') end
	if not res then tbl = {'S', 'M', 'T', 'W', 'T', 'F', 'S'} end
	for a = 1, 7 do SKIN:Bang('!SetOption', Meters.Labels.Name:format(a), 'Text', tbl[Settings.StartOnMonday and (a % 7 + 1) or a]) end
end -- SetLabels

function LoadEvents(FileTable)
	test(type(FileTable) == 'table', 'LoadEvents: input must be a table. Received %s instead.', type(FileTable))

	hFile = {}

	local Keys = function(line)
		local tbl = {}
	
		local escape = {quot='"', lt='<', gt='>', amp='&',} -- XML escape characters

		for key, value in line:gmatch('(%a+)="([^"]+)"') do
			tbl[key:sub(1, 6):lower()] = value:gsub('&([^;]+);', escape):gsub('\r?\n', ' '):match('^%s*(.-)%s*$')
		end
	
		return tbl
	end

	for _, FileName in ipairs(FileTable) do
		local File, fName = test(io.open(FileName, 'r'), 'File Read Error: %s', fName), FileName:match('[^/\\]+$')
		
		local open, content, close = File:read('*all'):gsub('<!%-%-.-%-%->', ''):match('^.-<([^>]+)>(.+)<([^>]+)>[^>]*$')
		File:close()

		test(open:match('%S+'):lower() == 'eventfile' and close:lower() == '/eventfile', 'Invalid Event File: %s', fName)
		local eFile, eSet = Keys(open), {}
			
		for tag, line in content:gmatch('<([^%s>]+)([^>]*)>') do
			local ntag = tag:lower()

			if ntag == 'variable' then
				local Tmp = Keys(line)
				
				if not Variables then
					Variables = {[fName] = {},}
				elseif not Variables[fName] then
					Variables[fName] = {}
				end
				
				Variables[fName][Tmp.name:lower()] = Tmp.select
			elseif ntag == 'set' then
				table.insert(eSet, Keys(line))
			elseif ntag == '/set' then
				table.remove(eSet)
			elseif ntag == 'event' then
				local Tmp, dSet, tbl = Keys(line), {}, {}
				for _, column in ipairs(eSet) do
					for key, value in pairs(column) do dSet[key] = value end
				end
				for _, v in pairs{'month', 'day', 'year', 'descri', 'title', 'color', 'repeat', 'multip', 'annive', 'inacti', 'case', 'skip'} do
					tbl[v] = Tmp[v] or dSet[v] or eFile[v] or ''
				end
				tbl.fname = fName
				table.insert(hFile, tbl)
			else
				ErrMsg(nil, 'Invalid Event Tag <%s> in %s', tag, fName)
			end
		end
	end
end -- LoadEvents

function Events() -- Parse Events table.
	Hol = setmetatable({}, { __call = function(self) -- Returns a list of events
		local Evns = {}
	
		for day = Time.stats.inmonth and Time.curr.day or 1, Time.stats.clength do -- Parse through month days to keep days in order
			if self[day] then
				local tbl = setmetatable({day = day, desc = table.concat(self[day]['text'], ', ')},
					{ __index = function(_, input) return ErrMsg('', 'Invalid NextFormat variable {%s}', input) end,})
				table.insert(Evns, (Settings.NextFormat:gsub('{%$([^}]+)}', function(variable) return tbl[variable:lower()] end)) )
			end
		end
	
		return table.concat(Evns, '\n')
	end})

	local AddEvn = function(day, desc, color, ann, cs, skip)
		desc = desc:format(ann and (' (%s)'):format(ann) or '')
		
		if cs == 'lower' then
			desc = desc:lower()
		elseif cs == 'upper' then
			desc = desc:upper()
		elseif cs == 'title' then
			desc = desc:gsub('(%S)(%S*)', function(first, rest) return first:upper() .. rest:lower() end)
		elseif cs == 'sentence' then
			desc = desc:gsub('[^.!?]+', function(sentence)
				local space, first, rest = sentence:match('(%s*)(.)(.*)')	
				return space .. first:upper() .. rest:lower():gsub("%si([%s'])", ' I%1')
			end)
		end

		if skip:find(('%02d%02d%04d'):format(day, Time.show.month, Time.show.year)) then
			-- Do Nothing	
		elseif Hol[day] then
			table.insert(Hol[day].text, desc)
			table.insert(Hol[day].color, color)
		else
			Hol[day] = {text = {desc}, color = {color},}
		end
	end

	local tstamp = function(d, m, y) return os.time{day = d, month = m, year= y, isdst = false} end

	for _, event in ipairs(hFile or {}) do
		local eMonth = Parse.Number(event.month, false, event.fname)
		local eRepeat = Parse.List(event['repeat'], 'none', event.fname, 'none|week|year|month')
		if  (eMonth or 0) == Time.show.month or eRepeat ~= 'none' then
			local day = Parse.Number(event.day, false, event.fname) or ErrMsg(0, 'Invalid Event Day %s in %s', event.day, event.descri)
			local title = Parse.String(event.title, '', event.fname, true)
			local desc = Parse.String(event.descri .. '%s' .. (title ~= '' and ' -' .. title or ''), '', event.fname, true)
			local color = Parse.Color(event.color, event.fname)
			local case = Parse.List(event.case, 'none', event.fname, 'none|lower|upper|title|sentence')
			local year = Parse.Number(event.year, false, event.fname)
			local skip = Parse.String(event.skip, '', event.fname)
			local multip = Parse.Number(event.multip, 0, event.fname, 0)
			local annive = Parse.Boolean(event.annive, event.fname)

			if Parse.Boolean(event.inacti, event.fname) then
				-- Do Nothing
			elseif eRepeat == 'week' and eMonth and year and day then
				local stamp = tstamp(day, eMonth, year)
				local test = tstamp(day, Time.show.month, Time.show.year) >= stamp
				local mstart = tstamp(1, Time.show.month, Time.show.year)
				local multi = multip * 604800
				local first = mstart + ((stamp - mstart) % multi)

				for a = 0, 4 do
					local tstamp = first + a * multi
					local temp = os.date('*t', tstamp)
					if temp.month == Time.show.month and test then
						AddEvn(temp.day, desc, color, annive and ((tstamp - stamp) / multi + 1) or false, case, skip)
					end
				end
			elseif eRepeat == 'year' then
				if eMonth == Time.show.month and ((year and multip > 1) and ((Time.show.year - year) % multip) or 0) == 0 then
					AddEvn(day, desc, color, annive and (Time.show.year - year / multip) or false, case, skip)
				end
			elseif eRepeat == 'month' then
				if eMonth and year then
					if Time.show.year >= year then
						local ydiff = Time.show.year - year - 1
						local mdiff = ydiff == -1 and (Time.show.month - eMonth) or ((12 - eMonth) + Time.show.month + (ydiff * 12))
						local estamp, mstart = tstamp(1, eMonth, year), tstamp(1, Time.show.month, Time.show.year)

						if (mdiff % multip) == 0 and mstart >= estamp then
							AddEvn(day, desc, color, annive and (mdiff / multip + 1) or false, case, skip)
						end
					end
				else
					AddEvn(day, desc, color, false, case, skip)
				end
			elseif year == Time.show.year then
				AddEvn(day, desc, color, false, case, skip)
			end
		end
	end
end -- Events

function Draw() -- Sets all meter properties and calculates days
	local LastWeek = Settings.HideLastWeek and math.ceil((Time.stats.startday + Time.stats.clength) / 7) < 6
	
	for wday = 1, 7 do -- Set Weekday Labels styles
		local Styles = {Meters.Labels.Styles.Normal}
		if wday == 1 then
			table.insert(Styles, Meters.Labels.Styles.First)
		end
		if rotate(Time.curr.wday - 1) == (wday - 1) and Time.stats.inmonth then
			table.insert(Styles, Meters.Labels.Styles.Current)
		end
		SKIN:Bang('!SetOption', Meters.Labels.Name:format(wday), 'MeterStyle', table.concat(Styles, '|'))
	end

	for meter = 1, Range[Settings.Range].days do -- Calculate and set day meters
		local Styles, day, event, color = {Meters.Days.Styles.Normal}, Range[Settings.Range].formula(meter)

		if meter == 1 then
			table.insert(Styles, Meters.Days.Styles.FirstDay)
		elseif (meter % 7) == 1 then
			table.insert(Styles, Meters.Days.Styles.NewWeek)
		end
		-- Holiday ToolTip and Style
		if Hol then
			if day > 0 and day <= Time.stats.clength and Hol[day] then
				event = table.concat(Hol[day].text, '\n')
				table.insert(Styles, Meters.Days.Styles.Holiday)

				for _, value in ipairs(Hol[day].color) do
					if value then
						if not color then
							color = value
						elseif color ~= value then
							color = ''
							break
						end
					end
				end
			end
		end
		
		if (Time.curr.day + Time.stats.startday) == meter and Time.stats.inmonth then
			table.insert(Styles, Meters.Days.Styles.Current)
		elseif meter > 35 and LastWeek then
			table.insert(Styles, Meters.Days.Styles.LastWk)
		elseif day < 1 then
			day = day + Time.stats.plength
			table.insert(Styles, Meters.Days.Styles.PrevMnth)
		elseif day > Time.stats.clength then
			day = day - Time.stats.clength
			table.insert(Styles, Meters.Days.Styles.NxtMnth)
		elseif (meter % 7) == 0 or (meter % 7) == (Settings.StartOnMonday and 6 or 1) then
			table.insert(Styles, Meters.Days.Styles.Wknd)
		end
		
		for k, v in pairs{ -- Define meter properties
			Text = LZero(day),
			MeterStyle = table.concat(Styles, '|'),
			ToolTipText = event or '',
			[Settings.Color] = color or '',
		} do SKIN:Bang('!SetOption', Meters.Days.Name:format(meter), k, v) end
	end
	
	local sVars = { -- Define skin variables
		ThisWeek = Range[Settings.Range].week(),
		Week = rotate(Time.curr.wday - 1),
		Today = LZero(Time.curr.day),
		Month = MLabels(Time.show.month),
		Year = Time.show.year,
		MonthLabel = Vars(Settings.LabelFormat),
		LastWkHidden = LastWeek and 1 or 0,
		NextEvent = Hol and Hol() or '',
	}
	-- Week Numbers for the current month
	local FirstWeek = os.time{day = (6 - Time.stats.startday), month = Time.show.month, year = Time.show.year}
	for i = 0, 5 do sVars['WeekNumber' .. (i + 1)] = math.ceil(tonumber(os.date('%j', (FirstWeek + (i * 604800)))) / 7) end
	-- Set Skin Variables
	for k, v in pairs(sVars) do SKIN:Bang('!SetVariable', k, v) end
end -- Draw

function Move(value) -- Move calendar through the months
	if value then test(type(value) == 'number', 'Move: input must be a number. Received %s instead.', type(value)) end
	if Range[Settings.Range].nomove or not value then
		Time.show = Time.curr
	elseif math.ceil(value) ~= value then
		ErrMsg(nil, 'Invalid Move Parameter %s', value)
	else
		local mvalue = Time.show.month + value - (math.modf(value / 12)) * 12
		local mchange = value < 0 and (mvalue < 1 and 12 or 0) or (mvalue > 12 and -12 or 0)
		Time.show = {month = (mvalue + mchange), year = (Time.show.year + (math.modf(value / 12)) - mchange / 12),}
	end

	Time.stats.inmonth = Time.show.month == Time.curr.month and Time.show.year == Time.curr.year
	SKIN:Bang('!SetVariable', 'NotCurrentMonth', Time.stats.inmonth and 0 or 1)
end -- Move

function Easter(year) -- Returns a timestamp representing easter of the current year
	local a, b, c, h, L, m = (year % 19), math.floor(year / 100), (year % 100), 0, 0, 0
	local d, e, f, i, k = math.floor(b/4), (b % 4), math.floor((b + 8) / 25), math.floor(c / 4), (c % 4)
	h = (19 * a + b - d - math.floor((b - f + 1) / 3) + 15) % 30
	L = (32 + 2 * e + 2 * i - h - k) % 7
	m = math.floor((a + 11 * h + 22 * L) / 451)
	
	return os.time{month = math.floor((h + L - 7 * m + 114) / 31), day = ((h + L - 7 * m + 114) % 31 + 1), year = year}
end -- Easter

function Vars(line, fname, esub) -- Makes allowance for {$Variables}
	local tbl = {mname = MLabels(Time.show.month), year = Time.show.year, today = LZero(Time.curr.day), month = Time.show.month}

	-- Built in Events
	local BuiltIn = {
		easter = function() return Easter(Time.show.year) end,
		goodfriday = function() return Easter(Time.show.year) - 2 * 86400 end,
		ashwednesday = function() return Easter(Time.show.year) - 46 * 86400 end,
		mardigras = function() return Easter(Time.show.year) - 47 * 86400 end,
	}

	return (line:gsub('{%$([^}]+)}', function(variable)
		local var = variable:gsub('%s', ''):lower()
		if BuiltIn[var:match('([^:]+):') or ''] then
			local name, vtype = var:match('^([^:]+):(.+)')
			return os.date('*t', BuiltIn[name]())[vtype] or ErrMsg(esub, 'Invalid Variable {$%s}', var)
		elseif ((Variables or {})[fname or ''] or {})[var] then
			return Variables[fname][var]
		elseif tbl[var] then
			return tbl[var]
		else
			local D, W = {sun = 0, mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6}, {first = 0, second = 1, third = 2, fourth = 3, last = 4}
			local v1, v2 = var:match('(.+)(...)')
			if not (W[v1 or ''] and D[v2 or '']) then -- Error
				return ErrMsg(esub, 'Invalid Variable {$%s}', var)
			elseif v1 == 'last' then -- Last Day
				local L = 36 + D[v2] - Time.stats.startday
				return L - math.ceil((L - Time.stats.clength) / 7) * 7
			else -- Variable Day
				return rotate(D[v2]) + 1 - Time.stats.startday + (Time.stats.startday > rotate(D[v2]) and 7 or 0) + 7 * W[v1]
			end
		end
	end))
end -- Vars

Parse = {
	Number = function(line, default, fname, round)
		local num = Vars(line, fname, 0):gsub('%s', '')
		if num == '' then
			return default
		else
			num = SKIN:ParseFormula('(' .. num .. ')')
			if num then
				return round and tonumber(('%.' .. round .. 'f'):format(num)) or num
			else
				return default
			end
		end
	end, -- Number

	Boolean = function(line, fname)
		return Vars(line, fname, ''):gsub('%s', ''):lower() == 'true'
	end, -- Boolean

	List = function(line, default, fname, list)
		line = Vars(line, fname, ''):gsub('[|%s]', ''):lower()
		return list:find(line) and line or default
	end, -- List

	String = function(line, default, fname, spaces)
		line = Vars(line, fname, '')
		if line == '' then line = default end
		return spaces and line or line:gsub('%s', '')
	end, -- String

	Color = function(line, fname)
		line = Vars(line, fname, ''):gsub('%s', '')
		local tbl = {}
		if line == '' then
			return false
		elseif line:match(',') then
			for rgb in line:gmatch('[^,]+') do
				if not tonumber(rgb) then
					return false
				else
					table.insert(tbl, ('%02X'):format(tonumber(rgb)))
				end
			end
		else
			for hex in line:gmatch('%S%S') do
				if not tonumber(hex, 16) then
					return false
				else
					table.insert(tbl, hex:upper())
				end
			end
		end
		for i = #tbl, 4 do table.insert(tbl, 'FF') end
		return table.concat(tbl)
	end, -- Color
}

function rotate(value) -- Makes allowance for StartOnMonday
	return Settings.StartOnMonday and ((value - 1 + 7) % 7) or value
end -- rotate

function LZero(value) -- Makes allowance for LeadingZeros
	return Settings.LeadingZeroes and ('%02d'):format(value) or value
end -- LZero

function ErrMsg(...) -- Used to display errors
	local value = table.remove(arg, 1)
	local msg = string.format(unpack(arg))
	if not rMessage then
		rMessage = {msg}
	else
		table.insert(rMessage, msg)
	end
	return value
end -- ErrMsg

function ReturnError() -- Used to prevent duplicate error messages
	if rMessage then
		local temp = {}
		for k, v in ipairs(rMessage) do
			local count = 0
			for k2, v2 in ipairs(temp) do
				if v == v2 then count = count +1 end
			end
			if count == 0 then table.insert(temp, v) end
		end
		for k, v in ipairs(temp) do print(Settings.Name .. ': ' .. v) end
		Error, rMessage = rMessage[#rMessage], nil
		return Error
	else
		return Error or 'Success!'
	end
end -- ReturnError

function test(...) -- clone of assert
	local rvalue = table.remove(arg, 1)
	if not rvalue then
		ErrMsg(nil, unpack(arg))
	end
	return rvalue
end -- test

function GetOption(option, default) -- Allows for existing but empty string options.
	local input = SELF:GetOption(option)
	if input == '' then
		return default or ''
	else
		return input
	end
end -- GetOption

function GetNumberOption(option, default) -- Allows for existing but empty number options.
	return tonumber(SELF:GetOption(option)) or default or 0
end -- GetNumberOption

function GetVariable(option, default) -- Allows for existing but empty variables.
	local input = SKIN:GetVariable(option)
	if input == '' then
		return default or ''
	else
		return input
	end
end -- GetVariable