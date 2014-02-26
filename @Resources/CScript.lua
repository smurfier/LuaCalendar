-- LuaCalendar v5.0 by Smurfier (smurfier@outlook.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
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
	local Current = Time.curr.all
	local NewMonth = Time.stats.inmonth and Time.show.month ~= Current.month
	local BrowsingMonth = (not Time.stats.inmonth) and Time.show.month == Current.month and Time.show.year == Current.year
	if NewMonth or BrowsingMonth then Move() end
	
	-- Recalculate and Redraw if Month and/or Year changes
	if Time.show.month ~= Time.old.month or Time.show.year ~= Time.old.year then
		Time.old = {month = Time.show.month, year = Time.show.year, day = Time.curr.day,}
		Time.stats() -- Set all Time.stats values for the current month.
		ParseEvents()
		Draw()
	elseif Time.curr.day ~= Time.old.day and Time.stats.inmonth then -- Redraw if Today changes
		Time.old.day = Time.curr.day
		Draw()
	end
	
	return ReturnErrorMessage()
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
			Color = 'FontColor', -- String
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
			DisableScroll = false, -- Boolean
		},
		-- Use __newindex to validate setting values.
		__newindex = function(t, key, value)
			local tbl = getmetatable(Settings).__index
			if tbl[key] == nil then
				CreateError('Setting does not exist: %s', key)
			elseif type(value) == type(tbl[key]) then
				rawset(t, key, value)
			else
				ErrorSource = key
				CreateError('Invalid Setting type. Expected %s, received %s instead.', key, type(tbl[key]), type(value))
			end
		end,
	}
) -- Settings

-- Set meter names/formats here.
Meters = {
	Labels = { -- Week Day Labels
		Name = 'l%d', -- Use %d to denote the number (0-6) of the meter.
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
			LastWeek = 'LastWeek',
			PreviousMonth = 'PreviousMonth',
			NextMonth = 'NextMonth',
			Weekend = 'WeekendStyle',
			Event = 'HolidayStyle',
		},
	},
} -- Meters

Time = { -- Used to store and call date functions and statistics
	curr = setmetatable({}, {__index = function(_, index)
		local tbl = os.date('*t')
		return index == 'all' and tbl or tbl[index]
	end,}),
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
				startday = LeadingZero(tonumber(os.date('%w', tstart))), -- Day code for the first day of the current month.
			}
			
			for k, v in pairs(values) do rawset(t, k, v) end
		end,}
	),
} -- Time

Range = setmetatable( -- Makes allowance for either Month or Week ranges
	{
		month = {
			formula = function(input) return input - Time.stats.startday end,
			adjustment = function(input) return input end,
			days = 42,
			week = function() return math.ceil((Time.curr.day + Time.stats.startday) / 7) end,
		},
		week = {
			formula = function(input) return Time.curr.day + ((input - 1) - RotateDay(Time.curr.wday - 1)) end,
			adjustment = function(input) local num = input % 7; return num == 0 and 7 or num end,
			days = 7,
			week = function() return 1 end,
			nomove = true,
		},
	},
	{
		__index = function(tbl, index) return ReturnError(tbl.month, 'Invalid Range: %s', index) end,
	}
) -- Range

function Delim(input, Separator) -- Separates an input string by a delimiter
	ErrorSource = 'Delim'
	local tbl = {}
	if TestError(type(input) == 'string', 'Input must be a string. Received %s instead', type(input)) then
		if not MultiType(Separator, 'nil|string') then
			Separator = ReturnError('|', 'Input #2 must be a string. Received %s instead. Using default value.', type(Separator))
		end
		for word in input:gmatch('[^' .. (Separator or '|') .. ']+') do table.insert(tbl, word:match('^%s*(.-)%s*$')) end
	end
	return tbl
end -- Delim

function ExpandFolder(input) -- Makes allowance for when the first value in a table represents the folder containing all objects.
	ErrorSource = 'ExpandFolder'
	if type(input) ~= 'table' then
		return ReturnError({}, 'Input must be a table. Received %s instead.', type(input))
	else
		if #input > 1 then
			local FolderPath = table.remove(input, 1):match('(.-)[/\\]-$') .. '\\'
			for Key, FileName in ipairs(input) do input[Key] = SKIN:MakePathAbsolute(FolderPath .. FileName) end
		end
		return input
	end
end -- ExpandFolder

function SetLabels(tbl) -- Sets weekday label text
	ErrorSource = 'SetLabels'
	if TestError(type(tbl) == 'table', 'Input must be a table. Received %s instead.', type(tbl)) then
		if #tbl ~= 7 then
			tbl = ReturnError({'S', 'M', 'T', 'W', 'T', 'F', 'S'}, 'Input must be a table with seven indicies. Using default table instead.')
		end
		if Settings.StartOnMonday then table.insert(tbl, table.remove(tbl, 1)) end
		for Label, Text in ipairs(tbl) do SKIN:Bang('!SetOption', Meters.Labels.Name:format(Label - 1), 'Text', Text) end
	end
end -- SetLabels

function LoadEvents(FileTable)
	ErrorSource = 'LoadEvents'
	if not Settings.ShowEvents then
		FileTable = {}
	elseif type(FileTable) ~= 'table' then
		FileTable = ReturnError({}, 'Input must be a table. Received %s instead.', type(FileTable))
	end
	
	EventsData = {}
	
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
	
	local ParseKeys = function(line, default)
		local tbl, escape = default or {}, {quot = '"', amp = '&', lt = '<', gt = '>', apos = "'",}
		
		for key, value in line:gmatch('(%a+)="([^"]+)"') do
			tbl[key:lower()] = value:gsub('&([^;]+);', escape):gsub('\r?\n', ' '):match('^%s*(.-)%s*$')
		end
		
		return tbl
	end -- ParseKeys
	
	for _, FilePath in ipairs(FileTable) do
		local FileName = FilePath:match('[^/\\]+$')
		local FileHandle = TestError(io.open(FilePath, 'r'), 'File read error: %s', FileName)
		
		local OpenTag, FileContent, CloseTag = '', '', ''
		if FileHandle then
			local FileText = FileHandle:read('*all')
			-- Remove commented sections
			FileText = FileText:gsub('<!%-%-.-%-%->', '')
			-- Validate XML structure, part 1
			OpenTag, FileContent, CloseTag = FileText:match('^.-<([^>]+)>(.+)<([^>]+)>[^>]*$')
			FileHandle:close()
		end
		
		-- Validate XML structure, part 2
		if (OpenTag or ''):match('%S*'):lower() ~= 'eventfile' or (CloseTag or ''):lower() ~= '/eventfile' then
			-- Set FileContent to empty in order to skip the tag iterator
			FileContent = ReturnError('', 'Invalid event file: %s', FileName)
		end
		
		local eFile, SetTags, ContentQueue = ParseKeys(OpenTag or ''), {}
		
		local AddEvent = function(options)
			local dSet, tbl = {}, {fname = FileName,}
			-- Collapse set matrix into a single table
			for _, column in ipairs(SetTags) do
				for key, value in pairs(column) do dSet[key] = value end
			end
			-- Work through all tables to add option to temporary table
			for _, v in pairs(KeyNames) do
				tbl[v] = options[v] or dSet[v] or eFile[v] or ''
			end
			-- Add temporary table to main Events table
			table.insert(EventsData, tbl)
		end -- AddEvent
		
		-- Tag Iterator
		for TagName, KeyLine, Contents in FileContent:gmatch('<%s-([^%s>]+)([^>]*)>([^<]*)') do
			TagName, Contents = TagName:lower(), Contents:gsub('%s+', ' ')
			
			if ContentQueue then
				if TestError(TagName == '/event',  'Event tags may not have nested tags. File: %s', FileName) then
					AddEvent(ParseKeys(ContentQueue.KeyLine, {description = ContentQueue.Contents,}))
				end
				ContentQueue = nil
			elseif TagName == 'variable' then
				local Temp = Keys(KeyLine)
				
				if not Variables then
					Variables = {[FileName] = {[Temp.name:lower()] = Temp.select,},}
				elseif not Variables[FileName] then
					Variables[FileName] = {[Temp.name:lower()] = Temp.select,}
				else
					Variables[FileName][Temp.name:lower()] = Temp.select
				end
			elseif TagName == 'set' then
				table.insert(SetTags, ParseKeys(KeyLine))
			elseif TagName == '/set' then
				table.remove(SetTags)
			elseif TagName == 'event' then
				-- inline closing event tag
				if KeyLine:match('/%s-$') then
					AddEvent(ParseKeys(KeyLine))
				-- Tag is open, create queue
				elseif Contents:gsub('[\t\n\r%s]', '') ~= '' then
					ContentQueue = {KeyLine = KeyLine, Contents = Contents:gsub('\r?\n', ' '),}
				-- Error
				else
					CreateError('Event tag detected without contents. File: %s', FileName)
				end	
			else
				CreateError('Invalid Tag <%s> in %s', TagName, FileName)
			end
		end
		
		if ContentQueue or #SetTags > 0 then CreateError('Unmatched Event or Set tag detected. File: %s', FileName) end
	end
end -- LoadEvents

function ParseEvents() -- Parse Events table.
	ErrorSource = 'ParseEvents'
	Events = {}
	
	-- Helper Functions
	local tstamp = function(d, m, y)
		return os.time{day = d, month = m or Time.show.month, year = y or Time.show.year, isdst = false}
	end -- tstamp
	
	local TestRequirements = function(...)
		local State = true
		for k, v in ipairs(arg) do State = State and v end
		return State
	end -- TestRequirements
	
	local DefineEvent = function(EventDay, EventDescription, EventColor)
		if not Events[EventDay] then
			Events[EventDay] = {text = {EventDescription}, color = {EventColor},}
		else
			table.insert(Events[EventDay].text, EventDescription)
			table.insert(Events[EventDay].color, EventColor)
		end
	end -- DefineEvent
	
	for _, event in ipairs(EventsData or {}) do
		-- Parse necessary options
		local DateTable = {
			multip = Parse.Number(event.multiplier, 1, event.fname, 0),
			erepeat = Parse.List(event['repeat'], 'none', event.fname, 'none|week|year|month|custom'),
			finish = Parse.Number(event.finish, Time.stats.nmonth, event.fname),
		}
		
		-- Find matching events
		if DateTable.finish >= Time.stats.cmonth and not Parse.Boolean(event.inactive, false, event.fname) then
			-- More necessary options
			local EventStamp = Parse.Number(event.timestamp, false, event.fname)
			if EventStamp then
				local temp = os.date('*t', EventStamp)
				for k, v in pairs(temp) do DateTable[k] = v end
			else
				local temp = {
					month = Parse.Number(event.month, false, event.fname),
					day = Parse.Number(event.day, false, event.fname) or ReturnError(0, 'Invalid Day %s in %s', event.day, event.description),
					year = Parse.Number(event.year, false, event.fname),
				}
				for k, v in pairs(temp) do DateTable[k] = v end
			end
			
			local AddEvent = function(EventDay, AnniversaryNumber)
				local EventDescription = Parse.String(event.description, false, event.fname, true) or ReturnError('', 'Event detected with no Description.')
				local UseAnniversary =  Parse.Boolean(event.anniversary, false, event.fname) and AnniversaryNumber
				local EventTitle = Parse.String(event.title, false, event.fname, true)
				
				if UseAnniversary and EventTitle then
					EventDescription = string.format('%s (%s) -%s', EventDescription, AnniversaryNumber, EventTitle)
				elseif UseAnniversary then
					EventDescription = string.format('%s (%s)', EventDescription, AnniversaryNumber)
				elseif EventTitle then
					EventDescription = string.format('%s -%s', EventDescription, EventTitle)
				end
				
				local case = Parse.List(event.case, 'none', event.fname, 'none|lower|upper|title|sentence')
				if case == 'lower' then
					EventDescription = EventDescription:lower()
				elseif case == 'upper' then
					EventDescription = EventDescription:upper()
				elseif case == 'title' then
					EventDescription = EventDescription:gsub('(%S)(%S*)', function(first, rest) return first:upper() .. rest:lower() end)
				elseif case == 'sentence' then
					EventDescription = EventDescription:gsub('[^.!?]+', function(sentence)
						local space, first, rest = sentence:match('(%s*)(.)(.*)')	
						return space .. first:upper() .. rest:lower():gsub("%si([%s'])", ' I%1')
					end)
				end
				
				local EventColor = Parse.Color(event.color, event.fname)
				
				if not Parse.String(event.skip, '', event.fname):find(string.format('%02d%02d%04d', EventDay, Time.show.month, Time.show.year)) then
					DefineEvent(EventDay, EventDescription, EventColor)
				end
			end -- AddEvent
			
			local frame = function(period) -- Repeats an event based on a given number of seconds
				local start = tstamp(DateTable.day, DateTable.month, DateTable.year)
				
				if Time.stats.nmonth >= start then
					local first = Time.stats.cmonth > start and (Time.stats.cmonth + (period - ((Time.stats.cmonth - start) % period))) or start
					
					for i = first, (DateTable.finish < Time.stats.nmonth and DateTable.finish or Time.stats.nmonth), period do
						AddEvent(tonumber(os.date('%d', i)), (i - start) / period + 1)
					end
				end
			end -- frame
			
			-- Begin testing and adding events to table
			if DateTable.erepeat == 'custom' then
				local Results = TestRequirements(
					TestError(DateTable.year, 'Year must be specified in %s when using Custom repeat.', event.description),
					TestError(DateTable.month, 'Month must be specified in %s when using Custom repeat.', event.description),
					TestError(DateTable.day, 'Day must be specified in %s when using Custom repeat.', event.description),
					TestError(DateTable.multip >= 86400, 'Multiplier must be greater than or equal to 86400 in %s when using Custom repeat.', event.description)
				)
				
				if Results then frame(DateTable.multip) end
				
			elseif DateTable.erepeat == 'week' then
				local Results = TestRequirements(
					TestError(DateTable.year, 'Year must be specified in %s when using Week repeat.', event.description),
					TestError(DateTable.month, 'Month must be specified in %s when using Week repeat.', event.description),
					TestError(DateTable.day, 'Day must be specified in %s when using Week repeat.', event.description),
					TestError(DateTable.multip >= 1, 'Multiplier must be greater than or equal to 1 in %s when using Week repeat.', event.description)
				)
				
				if Results then frame(DateTable.multip * 604800) end
				
			elseif DateTable.erepeat == 'year' then
				local Results = TestRequirements(
					TestError(DateTable.day, 'Day must be specified in %s when using Year repeat.', event.description),
					TestError(DateTable.month, 'Month must be specified in %s when using Year repeat.', event.description)
				)
				
				if Results and tstamp(DateTable.day, DateTable.month, Time.show.year) <= DateTable.finish then
					local TestYear = 0
					if DateTable.year and DateTable.multip > 1 then
						TestYear = (Time.show.year - DateTable.year) % DateTable.multip
					end
					if DateTable.month == Time.show.month and TestYear == 0 then
						AddEvent(DateTable.day, DateTable.year and Time.show.year - DateTable.year / DateTable.multip)
					end
				end
				
			elseif DateTable.erepeat == 'month' then
				local Results = TestError(DateTable.day, 'Day must be specified in %s when using Month repeat.', event.description)
				
				if not Results and tstamp(DateTable.day, DateTable.month, DateTable.year) <= DateTable.finish then
					-- Do Nothing
				elseif not DateTable.month and DateTable.year then
					AddEvent(DateTable.day)
				elseif Time.show.year >= DateTable.year then
					local ydiff = Time.show.year - DateTable.year - 1
					local mdiff
					if ydiff == -1 then
						mdiff = Time.show.month - DateTable.month
					else
						mdiff = (12 - DateTable.month) + Time.show.month + ydiff * 12
					end
					
					if (mdiff % DateTable.multip) == 0 and Time.stats.cmonth >= tstamp(1, DateTable.month, DateTable.year) then
						AddEvent(DateTable.day, mdiff / DateTable.multip + 1)
					end
				end
				
			elseif DateTable.erepeat =='none' then
				if DateTable.year == Time.show.year and DateTable.month == Time.show.month then
					AddEvent(DateTable.day)
				end
			end
		end
	end
	
	-- Find the Moon Phases for the Month
	if type(GetPhaseNumber) == 'function' and Settings.MoonPhases and Settings.ShowEvents then
		local MoonPhases, PhaseNames = {}, {[1] = 'New Moon', [5] = 'Full Moon',}
		for i = 1, Time.stats.clength do
			local PhaseNumber = GetPhaseNumber(Time.show.year, Time.show.month, i)
			if PhaseNames[PhaseNumber] and not MoonPhases[i - 1] then
				MoonPhases[i] = PhaseNames[PhaseNumber]
			end
		end
		-- Apply the Moon Phases to the Events table
		for PhaseDay, PhaseType in pairs(MoonPhases) do DefineEvent(PhaseDay, PhaseType, Settings.MoonColor) end
	end
end -- ParseEvents

function Draw() -- Sets all meter properties and calculates days
	local HideLastWeek = Settings.HideLastWeek and math.ceil((Time.stats.startday + Time.stats.clength) / 7) < 6
	
	-- Set Weekday Labels styles
	local CurrentWeekDay = RotateDay(Time.curr.wday - 1)
	for WeekDay = 0, 6 do
		local Styles = {Meters.Labels.Styles.Normal}
		if WeekDay == 0 then table.insert(Styles, Meters.Labels.Styles.First) end
		if CurrentWeekDay == WeekDay and Time.stats.inmonth then table.insert(Styles, Meters.Labels.Styles.Current) end
		SKIN:Bang('!SetOption', Meters.Labels.Name:format(WeekDay), 'MeterStyle', table.concat(Styles, '|'))
	end
	
	-- Calculate and set day meters
	local CurrentDayMeter = Range[Settings.Range].adjustment(Time.curr.day + Time.stats.startday)
	for MeterNumber = 1, Range[Settings.Range].days do
		local Styles, day, EventText, EventColor = {Meters.Days.Styles.Normal}, Range[Settings.Range].formula(MeterNumber)
		
		if MeterNumber == 1 then
			table.insert(Styles, Meters.Days.Styles.FirstDay)
		elseif (MeterNumber % 7) == 1 then
			table.insert(Styles, Meters.Days.Styles.NewWeek)
		end
		
		-- Events ToolTip and MeterStyle
		if (Events or {})[day] and day > 0 and day <= Time.stats.clength then
			EventText = table.concat(Events[day].text, '\n')
			table.insert(Styles, Meters.Days.Styles.Event)
			
			for _, value in ipairs(Events[day].color) do
				if value == '' then
					-- Do Nothing
				elseif not EventColor then
					EventColor = value
				elseif EventColor ~= value then
					EventColor = ''
					break
				end
			end
		end
		
		-- Regular MeterStyles
		if CurrentDayMeter == MeterNumber and Time.stats.inmonth then
			table.insert(Styles, Meters.Days.Styles.Current)
		elseif MeterNumber > 35 and HideLastWeek then
			table.insert(Styles, Meters.Days.Styles.LastWeek)
		elseif day < 1 then
			day = day + Time.stats.plength
			table.insert(Styles, Meters.Days.Styles.PreviousMonth)
		elseif day > Time.stats.clength then
			day = day - Time.stats.clength
			table.insert(Styles, Meters.Days.Styles.NextMonth)
		elseif (MeterNumber % 7) == 0 or (MeterNumber % 7) == (Settings.StartOnMonday and 6 or 1) and not EventText then
			table.insert(Styles, Meters.Days.Styles.Weekend)
		end
		
		-- Define meter properties
		local MeterName = Meters.Days.Name:format(MeterNumber)
		local MeterProperties = {
			Text = LeadingZero(day),
			MeterStyle = table.concat(Styles, '|'),
			ToolTipText = EventText or '',
			[Settings.Color or 'FontColor'] = EventColor or '',
		}
		for Option, Value in pairs(MeterProperties) do SKIN:Bang('!SetOption', MeterName, Option, Value) end
	end
	
	-- Define skin variables
	local SkinVariables = {
		ThisWeek = Range[Settings.Range].week(),
		Week = RotateDay(Time.curr.wday - 1),
		Today = LeadingZero(Time.curr.day),
		Month = Settings.MonthNames[Time.show.month] or Time.show.month,
		Year = Time.show.year,
		MonthLabel = ParseVariables(Settings.LabelFormat),
		LastWkHidden = HideLastWeek and 1 or 0,
		NextEvent = '',
	}
	
	-- Week Numbers for the current month
	local FirstWeek = os.time{day = (6 - Time.stats.startday), month = Time.show.month, year = Time.show.year}
	for i = 0, 5 do
		local WeekName = string.format('WeekNumber%d', i + 1)
		SkinVariables[WeekName] = math.ceil(os.date('%j', FirstWeek + i * 604800) / 7)
	end
	
	-- Parse Events table to create a list of events
	local Current = Time.curr.all
	if type(Events) == 'table' and Time.stats.cmonth >= os.time{day = 1, month = Current.month, year = Current.year,} then
		ErrorSource = 'NextFormat'
		local Evns = {}
		
		-- Parse through month days to keep days in order
		for day = Time.stats.inmonth and Time.curr.day or 1, Time.stats.clength do
			if Events[day] then
				local names = {day = day, desc = table.concat(Events[day].text, ', '),}
				
				local line = Settings.NextFormat:gsub('{%$([^}]+)}', function(variable)
					return names[variable:lower()] or ReturnError('', 'Invalid variable {$%s}', variable)
				end)
				
				table.insert(Evns, line)
			end
		end
		
		SkinVariables.NextEvent = table.concat(Evns, '\n')
	end
	
	-- Set Skin Variables
	for Name, Value in pairs(SkinVariables) do SKIN:Bang('!SetVariable', Name, Value) end
end -- Draw

function Move(value) -- Move calendar through the months
	ErrorSource = 'Move'
	if not MultiType(value, 'nil|number') then
		CreateError('input must be a number. Received %s instead.', type(value))
	elseif Range[Settings.Range].nomove or not value then
		Time.show = Time.curr.all
	elseif TestError(math.ceil(value) == value, 'Invalid input %s', value) then -- Check that value is not a decimal
		local Years = math.modf(value / 12) -- Number of years without months
		local Months = Time.show.month + value - Years * 12 -- Number of months without years
		local MonthsAdjustment
		if value < 0 then
			MonthsAdjustment = Months < 1 and 12 or 0
		else
			MonthsAdjustment = Months > 12 and -12 or 0
		end
		Time.show = {month = (Months + MonthsAdjustment), year = (Time.show.year + Years - MonthsAdjustment / 12),}
	end
	
	local Current = Time.curr.all
	Time.stats.inmonth = Time.show.month == Current.month and Time.show.year == Current.year
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

function ParseVariables(line, FileName, ErrorSubstitute) -- Makes allowance for {$Variables}
	ErrorSource = 'ParseVariables'
	local ScriptVariables = {
		mname = Settings.MonthNames[Time.show.month] or Time.show.month,
		year = Time.show.year,
		today = LeadingZero(Time.curr.day),
		month = Time.show.month,
	}
	local Day, Week = {sun = 0, mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6,}, {first = 0, second = 1, third = 2, fourth = 3,}
	
	local value = function(variable)
		local var = variable:gsub('%s', ''):lower()
		
		-- Function
		if (Functions or {})[var:match('([^:]+):.+') or ''] then
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
		elseif ((Variables or {})[FileName or ''] or {})[var] then
			return Variables[FileName][var]
		
		-- Script Variable
		elseif ScriptVariables[var] then
			return ScriptVariables[var]
		
		-- Variable Day
		elseif Week[var:match('(.+)...$') or ''] or Day[var:match('.+(...)$') or ''] then
			local WeekNum, DayNum = var:match('(.+)(...)')
			if WeekNum == 'last' then -- Last Day
				local AbsoluteLast = 36 + Day[DayNum] - Time.stats.startday -- Last week day in week 6
				local AdjustmentDays = math.ceil((AbsoluteLast - Time.stats.clength) / 7) * 7
				return AbsoluteLast - AdjustmentDays
			else -- Variable Day
				local AdjustedDay = RotateDay(Day[DayNum])
				local FirstDay = AdjustedDay + 1 - Time.stats.startday + (Time.stats.startday > AdjustedDay and 7 or 0)
				return FirstDay + 7 * Week[WeekNum]
			end
		end
	end -- value
	
	-- Allows for nested variables. IE: {$Var{$OtherVar}}
	-- In order to get around an issue where the function needed to be global,
	-- the function must be passed itself as an argument.
	local NestedExpression = function(InputLine, self)
		return (InputLine:gsub('%b{}', function(InputExpression)
			local NewLine = self(InputExpression:match('^{(.-)}$'), self)
			local name = NewLine:match('%$(.+)') or ''
			if name ~= '' then
				return value(name) or ReturnError(ErrorSubstitute, 'Invalid Variable {$%s}', name)
			else
				return string.format('{%s}', NewLine)
			end
		end))
	end -- NestedExpression
	
	return NestedExpression(line, NestedExpression)
end -- ParseVariables

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
	end, -- GetNumberVariable
}

Parse = {
	Number = function(line, default, FileName, Decimals)
		line = ParseVariables(line, FileName, 0):gsub('%s', '')
		if line == '' then
			return default
		else
			local number = SKIN:ParseFormula('(' .. line .. ')') or default
			return tonumber(Decimals and string.format('%.' .. Decimals .. 'f', number) or number)
		end
	end, -- Number
	
	Boolean = function(line, default, FileName)
		line = ParseVariables(line, FileName, ''):gsub('%s', ''):gsub('(%b())', function(input) return SKIN:ParseFormula(input) end)
		if line == '' then
			return default
		elseif tonumber(line) then
			return tonumber(line) ~= 0
		else
			return line:lower() == 'true'
		end
	end, -- Boolean
	
	List = function(line, default, FileName, FullList)
		line = ParseVariables(line, FileName, ''):gsub('[|%s]', ''):lower()
		return FullList:find(line) and line or default
	end, -- List
	
	String = function(line, default, FileName, AllowSpaces)
		line = ParseVariables(line, FileName, '')
		if line == '' then
			return default
		elseif AllowSpaces then
			return line
		else
			return line:gsub('%s', '')
		end
	end, -- String
	
	Color = function(line, FileName)
		line = ParseVariables(line, FileName, 0):gsub('%s', ''):gsub('(%b())', function(input) return SKIN:ParseFormula(input) end)
		local tbl = {}
		if line == '' then
			return ''
		elseif line:match(',') then
			for rgb in line:gmatch('[^,]+') do
				if not tonumber(rgb) then
					return ReturnError('', 'Invalid RGB color code found in %s.', FileName)
				else
					table.insert(tbl, string.format('%02X', tonumber(rgb)))
				end
			end
		else
			for hex in line:gmatch('%S%S') do
				if not tonumber(hex, 16) then
					return ReturnError('', 'Invalid HEX color code found in %s.', FileName)
				else
					table.insert(tbl, hex:upper())
				end
			end
		end
		return table.concat(tbl)
	end, -- Color
}

function RotateDay(value) -- Makes allowance for StartOnMonday
	return Settings.StartOnMonday and ((value - 1 + 7) % 7) or value
end -- RotateDay

function LeadingZero(value) -- Makes allowance for LeadingZeros
	return Settings.LeadingZeroes and string.format('%02d', value) or value
end -- LeadingZero

function MultiType(input, types) -- Test an input against multiple types
	return types:find(type(input)) and true or false
end -- MultiType

-- Begin all functions related to error checking
function ReturnErrorMessage() -- Logs all queued error messages
	if ErrorQueue then
		for _, Message in ipairs(ErrorQueue) do SKIN:Bang('!Log', Message, 'ERROR') end
		ErrorMessage, ErrorQueue = ErrorQueue[#ErrorQueue], nil
	end
	return ErrorMessage or 'Success!'
end -- ReturnErrorMessage

-- Remember to set the ErrorSource variable before calling any error message function.
function CreateError(...) -- Add error messages to queue
	local NewMessage = ErrorSource .. ': ' .. string.format(unpack(arg))
	if not ErrorQueue then
		ErrorQueue = {NewMessage}
	else
		-- Prevent duplicate messages
		local unique = true
		for _, CachedMessage in ipairs(ErrorQueue) do
			if CachedMessage == NewMessage then
				unique = false
				break
			end
		end
		if unique then table.insert(ErrorQueue, NewMessage) end
	end
end -- CreateError

function ReturnError(...) -- Create error message and return value
	local ReturnValue = table.remove(arg, 1)
	CreateError(unpack(arg))
	return ReturnValue
end -- ReturnError

function TestError(...) -- Clone of assert
	local ReturnValue = table.remove(arg, 1)
	if not ReturnValue then CreateError(unpack(arg)) end
	return ReturnValue
end -- TestError

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