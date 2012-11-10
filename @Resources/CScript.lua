-- LuaCalendar v4.0 by Smurfier (smurfier20@gmail.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Set = { -- Retrieve Measure Settings
		Name = 'LuaCalendar',
		Color = 'FontColor',
		HLWeek = SELF:GetNumberOption('HideLastWeek', 0) > 0,
		LZer = SELF:GetNumberOption('LeadingZeroes', 0) > 0,
		SMon = SELF:GetNumberOption('StartOnMonday', 0) > 0,
		LText = SELF:GetOption('LabelText', '{MName}, {Year}'),
		NFormat = SELF:GetOption('NextFormat', '{day}: {desc}'):lower(),
	}

	Meters = {
		Labels = {
			Name = 'l%d',
			Styles = {
				Normal = 'LblTxtSty',
				First = 'LblTxtStart',
				Current = 'LblCurrSty',
			},
		},
		Days = {
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
	}

	Time = {
		curr = {},
		old = {day = 0, month = 0, year = 0,},
		show = {month = 0, year = 0,},
		stats = {clength = 0, plength = 0, startday = 0, inmonth = true,},
	}

	local sRange = SELF:GetOption('Range', 'month'):lower():gsub(' ', '')
	if not ('week|month'):find(sRange) then ErrMsg(nil, 'Invalid Range: %s', sRange) end
	if sRange == 'week' then
		Range = {
			formula = function(input) return Time.curr.day +((input - 1) - rotate(Time.curr.wday - 1)) end,
			days = 7,
			week = function() return 1 end,
			nomove = true,
		}
	else
		Range = {
			formula = function(input) return input - Time.stats.startday end,
			days = 42,
			week = function() return math.ceil((Time.curr.day + Time.stats.startday) / 7) end,
		}
	end
	-- Weekday labels text
	local Labels = {}
	for label in SELF:GetOption('DayLabels', 'S|M|T|W|T|F|S'):gmatch('[^|]+') do table.insert(Labels, label) end
	SetLabels(Labels)
	-- Localization
	MLabels = setmetatable({}, { __index = function(_, key) return key end})
	if SELF:GetNumberOption('UseLocalMonths', 0) > 0 then
		os.setlocale('', 'time')
		for a = 1, 12 do MLabels[a] = os.date('%B', os.time{year = 2000, month = a, day = 1}) end
	else
		for label in SELF:GetOption('MonthLabels'):gmatch('[^|]+') do table.insert(MLabels, label) end
	end
	--Events File
	local fTemp = {}
	for word in SELF:GetOption('EventFile'):gmatch('[^|]+') do table.insert(fTemp, word) end
	if SELF:GetNumberOption('SingleFolder', 0) > 0 and #fTemp > 1 then
		local folder = table.remove(fTemp, 1)
		if not folder:match('[/\\]$') then folder = folder .. '\\' end
		for k, v in ipairs(fTemp) do fTemp[k] = SKIN:MakePathAbsolute(folder .. v) end
	end
	LoadEvents(fTemp)
end -- Initialize

function Update()
	Time.curr = os.date('*t')
	
	-- If in the current month or if browsing and Month changes to that month, set to Real Time
	if (Time.stats.inmonth and Time.show.month ~= Time.curr.month) or ((not Time.stats.inmonth) and Time.show.month == Time.curr.month and Time.show.year == Time.curr.year) then
		Move()
	end
	
	if Time.show.month ~= Time.old.month or Time.show.year ~= Time.old.year then -- Recalculate and Redraw if Month and/or Year changes
		Time.old = {month=Time.show.month, year=Time.show.year, day=Time.curr.day}
		local tstart = os.time{day = 1, month = Time.show.month, year = Time.show.year, isdst = false,}
		local nstart = os.time{day = 1, month = (Time.show.month % 12 + 1), year = (Time.show.year + (Time.show.month == 12 and 1 or 0)), isdst = false,}
		Time.stats = {
			clength = ((nstart - tstart) / 86400),
			plength = (tonumber(os.date('%d', tstart - 86400))),
			startday = rotate(tonumber(os.date('%w', tstart))),
		}
		Events()
		Draw()
	elseif Time.curr.day ~= Time.old.day then -- Redraw if Today changes
		Time.old.day = Time.curr.day
		Draw()
	end
	
	return rMessage or 'Success!'
end -- Update

function SetLabels(tbl)
	if #tbl < 7 then tbl = ErrMsg({'S', 'M', 'T', 'W', 'T', 'F', 'S'}, 'Invalid DayLabels string') end
	for a = 1, 7 do SKIN:Bang('!SetOption', Meters.Labels.Name:format(a), 'Text', tbl[Set.SMon and (a % 7 + 1) or a]) end
end

function LoadEvents(FileTable)
	hFile = {}
	local default = {
		month = {value = '', ktype = 'string'},
		day = {value = '', ktype = 'string'},
		year = {value = false, ktype = 'number'},
		descri = {value = '', ktype = 'string', spaces = true},
		title = {value = false, ktype = 'string'},
		color = {value = false, ktype = 'color'},
		['repeat'] = {value = false, ktype = 'string'},
		multip = {value = 1, ktype = 'number', round = 0},
		annive = {value = false, ktype = 'boolean'},
		inacti = {value = false, ktype = 'boolean'},
	}

	local Keys = function(line, source)
		local tbl = {}
		
		local funcs = {
			color = function(key, input)
				input = input:gsub('%s', '')
				if input:len() == 0 then
					return false
				elseif input:match(',') then
					local hex = {}
					for rgb in input:gmatch('%d+') do table.insert(hex, ('%02X'):format(tonumber(rgb))) end
					for i = #hex, 4 do table.insert(hex, 'FF') end
					return table.concat(hex)
				else
					return input
				end
			end, -- color
			number = function(key, input)
				local num = tonumber((input:gsub('%s', '')))
				return (num and default[key].round) and ('%.' .. default[key].round .. 'f'):format(num) or num
			end, -- number
			string = function(key, input) return default[key].spaces and input:match('^%s*(.-)%s*$') or (input:gsub('%s', '')) end,
			boolean = function(key, input) return input:gsub('%s', ''):lower() == 'true' end,
		}
	
		local escape = {quot='"', lt='<', gt='>', amp='&',} -- XML escape characters

		for key, value in line:gmatch('(%a+)="([^"]+)"') do
			local nkey = key:sub(1, 6):lower()
			if default[nkey] then
				tbl[nkey] = funcs[(default[nkey].ktype)](nkey, value:gsub('&([^;]+);', escape):gsub('\r?\n', ' '))
			else
				ErrMsg(nil, 'Invalid key %s=%q in %s', key, value, source)
			end
		end
	
		return tbl
	end

	for _, FileName in ipairs(FileTable) do
		local File, fName = io.open(FileName, 'r'), FileName:match('[^/\\]+$')
		
		if not File then
			ErrMsg(nil, 'File Read Error: %s', fName)
		else
			local open, content, close = File:read('*all'):gsub('<!%-%-.-%-%->', ''):match('^.-<([^>]+)>(.+)<([^>]+)>[^>]*$')
			File:close()

			if open:match('%S+'):lower() == 'eventfile' and close:lower() == '/eventfile' then
				local eFile, eSet = Keys(open, fName), {}
				
				for tag, line in content:gmatch('<([^%s>]+)([^>]*)>') do
					local ntag = tag:lower()

					if ntag == 'set' then
						table.insert(eSet, Keys(line, fName))
					elseif ntag == '/set' then
						table.remove(eSet)
					elseif ntag == 'event' then
						local Tmp, dSet, tbl = Keys(line, fName), {}, {}
						for _, column in ipairs(eSet) do
							for key, value in pairs(column) do dSet[key] = value end
						end
						for k, v in pairs(default) do tbl[k] = Tmp[k] or dSet[k] or eFile[k] or v.value end
						if not tbl.inacti then table.insert(hFile, tbl) end
					else
						ErrMsg(nil, 'Invalid Event Tag <%s> in %s', tag, fName)
					end
				end
			else
				ErrMsg(nil, 'Invalid Event File: %s', fName)
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
				table.insert(Evns, (Set.NFormat:gsub('{([^}]+)}', function(variable) return tbl[variable:lower()] end)) )
			end
		end
	
		return table.concat(Evns, '\n')
	end})

	local AddEvn = function(day, desc, color, ann)
		desc = desc:format(ann and (' (%s)'):format(ann) or '')
		if Hol[day] then
			table.insert(Hol[day].text, desc)
			table.insert(Hol[day].color, color)
		else
			Hol[day] = {text = {desc}, color = {color},}
		end
	end
	
	local formula = function(input, source) return SKIN:ParseFormula(('(%s)'):format(Vars(input, source))) end

	for _, event in ipairs(hFile) do
		local eMonth = formula(event.month, event.descri)
		if  eMonth == Time.show.month or event['repeat'] then
			local day = formula(event.day, event.descri) or ErrMsg(0, 'Invalid Event Day %s in %s', event.day, event.descri)
			local desc = event.descri .. '%s' .. (event.title and ' -' .. event.title or '')

			local nrepeat = event['repeat']:lower()

			if nrepeat == 'week' then
				if eMonth and event.year and day then
					local stamp = os.time{month = eMonth, day = day, year = event.year,}
					local test = os.time{month = Time.show.month, day = day, year = Time.show.year,} >= stamp
					local mstart = os.time{month = Time.show.month, day = 1, year = Time.show.year,}
					local multi = event.multip * 604800
					local first = mstart + ((stamp - mstart) % multi)

					for a = 0, 4 do
						local tstamp = first + a * multi
						local temp = os.date('*t', tstamp)
						if temp.month == Time.show.month and test then
							AddEvn(temp.day, desc, event.color, event.annive and ((tstamp - stamp) / multi + 1) or false)
						end
					end
				end
			elseif nrepeat == 'year' then
				local test = (event.year and event.multip > 1) and ((Time.show.year - event.year) % event.multip) or 0

				if eMonth == Time.show.month and test == 0 then
					AddEvn(day, desc, event.color, event.annive and (Time.show.year - event.year / event.multip) or false)
				end
			elseif nrepeat == 'month' then
				if eMonth and event.year then
					if Year >= event.year then
						local ydiff = Time.show.year - event.year - 1
						local mdiff = ydiff == -1 and (Time.show.month - eMonth) or ((12 - eMonth) + Time.show.month + (ydiff * 12))
						local estamp = os.time{year = event.year, month = eMonth, day = 1,}
						local mstart = os.time{year = Time.show.year, month = Time.show.month, day = 1,}

						if (mdiff % event.multip) == 0 and mstart >= estamp then
							AddEvn(day, desc, event.color, event.annive and (mdiff / event.multip + 1) or false)
						end
					end
				else
					AddEvn(day, desc, event.color, false)
				end
			elseif event.year == Time.show.year then
				AddEvn(day, desc, event.color)
			end
		end
	end
end -- Events

function Draw() -- Sets all meter properties and calculates days
	local LastWeek = Set.HLWeek and math.ceil((Time.stats.startday + Time.stats.clength) / 7) < 6
	
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

	for meter = 1, Range.days do -- Calculate and set day meters
		local Styles, day, event, color = {Meters.Days.Styles.Normal}, Range.formula(meter)

		if meter == 1 then
			table.insert(Styles, Meters.Days.Styles.FirstDay)
		elseif (meter % 7) == 1 then
			table.insert(Styles, Meters.Days.Styles.NewWeek)
		end
		-- Holiday ToolTip and Style
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
		elseif (meter % 7) == 0 or (meter % 7) == (Set.SMon and 6 or 1) then
			table.insert(Styles, Meters.Days.Styles.Wknd)
		end
		
		for k, v in pairs{ -- Define meter properties
			Text = LZero(day),
			MeterStyle = table.concat(Styles, '|'),
			ToolTipText = event or '',
			[Set.Color] = color or '',
		} do SKIN:Bang('!SetOption', Meters.Days.Name:format(meter), k, v) end
	end
	
	for k, v in pairs{ -- Define skin variables
		ThisWeek = Range.week(),
		Week = rotate(Time.curr.wday - 1),
		Today = LZero(Time.curr.day),
		Month = MLabels[Time.show.month],
		Year = Time.show.year,
		MonthLabel = Vars(Set.LText, 'MonthLabel'),
		LastWkHidden = LastWeek and 1 or 0,
		NextEvent = Hol(),
	} do SKIN:Bang('!SetVariable', k, v) end
	-- Week Numbers for the current month
	local FirstWeek = os.time{day = (6 - Time.stats.startday), month = Time.show.month, year = Time.show.year}
	for i = 0, 5 do
		SKIN:Bang('!SetVariable', 'WeekNumber' .. (i + 1), math.ceil(tonumber(os.date('%j', (FirstWeek + (i * 604800)))) / 7))
	end
end -- Draw

function Move(value) -- Move calendar through the months
	if Range.nomove or not value then
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

function Easter() -- Returns a timestamp representing easter of the current year
	local a, b, c, h, L, m = (Time.show.year % 19), math.floor(Time.show.year / 100), (Time.show.year % 100), 0, 0, 0
	local d, e, f, i, k = math.floor(b/4), (b % 4), math.floor((b + 8) / 25), math.floor(c / 4), (c % 4)
	h = (19 * a + b - d - math.floor((b - f + 1) / 3) + 15) % 30
	L = (32 + 2 * e + 2 * i - h - k) % 7
	m = math.floor((a + 11 * h + 22 * L) / 451)
	
	return os.time{month = math.floor((h + L - 7 * m + 114) / 31), day = ((h + L - 7 * m + 114) % 31 + 1), year = Time.show.year}
end -- Easter

function Vars(line, source) -- Makes allowance for {Variables}
	local tbl = setmetatable({mname = MLabels[Time.show.month], year = Time.show.year, today = LZero(Time.curr.day), month = Time.show.month},
		{ __index = function(_, input)
			local D, W = {sun = 0, mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6}, {first = 0, second = 1, third = 2, fourth = 3, last = 4}
			local v1, v2 = input:match('(.+)(...)')
			if W[v1 or ''] and D[v2 or ''] then -- Variable day
				if v1 == 'last' then
					local L = 36 + D[v2] - Time.stats.startday
					return L - math.ceil((L - Time.stats.clength) / 7) * 7
				else
					return rotate(D[v2]) + 1 - Time.stats.startday + (Time.stats.startday > rotate(D[v2]) and 7 or 0) + 7 * W[v1]
				end
			else -- Error
				return ErrMsg(0, 'Invalid Variable {%s} in %s', input, source)
			end
		end})
	-- Built in Events
	local SetVar = function(name, timestamp)
		local temp = os.date('*t', timestamp)
		tbl[name:lower() .. 'month'] = temp.month
		tbl[name:lower() .. 'day'] = temp.day
	end
	
	local sEaster = Easter()
	local day = 86400
	SetVar('easter', sEaster)
	SetVar('goodfriday', sEaster - 2 * day)
	SetVar('ashwednesday', sEaster - 46 * day)
	SetVar('mardigras', sEaster - 47 * day)

	return line:gsub('{([^}]+)}', function(variable) return tbl[variable:gsub('%s', ''):lower()] end)
end -- Vars

function rotate(value) -- Makes allowance for StartOnMonday
	return Set.SMon and ((value - 1 + 7) % 7) or value
end -- rotate

function LZero(value) -- Makes allowance for LeadingZeros
	return Set.LZer and ('%02d'):format(value) or value
end -- LZero

function ErrMsg(...) -- Used to display errors
	local value = table.remove(arg, 1)
	rMessage = string.format(unpack(arg))
	print(Set.Name .. ': ' .. rMessage)
	return value
end -- ErrMsg

function CheckUpdate() -- Checks for an update to LuaCalendar
	local lVersion = 4.1 -- Current LuaCalendar Version
	local sVersion = tonumber(SKIN:GetMeasure('UpdateVersion'):GetStringValue():match('<version>(.+)</version>') or 0)
	if sVersion > lVersion then
		ErrMsg(nil, 'Update Available: v%s', sVersion)
	elseif lVersion > sVersion then
		rMessage = 'Thanks for testing the Beta version!'
	end
	SKIN:Bang('!DisableMeasure', 'UpdateVersion')
end -- CheckUpdate