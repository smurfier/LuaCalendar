-- LuaCalendar v3.4 by Smurfier (smurfier20@gmail.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Set={ -- Retrieve Measure Settings
		DPref=SELF:GetOption('DayPrefix','l'),
		HLWeek=SELF:GetNumberOption('HideLastWeek',0)>0,
		LZer=SELF:GetNumberOption('LeadingZeroes',0)>0,
		MPref=SELF:GetOption('MeterPrefix','mDay'),
		SMon=SELF:GetNumberOption('StartOnMonday',0)>0,
		LText=SELF:GetOption('LabelText','{MName}, {Year}'),
		NFormat=SELF:GetOption('NextFormat','{day}: {desc}'),
	}
	Old={Day=0,Month=0,Year=0}
	StartDay,Month,Year,InMonth,Error=0,0,0,true,false -- Initialize Variables.
	cMonth={31,28,31,30,31,30,31,31,30,31,30,31} -- Length of the months.
--	========== Weekday labels text ==========
	local Labels=Delim(SELF:GetOption('DayLabels','S|M|T|W|T|F|S')) -- Separate DayLabels string.
	if #Labels<7 then -- Check for Error
		ErrMsg(0,'Invalid DayLabels string')
		Labels={'S','M','T','W','T','F','S'}
	end
	for a=1,7 do -- Set DayLabels text.
		SKIN:Bang('!SetOption',Set.DPref..a,'Text',Labels[Set.SMon and a%7+1 or a])
	end
--	========== Localization ==========
	MLabels=Delim(SELF:GetOption('MonthLabels','')) -- Pull custom month names.
	if SELF:GetNumberOption('UseLocalMonths',0)>0 then
		os.setlocale('','time') -- Set current locale.
		for a=1,12 do -- Pull each month name.
			MLabels[a]=os.date('%B',os.time{year=2000,month=a,day=1})
		end
	end
--	========== Holiday File ==========
	hFile={month={},day={},year={},desc={},title={},color={},} -- Initialize Event Matrix.
	for _,file in ipairs(Delim(SELF:GetOption('EventFile',''))) do -- For each event file.
		local In=io.input(SKIN:MakePathAbsolute(file),'r') -- Open file in read only.
		if not io.type(In)=='file' then -- File could not be opened.
			ErrMsg(0,'File Read Error',file)
		else -- File is open.
			local text=string.gsub(io.read('*all'),'<!%-%-.-%-%->','') -- Read in file contents and remove comments.
			io.close(In) -- Close the current file.
			if not string.match(string.lower(text),'<eventfile.->.-</eventfile>') then
				ErrMsg(0,'Invalid Event File',file)
			else
				local eFile,eSet={},{}
				local sw=switch{ -- Define Event File tags
					set=function(x) eSet=Keys(x[2]) end,
					['/set']=function(x) eSet={} end,
					eventfile=function(x) eFile=Keys(x[2]) end,
					['/eventfile']=function(x) eFile={} end,
					event=function(x)
						local match,ev=string.match(x[2],string.match(x[2],'/>') and '<(.-)/>' or '<(.-)>(.-)</')
						local Tmp=Keys(match,{desc=ev})
						for i,v in pairs(hFile) do table.insert(hFile[i],Tmp[i] or eSet[i] or eFile[i] or '') end
					end,
					default=function(x) ErrMsg(0,'Invalid Event Tag-',x[1]) end, -- Error
				}
				for line in string.gmatch(text,'[^\n\r\t]+') do -- For each file line, skipping tabs.
					sw:case(string.match(line,'^.-<([^%s>]+)'),line)
				end
			end
		end
	end
end -- Initialize

function Update()
	Time=os.date('*t') -- Retrieve date values.
	-- If in the current month or if browsing and Month changes to that month, set to Real Time.
	if (InMonth and Month~=Time.month) or ((not InMonth) and Month==Time.month and Year==Time.year) then
		Move()
	end
	if Month~=Old.Month or Year~=Old.Year then -- Recalculate and Redraw if Month and/or Year changes.
		Old={Month=Month,Year=Year,Day=Time.day}
		StartDay=rotate(tonumber(os.date('%w',os.time{year=Year,month=Month,day=1})))
		cMonth[2]=28+(((Year%4==0 and Year%100~=0) or Year%400==0) and 1 or 0) -- Check for Leap Year.
		Events()
		Draw()
	elseif Time.day~=Old.Day then -- Redraw if Today changes.
		Old.Day=Time.day
		Draw()
	end
	return Error and 'Error!' or 'Success!' -- Return a value to Rainmeter.
end -- Update

function Events() -- Parse Events table.
	Hol={} -- Initialize Event Table.
	local AddEvn=function(a,b,c) -- Adds new Events.
		c=string.match(c,',') and ConvertToHex(c) or c
		if Hol[a] then
			table.insert(Hol[a]['text'],b)
			table.insert(Hol[a]['color'],c)
		else
			Hol[a]={text={b},color={c},}
		end
	end
	local Test=function(c,d) return c=='' and '' or (d and d..c or nil) end
	for i=1,#hFile.month do -- For each event.
		if SKIN:ParseFormula(Vars(hFile.month[i]))==Month or hFile.month[i]=='*' then -- If Event exists in current month or *.
			AddEvn( -- Calculate Day and add to Event Table
				SKIN:ParseFormula(Vars(hFile.day[i],hFile.desc[i])) or ErrMsg(0,'Invalid Event Day',hFile.day[i],'in',hFile.desc[i]),
				hFile.desc[i]..(Test(hFile.year[i]) or ' ('..math.abs(Year-hFile.year[i])..')')..Test(hFile.title[i],' -'),
				hFile.color[i]
			)
		end
	end
end -- Events

function Draw() --Sets all meter properties and calculates days.
	local LastWeek=Set.HLWeek and (StartDay+cMonth[Month])/7<6 -- Check if Month is less than 6 weeks.
	for a=1,7 do --Set Weekday Labels styles.
		local Styles={'LblTxtSty'}
		if a==1 then table.insert(Styles,'LblTxtStart') end
		if rotate(Time.wday-1)==a-1 and InMonth then --If in current month, set Current Weekday style.
			table.insert(Styles,'LblCurrSty')
		end
		SKIN:Bang('!SetOption',Set.DPref..a,'MeterStyle',table.concat(Styles,'|'))
	end
	for a=1,42 do --Calculate and set day meters.
		local Par,Styles={a-StartDay, '', ''},{'TextStyle'} --Initialize variables.
		if a%7==1 then table.insert(Styles,a==1 and 'FirstDay' or 'NewWk') end --First Day and New Week
		if Par[1]>0 and Par[1]<=cMonth[Month] and Hol[Par[1]] then --Holiday ToolTip and Style
			Par[2]=table.concat(Hol[Par[1]]['text'],'\n')
			table.insert(Styles,'HolidayStyle')
			Par[3]=eColor(Hol[Par[1]]['color'])
		end
		if Time.day+StartDay==a and InMonth then --Current Day.
			table.insert(Styles,'CurrentDay')
		elseif a>35 and LastWeek then --Last week of the month.
			table.insert(Styles,'LastWeek')
		elseif Par[1]<1 then --Previous month.
			Par[1]=Par[1]+cMonth[Month==1 and 12 or Month-1]
			table.insert(Styles,'PreviousMonth')
		elseif Par[1]>cMonth[Month] then --Following month.
			Par[1]=Par[1]-cMonth[Month]
			table.insert(Styles,'NextMonth')
		elseif a%7==0 or a%7==(Set.SMon and 6 or 1) then --Weekends.
			table.insert(Styles,'WeekendStyle')
		end
		for k,v in pairs{ --Define meter properties.
			Text=LZero(Par[1]),
			MeterStyle=table.concat(Styles,'|'),
			ToolTipText=Par[2],
			FontColor=Par[3]
		} do SKIN:Bang('!SetOption',Set.MPref..a,k,v) end --Set meter properties.
	end
	for k,v in pairs{ --Define skin variables.
		ThisWeek=math.ceil((Time.day+StartDay)/7),
		Week=rotate(Time.wday-1),
		Today=LZero(Time.day),
		Month=MLabels[Month] or Month,
		Year=Year,
		MonthLabel=Vars(Set.LText,'MonthLabel'),
		LastWkHidden=LastWeek and 1 or 0,
		NextEvent=NextEvn(),
	} do SKIN:Bang('!SetVariable',k,v) end --Set skin variables.
end -- Draw

function eColor(tbl) -- Makes allowance for multiple custom colors.
	local a
	for k,v in ipairs(tbl) do if v=='' then table.remove(tbl,k) end end -- Remove Empty Colors
	for k,v in ipairs(tbl) do
		if a then
			if a~=v then
				return ''
			end
		else
			a=v
		end
	end
	return a
end -- eColor

function NextEvn() -- Returns a list of events
	local Evns={}
	for a=InMonth and Time.day or 1,cMonth[Month] do -- Parse through month days to keep days in order.
		if Hol[a] then
			local tbl={day=a,desc=table.concat(Hol[a]['text'],',')}
			local b=string.gsub(Set.NFormat,'(%b{})',function(c) -- Parse NextFormat variables
				return tbl[string.match(string.lower(c),'{(.+)}')] or ErrMsg('','Invalid NextFormat variable',c)
			end)
			table.insert(Evns,b)
		end
	end
	return table.concat(Evns,'\n')
end -- NextEvn

function Move(a) -- Move calendar through the months.
	local sw=switch{
		['1']=function() Month,Year=Month%12+1,Month==12 and Year+1 or Year end, -- Forward
		['-1']=function() Month,Year=Month==1 and 12 or Month-1,Month==1 and Year-1 or Year end, -- Back
		['0']=function() Month,Year=Time.month,Time.year end, -- Home
		default=function() ErrMsg(0,'Invalid Move parameter',a) end, -- Error
	}
	sw:case(tostring(a or 0))
	InMonth=Month==Time.month and Year==Time.year --Check if in the current month.
	SKIN:Bang('!SetVariable','NotCurrentMonth',InMonth and 0 or 1) --Set Skin Variable NotCurrentMonth
end -- Move

--===== These Functions are used to make life easier =====

function BuiltInEvents(a)
	tbl=a or {}
	local a,b,c,h,L,m=Year%19,math.floor(Year/100),Year%100,0,0,0
	local d,e,f,i,k=math.floor(b/4),b%4,math.floor((b+8)/25),math.floor(c/4),c%4
	h=(19*a+b-d-math.floor((b-f+1)/3)+15)%30
	L=(32+2*e+2*i-h-k)%7
	m=math.floor((a+11*h+22*L)/451)
	tbl['eastermonth']=math.floor((h+L-7*m+114)/31)
	tbl['easterday']=(h+L-7*m+114)%31+1
	tbl['goodfridaymonth']=(tbl.eastermonth-(tbl.easterday-2<1 and 1 or 0))
	tbl['goodfridayday']=(tbl.easterday-2)+(tbl.easterday-2<1 and cMonth[tbl.eastermonth-1] or 0)
	local atbl=os.date('*t',os.time{month=tbl.eastermonth,day=tbl.easterday,year=Year}-46*86400)
	tbl['ashwednesdaymonth']=atbl.month
	tbl['ashwednesdayday']=atbl.day
	return tbl
end

function Vars(a,source) -- Makes allowance for {Variables}
	local D,W={sun=0, mon=1, tue=2, wed=3, thu=4, fri=5, sat=6},{first=0, second=1, third=2, fourth=3, last=4}
	local tbl=BuiltInEvents{mname=MLabels[Month] or Month, year=Year, today=LZero(Time.day), month=Month}
	return string.gsub(a,'%b{}',function(b)
		local strip=string.match(string.lower(b),'{(.+)}')
		local v1,v2=string.match(strip,'(.+)(...)')
		if tbl[strip] then -- Regular variable.
			return tbl[strip]
		elseif W[v1 or 'nil'] and D[v2 or 'nil'] then -- Variable day.
			local L,wD=36+D[v2]-StartDay,rotate(D[v2])
			return W[v1]<4 and wD+1-StartDay+(StartDay>wD and 7 or 0)+7*W[v1] or L-math.ceil((L-cMonth[Month])/7)*7
		else -- Error
			return ErrMsg(0,'Invalid Variable',b,'in',source)
		end
	end)
end -- Vars

function rotate(a) -- Makes allowance for StartOnMonday.
	return Set.SMon and (a-1+7)%7 or a
end -- rotate

function LZero(a) -- Used to make allowance for LeadingZeros
	return Set.LZer and string.format('%02d',a) or a
end -- LZero

function Keys(a,b) -- Converts Key="Value" sets to a table
	local tbl=b or {}
	string.gsub(a,'(%a+)=(%b"")',function(c,d)
		local strip=string.match(d,'"(.+)"')
		tbl[string.lower(c)]=tonumber(strip) or strip
	end)
	return tbl
end -- Keys

function ErrMsg(...) -- Used to display errors
	Error=true
	print('LuaCalendar: '..table.concat(arg,' ',2))
	return arg[1]
end -- ErrMsg

function Delim(a) -- Separate String by Delimiter
	local tbl={}
	string.gsub(a,'[^%|]+', function(b) table.insert(tbl,b) end)
	return tbl
end -- Delim

function switch(tbl) -- Used to emulate a switch statement
	tbl.case=function(...)
		local t=table.remove(arg,1) -- Separate case table from arguments
		local f=t[string.lower(arg[1])] or t.default
		if f then
			if type(f)=='function' then
				f(arg)
			else
				print('Case: '..tostring(x)..' not a function')
			end
		end
	end
	return tbl
end -- switch

function ConvertToHex(a) -- Converts RGB colors to HEX
	local c={}
	a=string.gsub(a,'%s','') -- Remove spaces
	for b in string.gmatch(a,'[^,]+') do -- Separate by commas
		table.insert(c,string.format('%02X',tonumber(b))) -- Convert to double digit HEX
	end
	return table.concat(c) -- Concat into color code
end -- ConvertToHex