-- LuaCalendar v3.6 beta 1 by Smurfier (smurfier20@gmail.com)
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
	StartDay,Month,Year,InMonth,Error = 0,0,0,true,false
	cMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31} -- Length of the months.
	-- Weekday labels text
	local Labels = Delim(SELF:GetOption('DayLabels', 'S|M|T|W|T|F|S'))
	if #Labels < 7 then -- Check for Error
		ErrMsg(0,'Invalid DayLabels string')
		Labels = {'S', 'M', 'T', 'W', 'T', 'F', 'S'}
	end
	for a = 1, 7 do
		SKIN:Bang('!SetOption', Set.DPref..a, 'Text', Labels[Set.SMon and a%7+1 or a])
	end
	-- Localization
	MLabels = Delim(SELF:GetOption('MonthLabels'))
	if SELF:GetNumberOption('UseLocalMonths', 0) > 0 then
		os.setlocale('', 'time')
		for a = 1, 12 do
			MLabels[a] = os.date('%B', os.time{year = 2000, month = a, day = 1})
		end
	end
	-- Holiday File
	hFile = {month={}, day={}, year={}, descri={}, title={}, color={}, ['repeat']={}, multip={}, annive={},}
	for _,FileName in ipairs(Delim(SELF:GetOption('EventFile'))) do
		local File=io.input(SKIN:MakePathAbsolute(FileName), 'r')
		if not io.type(File)=='file' then -- File could not be opened.
			ErrMsg(0,'File Read Error',FileName)
		else -- File is open.
			local text = string.gsub(io.read('*all'), '<!%-%-.-%-%->', '') -- Read in file contents and remove comments.
			io.close(File)
			if not string.match(string.lower(text), '<eventfile.->.-</eventfile>') then
				ErrMsg(0,'Invalid Event File',FileName)
			else
				local eFile,eSet = {},{}
				local sw = switch{ -- Define Event File tags
					set = function(x) table.insert(eSet, Keys(x[2])) end,
					['/set'] = function(x) table.remove(eSet, #eSet) end,
					eventfile = function(x) eFile = Keys(x[2]) end,
					['/eventfile'] = function(x) eFile = {} end,
					event = function(x)
						local Tmp = Keys(x[2])
						local dSet = ParseTbl(eSet)
						for i,v in pairs(hFile) do table.insert(hFile[i], Tmp[i] or dSet[i] or eFile[i] or '') end
					end,
					default = function(x) ErrMsg(0,'Invalid Event Tag',x[1],'in',FileName) end,
				}
				for tag in string.gmatch(text, '%b<>') do
					sw:case(string.match(tag, '^<([^%s>]+)'), tag)
				end
			end
		end
	end
end -- Initialize

function Update()
	Time=os.date('*t')
	
	-- If in the current month or if browsing and Month changes to that month, set to Real Time.
	if (InMonth and Month ~= Time.month) or ((not InMonth) and Month == Time.month and Year == Time.year) then
		Move()
	end
	
	if Month ~= Old.Month or Year ~= Old.Year then -- Recalculate and Redraw if Month and/or Year changes.
		Old = {Month=Month, Year=Year, Day=Time.day}
		StartDay = rotate(tonumber(os.date('%w',os.time{year=Year,month=Month,day=1})))
		cMonth[2] = 28+(((Year%4 == 0 and Year%100 ~= 0) or Year%400 == 0) and 1 or 0) -- Check for Leap Year.
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
	local AddEvn = function(day, event, color)
		if Hol[day] then
			table.insert(Hol[day]['text'], event)
			table.insert(Hol[day]['color'], color)
		else
			Hol[day] = {text = {event}, color = {color},}
		end
	end
	
	for i=1, #hFile.month do
		local eMonth = SKIN:ParseFormula(Vars(hFile.month[i], hFile.descri[i]))
		if  eMonth == Month or hFile['repeat'][i] ~= '' then
			local day = SKIN:ParseFormula(Vars(hFile.day[i], hFile.descri[i])) or ErrMsg(0,'Invalid Event Day',hFile.day[i],'in',hFile.descri[i])
			local color = string.match(hFile.color[i], ',') and ConvertToHex(hFile.color[i]) or hFile.color[i]
			local event = table.concat{
				hFile.descri[i],
				(hFile.year[i]~='' and hFile.annive==1) and ' ('..math.abs(Year-hFile.year[i])..')' or '',
				hFile.title[i]=='' and '' or ' -'..hFile.title[i],
			}
			local multip=hFile.multip[i]~='' and hFile.multip[i] or 1
			local rswitch = switch{
				week = function()
					local stamp = os.time{month=hFile.month[i], day=hFile.day[i], year=hFile.year[i],}
					local mstart = os.time{month=Month, day=1, year=Year,}
					local multi = multip * 604800
					local first = mstart+((stamp-mstart)%multi)
					for a=0,4 do
						local rstamp = first+a*multi
						if tonumber(os.date('%m', rstamp)) == Month then
							AddEvn(tonumber(os.date('%d', rstamp)), event, color)
						end
					end
				end,
				year = function()
					local test = (hFile.year[i] ~= '' and hFile.multip[i] ~= '') and (Year-hFile.year[i])%multip or 0
					if eMonth == Month and test == 0 then
						AddEvn(day, event, color)
					end
				end,
				month = function()
					if hFile.month[i]~='' and hFile.year[i]~='' then
						if Year>=hFile.year[i] then
							local ydiff = Year-hFile.year[i]
							if ydiff == 0 then
								mdiff = Month-hFile.month[i]
							else
								mdiff = (12-hFile.month[i])+Month+ydiff*12
							end
							local estamp = os.time{year=hFile.year[i], month=hFile.month[i], day=1,}
							local mstart = os.time{year=Year,month=Month, day=1,}
							if mdiff%multip == 0 and mstart >= estamp then
								AddEvn(day, event, color)
							end
						end
					else
						AddEvn(day, event, color)
					end
				end,
				default = function()
					if hFile.year[i] == Year then
						AddEvn(day, event, color)
					end
				end,
			}
			
			rswitch:case(string.lower(hFile['repeat'][i]))
		end
	end
end -- Events

function Draw() -- Sets all meter properties and calculates days.
	local LastWeek = Set.HLWeek and (StartDay+cMonth[Month])/7 < 6
	
	for wday = 1, 7 do -- Set Weekday Labels styles.
		local Styles = {'LblTxtSty'}
		if wday == 1 then
			table.insert(Styles, 'LblTxtStart')
		end
		if rotate(Time.wday-1) == wday-1 and InMonth then
			table.insert(Styles, 'LblCurrSty')
		end
		SKIN:Bang('!SetOption', Set.DPref..wday, 'MeterStyle', table.concat(Styles, '|'))
	end
	
	for meter = 1, 42 do -- Calculate and set day meters.
		local day, event, color, Styles = meter-StartDay, '', '', {'TextStyle'}
		if meter%7 == 1 then -- First Day and New Week
			table.insert(Styles, meter == 1 and 'FirstDay' or 'NewWk')
		end
		-- Holiday ToolTip and Style
		if day > 0 and day <= cMonth[Month] and Hol[day] then
			event = table.concat(Hol[day]['text'], '\n')
			table.insert(Styles, 'HolidayStyle')
			color = eColor(Hol[day]['color'])
		end
		
		if Time.day+StartDay == meter and InMonth then -- Current Day.
			table.insert(Styles, 'CurrentDay')
		elseif meter > 35 and LastWeek then -- Last week of the month.
			table.insert(Styles, 'LastWeek')
		elseif day < 1 then -- Previous month.
			day = day+cMonth[Month == 1 and 12 or Month-1]
			table.insert(Styles, 'PreviousMonth')
		elseif day > cMonth[Month] then -- Following month.
			day = day-cMonth[Month]
			table.insert(Styles, 'NextMonth')
		elseif meter%7 == 0 or meter%7 == (Set.SMon and 6 or 1) then -- Weekends.
			table.insert(Styles, 'WeekendStyle')
		end
		
		for k,v in pairs{ -- Define meter properties.
			Text = LZero(day),
			MeterStyle = table.concat(Styles, '|'),
			ToolTipText = event,
			FontColor = color
		} do SKIN:Bang('!SetOption', Set.MPref..meter, k, v) end
	end
	-- Define skin variables.
	for k,v in pairs{
		ThisWeek = math.ceil((Time.day+StartDay)/7),
		Week = rotate(Time.wday-1),
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
		if Hol[a] then
			local tbl = {day = day, desc = table.concat(Hol[a]['text'], ',')}
			local event = string.gsub(Set.NFormat, '(%b{})', function(variable)
				return tbl[string.match(string.lower(variable), '{(.+)}')] or ErrMsg('','Invalid NextFormat variable',variable)
			end)
			table.insert(Evns, event)
		end
	end
	
	return table.concat(Evns, '\n')
end -- NextEvn

function Move(value) -- Move calendar through the months.
	local sw = switch{
		['1'] = function() Month, Year = Month%12+1, Month == 12 and Year+1 or Year end, -- Forward
		['-1'] = function() Month, Year = Month == 1 and 12 or Month-1, Month == 1 and Year-1 or Year end, -- Back
		['0'] = function() Month, Year = Time.month, Time.year end, -- Home
		default = function() ErrMsg(0,'Invalid Move parameter',a) end, -- Error
	}
	sw:case(tostring(value or 0))
	InMonth = Month == Time.month and Year == Time.year
	SKIN:Bang('!SetVariable', 'NotCurrentMonth', InMonth and 0 or 1)
end -- Move

--===== These Functions are used to make life easier =====

function Easter() -- Returns a timestamp representing easter of the current year.
	local a,b,c,h,L,m = Year%19,math.floor(Year/100),Year%100,0,0,0
	local d,e,f,i,k = math.floor(b/4),b%4,math.floor((b+8)/25),math.floor(c/4),c%4
	h = (19*a+b-d-math.floor((b-f+1)/3)+15)%30
	L = (32+2*e+2*i-h-k)%7
	m = math.floor((a+11*h+22*L)/451)
	
	return os.time{month=math.floor((h+L-7*m+114)/31),day=(h+L-7*m+114)%31+1,year=Year}
end -- Easter

function BuiltInEvents(default) -- Makes allowance for events that require calculation.
	local tbl = default or {}
	
	local SetVar = function(name,timestamp)
		tbl[string.lower(name)..'month'] = os.date('%m',timestamp)
		tbl[string.lower(name)..'day'] = os.date('%d',timestamp)
	end
	
	local sEaster = Easter()
	local day = 86400
	SetVar('easter', sEaster)
	SetVar('goodfriday', sEaster-2*day)
	SetVar('ashwednesday', sEaster-46*day)
	SetVar('mardigras', sEaster-47*day)
	
	return tbl
end -- BuiltInEvents

function Vars(line,source) -- Makes allowance for {Variables}
	local D,W={sun=0, mon=1, tue=2, wed=3, thu=4, fri=5, sat=6},{first=0, second=1, third=2, fourth=3, last=4}
	local tbl=BuiltInEvents{mname=MLabels[Month] or Month, year=Year, today=LZero(Time.day), month=Month}
	
	return string.gsub(line, '%b{}', function(variable)
		local strip = string.match(string.lower(variable),'{(.+)}')
		local v1,v2 = string.match(strip,'(.+)(...)')
		if tbl[strip] then -- Regular variable.
			return tbl[strip]
		elseif W[v1 or 'nil'] and D[v2 or 'nil'] then -- Variable day.
			local L, wD = 36+D[v2]-StartDay, rotate(D[v2])
			return W[v1]<4 and wD+1-StartDay+(StartDay>wD and 7 or 0)+7*W[v1] or L-math.ceil((L-cMonth[Month])/7)*7
		else -- Error
			return ErrMsg(0,'Invalid Variable',variable,source and 'in '..source or '')
		end
	end)
end -- Vars

function rotate(value) -- Makes allowance for StartOnMonday.
	return Set.SMon and (value-1+7)%7 or value
end -- rotate

function LZero(value) -- Used to make allowance for LeadingZeros
	return Set.LZer and string.format('%02d',value) or value
end -- LZero

function Keys(line,default) -- Converts Key="Value" sets to a table
	local tbl = default or {}
	local escape = {
		['&quot;']='"',
		['&lt;']='<',
		['&gt;']='>',
		['&amp;']='&'
	}
	
	for key, value in string.gmatch(line, '(%a+)=(%b"")') do
		local strip = string.match(value, '"(.+)"')
		for code,char in pairs(escape) do
			strip=string.gsub(strip or '',code,char)
		end
		tbl[string.lower(string.sub(key,1,6))] = tonumber(strip) or strip
	end
	
	return tbl
end -- Keys

function ErrMsg(...) -- Used to display errors
	Error=true
	print('LuaCalendar: '..table.concat(arg,' ',2))
	return arg[1]
end -- ErrMsg

function Delim(line) -- Separate String by Delimiter
	local tbl={}
	for word in string.gmatch(line, '[^%|]+') do table.insert(tbl, word) end
	return tbl
end -- Delim

function switch(tbl) -- Used to emulate a switch statement
	tbl.case=function(...)
		local t = table.remove(arg,1) -- Separate case table from arguments
		local f = t[string.lower(arg[1])] or t.default
		if f then
			if type(f) == 'function' then
				f(arg)
			else
				print('Case: '..tostring(x)..' not a function')
			end
		end
	end
	
	return tbl
end -- switch

function ConvertToHex(color) -- Converts RGB colors to HEX
	local hex = {}
	
	for rgb in string.gmatch(color, '%d+') do
		table.insert(hex, string.format('%02X',tonumber(rgb)))
	end
	
	return table.concat(hex)
end -- ConvertToHex

function ParseTbl(input) -- Compresses matrix into a single table.
	local tbl = {}
	
	for _,column in ipairs(input) do
		for key,value in pairs(column) do
			tbl[key] = value
		end
	end
	
	return tbl
end -- ParseTbl