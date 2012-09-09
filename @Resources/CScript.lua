-- LuaCalendar v3.6 beta 2 by Smurfier (smurfier20@gmail.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Set={ -- Retrieve Measure Settings
		DPref = SELF:GetOption('DayPrefix', 'l'),
		HLWeek = SELF:GetNumberOption('HideLastWeek', 0) > 0,
		LZer = SELF:GetNumberOption('LeadingZeroes', 0) > 0,
		MPref = SELF:GetOption('MeterPrefix', 'mDay'),
		SMon = SELF:GetNumberOption('StartOnMonday', 0) > 0,
		LText = SELF:GetOption('LabelText', '{MName}, {Year}'),
		NFormat = SELF:GetOption('NextFormat', '{day}: {desc}'),
	}
	Old = {Day = 0, Month = 0, Year = 0}
	StartDay, Month, Year, InMonth, Error = 0, 0, 0, true, false
	cMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31} -- Length of the months.
	-- Weekday labels text
	local Labels = Delim('DayLabels', 'S|M|T|W|T|F|S')
	if #Labels < 7 then -- Check for Error
		ErrMsg(0, 'Invalid DayLabels string')
		Labels = {'S', 'M', 'T', 'W', 'T', 'F', 'S'}
	end
	for a = 1, 7 do
		SKIN:Bang('!SetOption', Set.DPref..a, 'Text', Labels[Set.SMon and (a % 7 + 1) or a])
	end
	-- Localization
	MLabels = Delim('MonthLabels')
	if SELF:GetNumberOption('UseLocalMonths', 0) > 0 then
		os.setlocale('', 'time')
		for a = 1, 12 do
			MLabels[a] = os.date('%B', os.time{year = 2000, month = a, day = 1})
		end
	end
	-- Holiday File
	hFile = {}
	for _,FileName in ipairs(Delim('EventFile')) do
		local File = io.open(SKIN:MakePathAbsolute(FileName), 'r')
		if not File then -- File could not be opened.
			ErrMsg(0, 'File Read Error', FileName)
		else -- File is open.
			local text = File:read('*all'):gsub('<!%-%-.-%-%->', '') -- Read in file contents and remove comments.
			File:close()
			if not text:lower():match('<eventfile.->.-</eventfile>') then
				ErrMsg(0, 'Invalid Event File', FileName)
			else
				local eFile, eSet = {}, {}
				local default = {month='', day='', year=false, descri='', title=false, color='', ['repeat']=false, multip=1, annive=0,}
				local sw = switch{ -- Define Event File tags
					set = function(x, y) table.insert(eSet, Keys(y)) end,
					['/set'] = function() table.remove(eSet, #eSet) end,
					eventfile = function(x,y) eFile = Keys(y) end,
					['/eventfile'] = function() eFile = {} end,
					event = function(x, y)
						local Tmp, dSet, tbl = Keys(y), ParseTbl(eSet), {}
						for k, v in pairs(default) do tbl[k] = Tmp[k] or dSet[k] or eFile[k] or v end
						table.insert(hFile, tbl)
					end,
					default = function(x) ErrMsg(0, 'Invalid Event Tag', x, 'in', FileName) end,
				}
				for tag in text:gmatch('%b<>') do
					sw:case(tag:match('^<([^%s>]+)'), tag)
				end
			end
		end
	end
end -- Initialize

function Update()
	Time = os.date('*t')
	
	-- If in the current month or if browsing and Month changes to that month, set to Real Time.
	if (InMonth and Month ~= Time.month) or ((not InMonth) and Month == Time.month and Year == Time.year) then
		Move()
	end
	
	if Month ~= Old.Month or Year ~= Old.Year then -- Recalculate and Redraw if Month and/or Year changes.
		Old = {Month=Month, Year=Year, Day=Time.day}
		StartDay = rotate(tonumber(os.date('%w', os.time{year=Year, month=Month, day=1})))
		cMonth[2] = 28 + ((((Year % 4) == 0 and (Year % 100) ~= 0) or (Year % 400) == 0) and 1 or 0) -- Check for Leap Year.
		Events()
		Draw()
	elseif Time.day ~= Old.Day then -- Redraw if Today changes.
		Old.Day = Time.day
		Draw()
	end
	
	return Error and 'Error!' or 'Success!'
end -- Update

function Events() -- Parse Events table.
	Hol={}
	local AddEvn = function(day, desc, color)
		if Hol[day] then
			table.insert(Hol[day]['text'], desc)
			table.insert(Hol[day]['color'], color)
		else
			Hol[day] = {text = {desc}, color = {color},}
		end
	end
	
	for _, event in ipairs(hFile) do
		local eMonth = SKIN:ParseFormula(Vars(event.month, event.descri))
		if  eMonth == Month or event['repeat'] then
			local day = SKIN:ParseFormula(Vars(event.day, event.descri)) or ErrMsg(0, 'Invalid Event Day', event.day, 'in', event.descri)
			local color = event.color:match(',') and ConvertToHex(event.color) or event.color
			local desc = table.concat{
				event.descri,
				(event.year and event.annive > 0) and ' ('..math.abs(Year - event.year)..')' or '',
				event.title and ' -'..event.title or '',
			}
			local rswitch = switch{
				week = function()
					if eMonth and event.year and day then
						local stamp = os.time{month=eMonth, day=day, year=event.year,}
						local test = os.time{month=Month, day=day, year=Year,} >= stamp
						local mstart = os.time{month=Month, day=1, year=Year,}
						local multi = event.multip * 604800
						local first = mstart + ((stamp - mstart) % multi)
						for a = 0, 4 do
							local temp = os.date('*t', first + a * multi)
							if temp.month == Month and test then
								AddEvn(temp.day, desc, color)
							end
						end
					end
				end,
				year = function()
					local test = (event.year and event.multip > 1) and ((Year - event.year) % event.multip) or 0
					if eMonth == Month and test == 0 then
						AddEvn(day, desc, color)
					end
				end,
				month = function()
					if eMonth and event.year then
						if Year>=event.year then
							local ydiff = Year - event.year
							local mdiff = ydiff == 0 and (Month - eMonth) or ((12 - eMonth) + Month + ydiff * 12)
							local estamp = os.time{year=event.year, month=eMonth, day=1,}
							local mstart = os.time{year=Year, month=Month, day=1,}

							if (mdiff % event.multip) == 0 and mstart >= estamp then
								AddEvn(day, desc, color)
							end
						end
					else
						AddEvn(day, desc, color)
					end
				end,
				default = function()
					if event.year == Year then
						AddEvn(day, desc, color)
					end
				end,
			}
			
			rswitch:case(event['repeat']:lower())
		end
	end
end -- Events

function Draw() -- Sets all meter properties and calculates days.
	local LastWeek = Set.HLWeek and math.ceil((StartDay + cMonth[Month]) / 7) < 6
	
	for wday = 1, 7 do -- Set Weekday Labels styles.
		local Styles = {'LblTxtSty'}
		if wday == 1 then
			table.insert(Styles, 'LblTxtStart')
		end
		if rotate(Time.wday - 1) == (wday - 1) and InMonth then
			table.insert(Styles, 'LblCurrSty')
		end
		SKIN:Bang('!SetOption', Set.DPref..wday, 'MeterStyle', table.concat(Styles, '|'))
	end
	
	for meter = 1, 42 do -- Calculate and set day meters.
		local day, event, color, Styles = (meter - StartDay), '', '', {'TextStyle'}
		if meter == 1 then
			table.insert(Styles, 'FirstDay')
		elseif (meter % 7) == 1 then
			table.insert(Styles, 'NewWk')
		end
		-- Holiday ToolTip and Style
		if day > 0 and day <= cMonth[Month] and Hol[day] then
			event = table.concat(Hol[day]['text'], '\n')
			table.insert(Styles, 'HolidayStyle')
			color = eColor(Hol[day]['color'])
		end
		
		if (Time.day + StartDay) == meter and InMonth then -- Current Day.
			table.insert(Styles, 'CurrentDay')
		elseif meter > 35 and LastWeek then -- Last week of the month.
			table.insert(Styles, 'LastWeek')
		elseif day < 1 then -- Previous month.
			day = day + cMonth[Month == 1 and 12 or (Month - 1)]
			table.insert(Styles, 'PreviousMonth')
		elseif day > cMonth[Month] then -- Following month.
			day = day - cMonth[Month]
			table.insert(Styles, 'NextMonth')
		elseif (meter % 7) == 0 or (meter % 7) == (Set.SMon and 6 or 1) then -- Weekends.
			table.insert(Styles, 'WeekendStyle')
		end
		
		for k,v in pairs{ -- Define meter properties.
			Text = LZero(day),
			MeterStyle = table.concat(Styles, '|'),
			ToolTipText = event,
			FontColor = color,
		} do SKIN:Bang('!SetOption', Set.MPref..meter, k, v) end
	end
	-- Define skin variables.
	for k,v in pairs{
		ThisWeek = math.ceil((Time.day + StartDay) / 7),
		Week = rotate(Time.wday - 1),
		Today = LZero(Time.day),
		Month = MLabels[Month] or Month,
		Year = Year,
		MonthLabel = Vars(Set.LText, 'MonthLabel'),
		LastWkHidden = LastWeek and 1 or 0,
		NextEvent = NextEvn(),
	} do SKIN:Bang('!SetVariable', k, v) end
end -- Draw

function eColor(tbl) -- Makes allowance for multiple custom colors.
	local color
	-- Remove Empty Colors
	for k,v in ipairs(tbl) do if v == '' then table.remove(tbl, k) end end
	
	for _,value in ipairs(tbl) do
		if color then
			if color ~= value then
				return ''
			end
		else
			color = value
		end
	end
	
	return color
end -- eColor

function NextEvn() -- Returns a list of events
	local Evns = {}
	
	for day = InMonth and Time.day or 1, cMonth[Month] do -- Parse through month days to keep days in order.
		if Hol[day] then
			local tbl = {day = day, desc = table.concat(Hol[day]['text'], ',')}
			local event = Set.NFormat:gsub('(%b{})', function(variable)
				return tbl[variable:lower():match('{(.+)}')] or ErrMsg('', 'Invalid NextFormat variable', variable)
			end)
			table.insert(Evns, event)
		end
	end
	
	return table.concat(Evns, '\n')
end -- NextEvn

function Move(value) -- Move calendar through the months.
	local sw = switch{
		['1'] = function() Month, Year = (Month % 12 + 1), Month == 12 and (Year + 1) or Year end, -- Forward
		['-1'] = function() Month, Year = Month == 1 and 12 or (Month - 1), Month == 1 and (Year - 1) or Year end, -- Back
		['0'] = function() Month, Year = Time.month, Time.year end, -- Home
		default = function() ErrMsg(0, 'Invalid Move parameter', value) end, -- Error
	}
	sw:case(tostring(value or 0))
	InMonth = Month == Time.month and Year == Time.year
	SKIN:Bang('!SetVariable', 'NotCurrentMonth', InMonth and 0 or 1)
end -- Move

--===== These Functions are used to make life easier =====

function Easter() -- Returns a timestamp representing easter of the current year.
	local a, b, c, h, L, m = (Year % 19), math.floor(Year / 100), (Year % 100), 0, 0, 0
	local d, e, f, i, k = math.floor(b/4), (b % 4), math.floor((b + 8) / 25), math.floor(c / 4), (c % 4)
	h = (19 * a + b - d - math.floor((b - f + 1) / 3) + 15) % 30
	L = (32 + 2 * e + 2 * i - h - k) % 7
	m = math.floor((a + 11 * h + 22 * L) / 451)
	
	return os.time{month=math.floor((h + L - 7 * m + 114) / 31), day=((h + L - 7 * m + 114) % 31 + 1), year=Year}
end -- Easter

function BuiltInEvents(default) -- Makes allowance for events that require calculation.
	local tbl = default or {}
	
	local SetVar = function(name,timestamp)
		tbl[name:lower()..'month'] = os.date('%m', timestamp)
		tbl[name:lower()..'day'] = os.date('%d', timestamp)
	end
	
	local sEaster = Easter()
	local day = 86400
	SetVar('easter', sEaster)
	SetVar('goodfriday', sEaster - 2 * day)
	SetVar('ashwednesday', sEaster - 46 * day)
	SetVar('mardigras', sEaster - 47 * day)
	
	return tbl
end -- BuiltInEvents

function Vars(line,source) -- Makes allowance for {Variables}
	local D, W = {sun=0, mon=1, tue=2, wed=3, thu=4, fri=5, sat=6}, {first=0, second=1, third=2, fourth=3, last=4}
	local tbl = BuiltInEvents{mname=MLabels[Month] or Month, year=Year, today=LZero(Time.day), month=Month}
	
	return tostring(line):gsub('%b{}', function(variable)
		local strip = variable:lower():match('{(.+)}')
		local v1, v2 = strip:match('(.+)(...)')
		if tbl[strip] then -- Regular variable.
			return tbl[strip]
		elseif W[v1 or ''] and D[v2 or ''] then -- Variable day.
			local L, wD = (36 + D[v2]-StartDay), rotate(D[v2])
			return W[v1] < 4 and (wD + 1 - StartDay + (StartDay > wD and 7 or 0) + 7 * W[v1]) or (L - math.ceil((L - cMonth[Month]) / 7) * 7)
		else -- Error
			return ErrMsg(0, 'Invalid Variable', variable, source and 'in '..source or '')
		end
	end)
end -- Vars

function rotate(value) -- Makes allowance for StartOnMonday.
	return Set.SMon and ((value - 1 + 7) % 7) or value
end -- rotate

function LZero(value) -- Used to make allowance for LeadingZeros
	return Set.LZer and string.format('%02d', value) or value
end -- LZero

function Keys(line,default) -- Converts Key="Value" sets to a table
	local tbl = default or {}
	local escape = {
		['&quot;']='"',
		['&lt;']='<',
		['&gt;']='>',
		['&amp;']='&',
	}
	
	for key, value in line:gmatch('(%a+)=(%b"")') do
		local strip = value:match('"(.+)"')
		for code,char in pairs(escape) do
			strip = string.gsub(strip or '', code, char)
		end
		tbl[key:sub(1, 6):lower()] = tonumber(strip) or strip
	end
	
	return tbl
end -- Keys

function ErrMsg(...) -- Used to display errors
	Error = true
	print('LuaCalendar: '..table.concat(arg, ' ', 2))
	return arg[1]
end -- ErrMsg

function Delim(option, default) -- Separate String by Delimiter
	local value, tbl = SELF:GetOption(option, default), {}
	for word in value:gmatch('[^%|]+') do table.insert(tbl, word) end
	return tbl
end -- Delim

function switch(tbl) -- Used to emulate a switch statement
	tbl.case = function(...)
		local t = table.remove(arg, 1) -- Separate case table from arguments
		local f = t[arg[1]:lower()] or t.default
		if f then
			if type(f) == 'function' then
				f(unpack(arg))
			else
				print('Case: '..tostring(arg[1])..' not a function')
			end
		end
	end
	
	return tbl
end -- switch

function ConvertToHex(color) -- Converts RGB colors to HEX
	local hex = {}
	
	for rgb in color:gmatch('%d+') do
		table.insert(hex, string.format('%02X', tonumber(rgb)))
	end
	
	return table.concat(hex)
end -- ConvertToHex

function ParseTbl(input) -- Compresses matrix into a single table.
	local tbl = {}
	
	for _, column in ipairs(input) do
		for key, value in pairs(column) do
			tbl[key] = value
		end
	end
	
	return tbl
end -- ParseTbl