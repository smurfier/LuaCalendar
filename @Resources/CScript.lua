-- LuaCalendar v5.0 by Smurfier (smurfier@outlook.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Settings.Color = 'FontColor'
	Settings.HideLastWeek = Get.NumberVariable('HideLastWeek') > 0
	Settings.LeadingZeroes = Get.NumberVariable('LeadingZeroes') > 0
	Settings.StartOnMonday = Get.NumberVariable('StartOnMonday') > 0
	Settings.LabelFormat = Get.Variable('LabelText', '{$MName}, {$Year}')
	Settings.NextFormat = Get.Variable('NextFormat', '{$day}: {$desc}')
	Settings.MonthNames = Delim(Get.Variable('MonthLabels', ''))
	Settings.MoonPhases = Get.NumberVariable('ShowMoonPhases') > 0
	Settings.MoonColor = Parse.Color(Get.Variable('MoonColor', ''))
	Settings.ShowEvents = Get.NumberVariable('ShowEvents') > 0
	Settings.DisableScroll = Get.NumberVariable('DisableScroll') > 0
	-- Weekday labels text
	SetLabels(Delim(Get.Variable('DayLabels', 'S|M|T|W|T|F|S')))
	-- Events File
	LoadEvents(ExpandFolder(Delim(Get.Variable('EventFile'))))
end -- Initialize

function Update()
	CombineScroll(0)

	-- If in the current month or if browsing and Month changes to that month, set to Real Time
	if (Time.stats.inmonth and Time.show.month ~= Time.curr.month) or ((not Time.stats.inmonth) and Time.show.month == Time.curr.month and Time.show.year == Time.curr.year) then
		Move()
	end
	
	if Time.show.month ~= Time.old.month or Time.show.year ~= Time.old.year then -- Recalculate and Redraw if Month and/or Year changes
		Time.old = {month = Time.show.month, year = Time.show.year, day = Time.curr.day}
		Time.stats() -- Set all Time.stats values for the current month.
		Events()
		Draw()
	elseif Time.curr.day ~= Time.old.day and Time.stats.inmonth then -- Redraw if Today changes
		Time.old.day = Time.curr.day
		Draw()
	end
	
	return ReturnError()
end -- Update

function CombineScroll(input)
	if Settings.DisableScroll then
		-- Do Nothing
	elseif input and not Scroll then
		Scroll = input
	elseif Scroll ~= 0 and input == 0 then
		Move(Scroll / math.abs(Scroll))
		Scroll = 0
	else
		Scroll = Scroll + input
	end
end -- CombineScroll

Settings = setmetatable(
	{}, -- Start with an empty settings table. Force the use of __newindex in the metatable.
	{
		-- Use __index metatable to set up default settings.
		__index = {
			Color = '', -- String
			Range = 'month', -- String
			HideLastWeek = false, -- Boolean
			LeadingZeroes = false, -- Boolean
			StartOnMonday = false, -- Boolean
			LabelFormat = '{$MName}, {$Year}', -- String
			NextFormat = '{$day}: {$desc}', -- String
			MonthNames = {}, -- Table
			MoonPhases = false, -- Boolean
			MoonColor = '', -- String
			ShowEvents = true, -- Boolean
			DisableScroll = false; -- Boolean
		},
		-- Use __newindex to validate setting values.
		__newindex = function(t, key, value)
			local tbl = getmetatable(Settings).__index
			if test(tbl[key] ~= nil, 'Setting does not exist: %s', key) then
				if type(value) == type(tbl[key]) then
					rawset(t, key, value)
				else
					ErrMsg(nil, '%s: Invalid Setting type. %s expected, received %s instead.', key, type(tbl[key]), type(value))
				end
			end
		end,
	}
) -- Settings

-- Set meter names/formats here.
Meters = {
	Labels = { -- Week Day Labels
		Name = 'l%d', -- Use %d to denote the number (1-7) of the meter.
		Styles = {
			Normal = 'LblTxtSty',
			First = 'LblTxtStart',
			Current = 'LblCurrSty',
		},
	},
	Days = { -- Month Days
		Name = 'mDay%d', -- Use %d to denote the number (1-42) of the meter.
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
} -- Meters

Time = { -- Used to store and call date functions and statistics
	curr = setmetatable({}, {__index = function(_, index) return os.date('*t')[index] end,}),
	old = {day = 0, month = 0, year = 0,},
	show = os.date('*t'), -- Needs to be initialized with current values.
	stats = setmetatable({inmonth = true,},
		{__call = function(t, index)
			local tstart = os.time{day = 1, month = Time.show.month, year = Time.show.year, isdst = false,}
			local nstart = os.time{day = 1, month = (Time.show.month % 12 + 1), year = (Time.show.year + (Time.show.month == 12 and 1 or 0)), isdst = false,}
			
			local values = {
				nmonth = nstart, -- Timestamp for the first day of the following month.
				cmonth = tstart, -- Timestamp for the first day of the current month.
				clength = (nstart - tstart) / 86400, -- Number of days in the current month.
				plength = tonumber(os.date('%d', tstart - 86400)), -- Number of days in the previous month.
				startday = rotate(tonumber(os.date('%w', tstart))), -- Day code for the first day of the current month.
			}
			
			for k, v in pairs(values) do rawset(t, k, v) end
		end,}
	),
} -- Time

Range = setmetatable({ -- Makes allowance for either Month or Week ranges
	month = {
		formula = function(input) return input - Time.stats.startday end,
		adjustment = function(input) return input end,
		days = 42,
		week = function() return math.ceil((Time.curr.day + Time.stats.startday) / 7) end,
	},
	week = {
		formula = function(input) return Time.curr.day + ((input - 1) - rotate(Time.curr.wday - 1)) end,
		adjustment = function(input) local num = input % 7 return num == 0 and 7 or num end,
		days = 7,
		week = function() return 1 end,
		nomove = true,
	},
}, { __index = function(tbl, index) return ErrMsg(tbl.month, 'Invalid Range: %s', index) end, }) -- Range

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
	local res = test(type(tbl) == 'table', 'SetLabels must receive a table. Received %s instead.', type(tbl))
	if res and not test(#tbl >= 7, 'SetLabels must receive a table with seven indicies.') then tbl = {'S', 'M', 'T', 'W', 'T', 'F', 'S'} end
	if Settings.StartOnMonday then table.insert(tbl, table.remove(tbl, 1)) end
	for k, v in ipairs(tbl) do SKIN:Bang('!SetOption', Meters.Labels.Name:format(k), 'Text', v) end
end -- SetLabels

function LoadEvents(FileTable)
	test(type(FileTable) == 'table', 'LoadEvents: input must be a table. Received %s instead.', type(FileTable))
	
	if not Settings.ShowEvents then FileTable = {} end

	hFile = {}
	
	-- Define valid key names
	local KeyNames = {
		'month',
		'day',
		'year',
		'description',
		'title',
		'color',
		'repeat',
		'multiplier',
		'anniversary',
		'inactive',
		'case',
		'skip',
		'timestamp',
		'finish',
	}

	local Keys = function(line, default)
		local tbl, escape = default or {}, {quot = '"', amp = '&', lt = '<', gt = '>', apos = "'",}

		for key, value in line:gmatch('(%a+)="([^"]+)"') do
			tbl[key:lower()] = value:gsub('&([^;]+);', escape):gsub('\r?\n', ' '):match('^%s*(.-)%s*$')
		end
	
		return tbl
	end -- Keys

	for _, FileName in ipairs(FileTable) do
		local File, fName = test(io.open(FileName, 'r'), 'File Read Error: %s', fName), FileName:match('[^/\\]+$')
		
		local open, content, close = File:read('*all'):gsub('<!%-%-.-%-%->', ''):match('^.-<([^>]+)>(.+)<([^>]+)>[^>]*$')
		File:close()

		test(open:match('%S+'):lower() == 'eventfile' and close:lower() == '/eventfile', 'Invalid Event File: %s', fName)
		local eFile, eSet, queue = Keys(open), {}
		
		local AddEvn = function(options)
			local dSet, tbl = {}, {fname = fName,}
			-- Collapse set matrix into a single table
			for _, column in ipairs(eSet) do
				for key, value in pairs(column) do dSet[key] = value end
			end
			-- Work through all tables to add option to temporary table
			for _, v in pairs(KeyNames) do
				tbl[v] = options[v] or dSet[v] or eFile[v] or ''
			end
			-- Add temporary table to main Holidays table
			table.insert(hFile, tbl)
		end -- AddEvn
			
		for tag, line, contents in content:gmatch('<%s-([^%s>]+)([^>]*)>([^<]*)') do
			local ntag, contents = tag:lower(), contents:gsub('%s+', ' ')

			if queue then
				if test(ntag == '/event',  'Event tags may not have nested tags. File: %s', fName) then
					AddEvn(Keys(queue.line, {description = queue.contents,}))
				end
				queue = nil
			elseif ntag == 'variable' then
				local Tmp = Keys(line)
				
				if not Variables then
					Variables = {[fName] = {[Tmp.name:lower()] = Tmp.select,},}
				elseif not Variables[fName] then
					Variables[fName] = {[Tmp.name:lower()] = Tmp.select,}
				else
					Variables[fName][Tmp.name:lower()] = Tmp.select
				end
			elseif ntag == 'set' then
				table.insert(eSet, Keys(line))
			elseif ntag == '/set' then
				table.remove(eSet)
			elseif ntag == 'event' then
				-- inline closing event tag
				if line:match('/%s-$') then
					AddEvn(Keys(line))
				-- Tag is open, create queue
				elseif contents:gsub('[\t\n\r%s]', '') ~= '' then
					queue = {line = line, contents = contents:gsub('\r?\n', ' '),}
				-- Error
				else
					ErrMsg(nil, 'Open Event tag detected without contents. File: %s', fName)
				end	
			else
				ErrMsg(nil, 'Invalid Tag <%s> in %s', tag, fName)
			end
		end

		if queue or #eSet > 0 then ErrMsg(nil, 'Unmatched Event or Set tag detected in %s', fName) end
	end
end -- LoadEvents

function Events() -- Parse Events table.
	Hol = {}

	local tstamp = function(d, m, y) return os.time{day = d, month = m, year = y, isdst = false} end

	local DefineEvent = function(d, e, c)
		if not Hol[d] then
			Hol[d] = {text = {e}, color = {c},}
		else
			table.insert(Hol[d].text, e)
			table.insert(Hol[d].color, c)
		end
	end -- DefineEvent

	for _, event in ipairs(hFile or {}) do
		-- Parse necessary options
		local dtbl = {stamp = Parse.Number(event.timestamp, false, event.fname)}
		if dtbl.stamp then
			dtbl = os.date('*t', dtbl.stamp)
		else
			dtbl.month = Parse.Number(event.month, false, event.fname)
			dtbl.day = Parse.Number(event.day, false, event.fname) or ErrMsg(0, 'Invalid Event Day %s in %s', event.day, event.description)
			dtbl.year = Parse.Number(event.year, false, event.fname)
		end
		dtbl.multip = Parse.Number(event.multiplier, 1, event.fname, 0)
		dtbl.erepeat = Parse.List(event['repeat'], 'none', event.fname, 'none|week|year|month|custom')
		dtbl.finish = Parse.Number(event.finish, Time.stats.nmonth, event.fname)

		-- Find matching events
		if dtbl.finish >= Time.stats.cmonth and not Parse.Boolean(event.inactive, event.fname) then
			
			local AddEvn = function(day, ann)
				local desc = Parse.String(event.description, false, event.fname, true) or ErrMsg('', 'Event detected with no Description.')
				local useann =  Parse.Boolean(event.anniversary, event.fname) and ann
				local title = Parse.String(event.title, false, event.fname, true)

				if useann and title then
					desc = ('%s (%s) -%s'):format(desc, ann, title)
				elseif useann then
					desc = ('%s (%s)'):format(desc, ann)
				elseif title then
					desc = ('%s -%s'):format(desc, title)
				end
				
				local case = Parse.List(event.case, 'none', event.fname, 'none|lower|upper|title|sentence')
				if case == 'lower' then
					desc = desc:lower()
				elseif case == 'upper' then
					desc = desc:upper()
				elseif case == 'title' then
					desc = desc:gsub('(%S)(%S*)', function(first, rest) return first:upper() .. rest:lower() end)
				elseif case == 'sentence' then
					desc = desc:gsub('[^.!?]+', function(sentence)
						local space, first, rest = sentence:match('(%s*)(.)(.*)')	
						return space .. first:upper() .. rest:lower():gsub("%si([%s'])", ' I%1')
					end)
				end

				local color = Parse.Color(event.color, event.fname)

				if not Parse.String(event.skip, '', event.fname):find(('%02d%02d%04d'):format(day, Time.show.month, Time.show.year)) then
					DefineEvent(day, desc, color)
				end
			end -- AddEvn

			local frame = function(period)
				local start = tstamp(dtbl.day, dtbl.month, dtbl.year)
				
				if Time.stats.nmonth >= start then
					local first = Time.stats.cmonth > start and (Time.stats.cmonth + (period - ((Time.stats.cmonth - start) % period))) or start
					
					for i = first, (dtbl.finish < Time.stats.nmonth and dtbl.finish or Time.stats.nmonth), period do
						AddEvn(tonumber(os.date('%d', i)), (i - start) / period + 1)
					end
				end
			end -- frame

			if dtbl.erepeat == 'custom' and dtbl.year and dtbl.month and dtbl.day and dtbl.multip >= 86400 then
				frame(dtbl.multip)
			elseif dtbl.erepeat == 'week' and dtbl.month and dtbl.year and dtbl.day and dtbl.multip >= 1 then
				frame(dtbl.multip * 604800)
			elseif dtbl.erepeat == 'year' and tstamp(dtbl.day, dtbl.month, Time.show.year) <= dtbl.finish then
				if dtbl.month == Time.show.month and ((dtbl.year and dtbl.multip > 1) and ((Time.show.year - dtbl.year) % dtbl.multip) or 0) == 0 then
					AddEvn(dtbl.day, dtbl.year and Time.show.year - dtbl.year / dtbl.multip)
				end
			elseif dtbl.erepeat == 'month' and tstamp(dtbl.day, dtbl.month or Time.show.month, dtbl.year or Time.show.year) <= dtbl.finish then
				if not dtbl.month and dtbl.year then
					AddEvn(dtbl.day)
				elseif Time.show.year >= dtbl.year then
					local ydiff = Time.show.year - dtbl.year - 1
					local mdiff = ydiff == -1 and (Time.show.month - dtbl.month) or ((12 - dtbl.month) + Time.show.month + (ydiff * 12))

					if (mdiff % dtbl.multip) == 0 and Time.stats.cmonth >= tstamp(1, dtbl.month, dtbl.year) then
						AddEvn(dtbl.day, mdiff / dtbl.multip + 1)
					end
				end
			elseif dtbl.erepeat =='none' and dtbl.year == Time.show.year and dtbl.month == Time.show.month then
				AddEvn(dtbl.day)
			end
		end
	end

	-- Find the Moon Phases for the Month
	if type(GetPhaseNumber) == 'function' and Settings.MoonPhases and Settings.ShowEvents then
		local moon, names = {}, {[1] = 'New Moon', [5] = 'Full Moon',}
		for i = 1, Time.stats.clength do
			local phase = GetPhaseNumber(Time.show.year, Time.show.month, i)
			if names[phase] and not moon[i - 1] then
				moon[i] = names[phase]
			end
		end
		-- Apply the Moon Phases to the Hol table
		for k, v in pairs(moon) do
			DefineEvent(k, v, Settings.MoonColor)
		end
	end
end -- Events

function Draw() -- Sets all meter properties and calculates days
	local HideLastWeek = Settings.HideLastWeek and math.ceil((Time.stats.startday + Time.stats.clength) / 7) < 6
	
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
		if (Hol or {})[day] and day > 0 and day <= Time.stats.clength then
			event = table.concat(Hol[day].text, '\n')
			table.insert(Styles, Meters.Days.Styles.Holiday)

			for _, value in ipairs(Hol[day].color) do
				if value == '' then
					-- Do Nothing
				elseif not color then
					color = value
				elseif color ~= value then
					color = ''
					break
				end
			end
		end
		
		if Range[Settings.Range].adjustment(Time.curr.day + Time.stats.startday) == meter and Time.stats.inmonth then
			table.insert(Styles, Meters.Days.Styles.Current)
		elseif meter > 35 and HideLastWeek then
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
			[Settings.Color or 'FontColor'] = color or '',
		} do SKIN:Bang('!SetOption', Meters.Days.Name:format(meter), k, v) end
	end

	-- Week Numbers for the current month
	local FirstWeek = os.time{day = (6 - Time.stats.startday), month = Time.show.month, year = Time.show.year}
	local GetWeek = function(i) return math.ceil(os.date('%j', FirstWeek + i * 604800) / 7) end
	
	function EventList(self) -- Returns a list of events
		local Evns = {}
	
		for day = Time.stats.inmonth and Time.curr.day or 1, Time.stats.clength do -- Parse through month days to keep days in order
			if self[day] then
				local names = {day = day, desc = table.concat(self[day].text, ', '),}
				
				local line = Settings.NextFormat:gsub('{%$([^}]+)}', function(variable)
					return names[variable:lower()] or ErrMsg('', 'Invalid NextFormat variable {$%s}', variable)
				end)
				
				table.insert(Evns, line)
			end
		end
	
		return table.concat(Evns, '\n')
	end -- EventList
	
	for k, v in pairs{ -- Define skin variables
		ThisWeek = Range[Settings.Range].week(),
		Week = rotate(Time.curr.wday - 1),
		Today = LZero(Time.curr.day),
		Month = Settings.MonthNames[Time.show.month] or Time.show.month,
		Year = Time.show.year,
		MonthLabel = Vars(Settings.LabelFormat),
		LastWkHidden = LastWeek and 1 or 0,
		NextEvent = Hol and EventList(Hol) or '',
		WeekNumber1 = GetWeek(0),
		WeekNumber2 = GetWeek(1),
		WeekNumber3 = GetWeek(2),
		WeekNumber4 = GetWeek(3),
		WeekNumber5 = GetWeek(4),
		WeekNumber6 = GetWeek(5),
	} do SKIN:Bang('!SetVariable', k, v) end
end -- Draw

function Move(value) -- Move calendar through the months
	if value then test(type(value) == 'number', 'Move: input must be a number. Received %s instead.', type(value)) end
	if Range[Settings.Range].nomove or not value then
		Time.show = Time.curr
	elseif test(math.ceil(value) == value, 'Invalid Move Parameter %s', value) then
		local mvalue = Time.show.month + value - (math.modf(value / 12)) * 12
		local mchange = value < 0 and (mvalue < 1 and 12 or 0) or (mvalue > 12 and -12 or 0)
		Time.show = {month = (mvalue + mchange), year = (Time.show.year + (math.modf(value / 12)) - mchange / 12),}
	end

	Time.stats.inmonth = Time.show.month == Time.curr.month and Time.show.year == Time.curr.year
	SKIN:Bang('!SetVariable', 'NotCurrentMonth', Time.stats.inmonth and 0 or 1)
end -- Move

function Easter()
	local a, b, c, h, L, m = (Time.show.year % 19), math.floor(Time.show.year / 100), (Time.show.year % 100), 0, 0, 0
	local d, e, f, i, k = math.floor(b/4), (b % 4), math.floor((b + 8) / 25), math.floor(c / 4), (c % 4)
	h = (19 * a + b - d - math.floor((b - f + 1) / 3) + 15) % 30
	L = (32 + 2 * e + 2 * i - h - k) % 7
	m = math.floor((a + 11 * h + 22 * L) / 451)
	
	return os.time{month = math.floor((h + L - 7 * m + 114) / 31), day = ((h + L - 7 * m + 114) % 31 + 1), year = Time.show.year}
end -- Easter

BuiltIn = {
	easter = function() return Easter() end,
	goodfriday = function() return Easter() - 2 * 86400 end, -- Old style format. To be removed later
	ashwednesday = function() return Easter() - 46 * 86400 end, -- Old style format. To be removed later
	mardigras = function() return Easter() - 47 * 86400 end, -- Old style format. To be removed later
} -- BuiltIn

-- It is the developers responsibility to validate all variables.
-- Have the function return nil in the event of an error.
-- Each variable is passed to the function as a string.
Functions = {
	timestamp = function(day, month, year)
		if tonumber(day or '') and tonumber(month or '') and tonumber(year or '') then
			return os.time{day = tonumber(day), month = tonumber(month), year = tonumber(year), isdst = false,}
		end
	end,
} -- Functions

function Vars(line, fname, esub) -- Makes allowance for {$Variables}
	local tbl = {mname = Settings.MonthNames[Time.show.month] or Time.show.month, year = Time.show.year, today = LZero(Time.curr.day), month = Time.show.month}
	local D, W = {sun = 0, mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6}, {first = 0, second = 1, third = 2, fourth = 3, last = 4}

	local value = function(variable)
		local var = variable:gsub('%s', ''):lower()
		
		-- Function
		if (Functions or {})[var:match('[^:]+:.+') or ''] then
			local name, vtype = variable:gsub('%s', ''):match('^([^:]+):(.+)')
			return Functions[name:lower()](unpack(Delim(vtype, ',')))
		
		-- BuiltIn Event
		elseif (BuiltIn or {})[var:match('([^:]+):.+') or ''] then
			local name, vtype = var:match('^([^:]+):(.+)')
			local stamp = BuiltIn[name]()
			return vtype == 'stamp' and stamp or os.date('*t', stamp)[vtype]
		
		-- Make allowance for old BuiltIn style
		elseif BuiltIn[var:match('(.+)month$') or var:match('(.+)day$') or ''] then
			local name = var:match('(.+)month$') or var:match('(.+)day$')
			local vtype = var:match('^' .. name .. '(.+)')
			return os.date('*t', BuiltIn[name]())[vtype]
		
		-- Event File Variable
		elseif ((Variables or {})[fname or ''] or {})[var] then
			return Variables[fname][var]
		
		-- Script Variable
		elseif tbl[var] then
			return tbl[var]
		
		-- Variable Day
		elseif W[var:match('(.+)...$') or ''] or D[var:match('.+(...)$') or ''] then
			local v1, v2 = var:match('(.+)(...)')
			if v1 == 'last' then -- Last Day
				local L = 36 + D[v2] - Time.stats.startday
				return L - math.ceil((L - Time.stats.clength) / 7) * 7
			else -- Variable Day
				return rotate(D[v2]) + 1 - Time.stats.startday + (Time.stats.startday > rotate(D[v2]) and 7 or 0) + 7 * W[v1]
			end
		end
	end -- value

	-- Allows for nested variables. IE: {$Var{$OtherVar}}
	-- In order to get around an issue where the function needed to be global,
	-- the function must be passed itself as an argument.
	local nested = function(string, self)
		return (string:gsub('%b{}', function(input)
			local newline = self(input:match('^{(.-)}$'), self)
			local name = newline:match('%$(.+)')
			if (name or '') ~= '' then
				return value(name) or ErrMsg(esub, 'Invalid Variable {$%s}', name)
			else
				return ('{%s}'):format(newline)
			end
		end))
	end -- nested

	return nested(line, nested)
end -- Vars

Parse = {
	Number = function(line, default, fname, round)
		line = Vars(line, fname, 0):gsub('%s', '')
		if line == '' then
			return default
		else
			local number = SKIN:ParseFormula('(' .. line .. ')') or default
			return tonumber(round and ('%.' .. round .. 'f'):format(number) or number)
		end
	end, -- Number

	Boolean = function(line, fname)
		line = Vars(line, fname, ''):gsub('%s', ''):gsub('(%b())', function(input) return SKIN:ParseFormula(input) end)
		if tonumber(line) then
			return tonumber(line) > 0
		else
			return line:lower() == 'true'
		end
	end, -- Boolean

	List = function(line, default, fname, list)
		line = Vars(line, fname, ''):gsub('[|%s]', ''):lower()
		return list:find(line) and line or default
	end, -- List

	String = function(line, default, fname, spaces)
		line = Vars(line, fname, '')
		if line == '' then
			return default
		elseif spaces then
			return line
		else
			return line:gsub('%s', '')
		end
	end, -- String

	Color = function(line, fname)
		line = Vars(line, fname, 0):gsub('%s', ''):gsub('(%b())', function(input) return SKIN:ParseFormula(input) end)
		local tbl = {}
		if line == '' then
			return ''
		elseif line:match(',') then
			for rgb in line:gmatch('[^,]+') do
				if not tonumber(rgb) then
					return ErrMsg('', 'Invalid RGB color code found in %s.', fname)
				else
					table.insert(tbl, ('%02X'):format(tonumber(rgb)))
				end
			end
		else
			for hex in line:gmatch('%S%S') do
				if not tonumber(hex, 16) then
					return ErrMsg('', 'Invalid HEX color code found in %s.', fname)
				else
					table.insert(tbl, hex:upper())
				end
			end
		end
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
		local unique = true
		for _, v in ipairs(rMessage) do
			if v == msg then
				unique = false
				break
			end
		end
		if unique then table.insert(rMessage, msg) end
	end
	return value
end -- ErrMsg

function ReturnError() -- Used to prevent duplicate error messages
	if rMessage then
		for _, v in ipairs(rMessage) do SKIN:Bang('!Log', v, 'ERROR') end
		Error, rMessage = rMessage[#rMessage], nil
		return Error
	else
		return Error or 'Success!'
	end
end -- ReturnError

function test(...) -- clone of assert
	local rvalue = table.remove(arg, 1)
	if not rvalue then ErrMsg(nil, unpack(arg)) end
	return rvalue
end -- test

Get = {
	Option = function(option, default) -- Allows for existing but empty string options.
		local input = SELF:GetOption(option)
		if input == '' then
			return default or ''
		else
			return input
		end
	end, -- GetOption

	NumberOption = function(option, default) -- Allows for existing but empty number options.
		return tonumber(SELF:GetOption(option)) or default or 0
	end, -- GetNumberOption

	Variable = function(option, default) -- Allows for existing but empty variables.
		local input = SKIN:GetVariable(option) or default
		if default and input == '' then
			return default
		else
			return input
		end
	end, -- GetVariable
	
	NumberVariable = function(option, default) -- Allows for existing but empty numeric variables.
		local input = SKIN:GetVariable(option) or default or 0
		if default and input == '' then
			input = default
		end
		return SKIN:ParseFormula(input) or default or 0
	end, -- GetNumberVariable
}

-- Function provided by Mordasius, tweaked by Smurfier
function GetPhaseNumber(year, month, day)
	-- Helper functions
	local fixangle = function(a) return a % 360 end
	-- Deg->Rad
	local torad = function(d) return d * (math.pi / 180) end

	-- Convert Gregorian Date into Julian Date
	local gregorian = year >= 1583
	if month == 1 or month == 2 then
		year, month = (year - 1), (month + 12)
	end
	local a = math.floor(year / 100)
	local b = gregorian and (2 - a + math.floor(a / 4)) or 0
	local Jday = math.floor(365.25 * (year + 4716)) + math.floor(30.6001 * (month + 1)) + day + b - 1524.5 + ((60 * (60 * 12)) / 86400)	

	local eccent, Day, M, Ec, Lambdasun, ml, Ev, Ae, MM, MmP, mEc, lP
	eccent = 0.016718 -- Eccentricity of Earth's orbit
	Day = Jday - 2444238.5 -- Date within epoch
	M = torad(fixangle(fixangle((360 / 365.2422) * Day) - 3.762863)) -- Convert from perigee co-ordinates to epoch 1980.0
	
	-- Solve Kepler equation
	local e, delta = M, - eccent * math.sin(M)
	while math.abs(delta) > 1E-6 do
		delta = e - eccent * math.sin(e) - M
		e = e - delta / (1 - eccent * math.cos(e))
	end

	Ec = 2 * ((math.atan(math.sqrt((1 + eccent) / (1 - eccent)) * math.tan(e / 2))) * (180 / math.pi)) -- True anomaly
	Lambdasun = fixangle(Ec + 282.596403) -- Sun's geocentric ecliptic Longitude
	ml = fixangle(13.1763966 * Day + 64.975464) -- Moon's mean Longitude
	MM = fixangle(ml - 0.1114041 * Day - 348.383063) -- Moon's mean anomaly
	Ev = 1.2739 * math.sin(torad(2 * (ml - Lambdasun) - MM)) -- Evection
	Ae = 0.1858 * math.sin(M) -- Annual equation
	MmP = torad(MM + Ev - Ae - (0.37 * math.sin(M))) -- Corrected anomaly
	mEc = 6.2886 * math.sin(MmP) -- Correction for the equation of the centre
	lP = ml + Ev + mEc - Ae + (0.214 * math.sin(2 * MmP)) -- Corrected Longitude
	local PhaseNum = fixangle((lP + (0.6583 * math.sin(torad(2 * (lP - Lambdasun))))) - Lambdasun)

	if PhaseNum > 10 and PhaseNum <= 85 then
		return 2 -- Waxing Crescent
	elseif PhaseNum > 85 and PhaseNum <= 95 then
		return 3 -- First Quarter
	elseif PhaseNum > 95 and PhaseNum <= 170 then
		return 4 -- Waxing Gibbous
	elseif PhaseNum > 170 and PhaseNum <= 190 then
		return 5 -- Full Moon
	elseif PhaseNum > 190 and PhaseNum <= 265 then
		return 6 -- Waning Gibbous
	elseif PhaseNum > 265 and PhaseNum <= 275 then
		return 7 -- Last Quarter
	elseif PhaseNum > 275 and PhaseNum <= 350 then
		return 8 -- Waning Crescent
	else
		return 1 -- New Moon
	end
end  -- function GetPhaseNumber