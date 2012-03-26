-- LuaCalendar v3.2 by Smurfier (smurfier20@gmail.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Set={ -- Retrieve Measure Settings
		DPrefix=SELF:GetOption('DayPrefix','l'),
		HLWeek=GetBool('HideLastWeek'),
		LZer=GetBool('LeadingZeroes'),
		MPref=SELF:GetOption('MeterPrefix','mDay'),
		SMon=GetBool('StartOnMonday'),
	}
	OldDay,OldMonth,OldYear,StartDay,Month,Year,InMonth=0,0,0,0,0,0,1 -- Initialize Variables.
	cMonth={31,28,31,30,31,30,31,31,30,31,30,31} -- Length of the months.
--	========== Weekday labels text ==========
	local Labels={} -- Initialize Labels table in local context.
	for a in string.gmatch(SELF:GetOption('DayLabels','S|M|T|W|T|F|S'),'[^%|]+') do -- Separate DayLabels by Delimiter.
		table.insert(Labels,a)
	end
	for a=1,#Labels do -- Set DayLabels text.
		SetOption(Set.DPrefix..a,'Text',Labels[Set.SMon and a%#Labels+1 or a])
	end
--	========== Localization ==========
	MLabels={}
	if GetBool('UseLocalMonths') then
		os.setlocale('','time') -- Set current locale. This affects all skins and scripts.
		for a=1,12 do -- Pull each month name.
			table.insert(MLabels,os.date('%B',os.time({year=2000,month=a,day=1})))
		end
	else
		for a in string.gmatch(SELF:GetOption('MonthLabels',''),'[^%|]+') do -- Pull custom month names.
			table.insert(MLabels,a)
		end
		for a=#MLabels+1,12 do -- Make sure there are 12 months.
			table.insert(MLabels,a)
		end
	end
--	========== Holiday File ==========
	hFile={} -- Initialize Main Holiday table.
	for i,v in ipairs({'month','day','year','event','title'}) do hFile[v]={} end -- Turn Holiday Table into a Matrix.
	local Num=0 -- Used to track Matrix rows.
	for file in string.gmatch(SELF:GetOption('HolidayFile',''),'[^%|]+') do -- For each holiday file.
		local In=io.input(SKIN:MakePathAbsolute(file),'r') -- Open file in read only.
		if In then -- If file is open.
			local Title=''
			for line in io.lines() do -- For each file line.
				if string.match(string.lower(line),'<title>.+</title>') then
					Title=' -'..string.match(line,'<.->(.+)</.->') -- Set Title.
				elseif string.match(string.lower(line),'<event.+>.+</') then
					Num=Num+1
					local match,event=string.match(line,'<(.+)>(.-)</')
					for a,b in string.gmatch(match,'(%a+)=(%b"")') do
						hFile[string.lower(a)][Num]=string.match(b,'"(.+)"')
					end
					hFile.event[Num]=event or ''
					hFile.title[Num]=Title
				end
			end
		else -- File could not be opened.
			print('File Read Error: '..file)
		end
		io.close(In) -- Close the current file.
	end	
end -- function Initialize

function Update()
	Time=os.date('*t') -- Retrieve date values.
	if InMonth==1 and Month~=Time.month then  -- If in the current month, set to Real Time.
		Month,Year=Time.month,Time.year
	elseif InMonth==0 and Month==Time.month and Year==Time.year then -- If browsing and Month changes to that month, set to Real Time.
		Home()
	end
	if Month~=OldMonth or Year~=OldYear then -- Recalculate and Redraw if Month and/or Year changes.
		OldMonth,OldYear,OldDay=Month,Year,Time.day
		StartDay=rotate(os.date('%w',os.time({year=Year,month=Month,day=1})))
		cMonth[2]=28+tobool((Year%4==0 and Year%100~=0) or Year%400==0) -- Check for Leap Year.
		-- Set LastWkHidden skin variable.
		SetVariable('LastWkHidden',tobool(Set.HLWeek and math.ceil((StartDay+cMonth[Month])/7)<6))
		Holidays()
		Draw()
	elseif Time.day~=OldDay then --Redraw if Today changes.
		OldDay=Time.day
		Draw()
	end
	return 'Success!' --Return a value to Rainmeter.
end -- function Update

function Holidays() -- Parse Holidays table.
	Hol={} -- Initialize Holiday Table.
	if not GetBool('DisableBuiltInEvents') then BuiltIn() end -- Add built in events.
	for i=1,#hFile.month do -- For each holiday in the main table.
		local Dy=0 -- Reset Dy to zero just to be sure.
		if tonumber(hFile.month[i])==Month or hFile.month[i]=='*' then -- If Holiday exists in current month or *.
			Dy=SKIN:ParseFormula(Vars(hFile.day[i])) -- Calculate Day.
			local An=tonumber(hFile.year[i]) and ' ('..(Year-tonumber(hFile.year[i]))..')' or '' -- Calculate Anniversary.
			Hol[Dy]=(Hol[Dy] and Hol[Dy]..'\n' or '')..hFile.event[i]..An..hFile.title[i] -- Add to Holiday Table.
		end
	end
end -- function Holidays

function Draw() --Sets all meter properties and calculates days.
	for a=1,7 do --Set Weekday Labels styles.
		local Styles={'LblTxtSty'}
		if a==1 then table.insert(Styles,'LblTxtStart') end
		if rotate(Time.wday-1)==a-1 and InMonth==1 then --If in current month and year, set Current Weekday style.
			table.insert(Styles,'LblCurrSty')
		end
		SetOption(Set.DPrefix..a,'MeterStyle',table.concat(Styles,'|'))
	end
	for a=1,42 do --Calculate and set day meters.
		local Par,Styles={a-StartDay, ''},{'TextStyle'} --Reinitialize variables.
		if a%7==1 then table.insert(Styles,a==1 and 'FirstDay' or 'NewWk') end --First Day and New Week
		if Par[1]>0 and Par[1]<=cMonth[Month] and Hol[Par[1]] then --Holiday ToolTip and Style
			Par[2]=Hol[Par[1]]
			table.insert(Styles,'HolidayStyle')
		end
		if Time.day+StartDay==a and InMonth==1 then --If in current month and year, set Current Day Style.
			table.insert(Styles,'CurrentDay')
		elseif a>35 and math.ceil((StartDay+cMonth[Month])/7)<6 and Set.HLWeek then --LastWeek of the month.
			table.insert(Styles,'LastWeek')
		elseif Par[1]<1 then --Days in the previous month.
			Par[1]=Par[1]+cMonth[Month==1 and 12 or Month-1]
			table.insert(Styles,'PreviousMonth')
		elseif Par[1]>cMonth[Month] then --Days in the following month.
			Par[1]=Par[1]-cMonth[Month]
			table.insert(Styles,'NextMonth')
		elseif a%7==0 or a%7==(Set.SMon and 6 or 1) then --Weekends in the current month.
			table.insert(Styles,'WeekendStyle')
		end
		local tbl={ --Use this table to define meter properties.
			Text=LZero(Par[1]);
			MeterStyle=table.concat(Styles,'|');
			ToolTipText=Par[2];
		}
		for i,v in pairs(tbl) do SetOption(Set.MPref..a,i,v) end -- Read tbl and sets meter properties.
	end
	local var={ --Use this table to define skin variables.
		ThisWeek=math.ceil((Time.day+StartDay)/7);
		Week=rotate(Time.wday-1);
		Today=LZero(Time.day);
		Month=MLabels[Month];
		Year=Year;
		MonthLabel=Vars(SELF:GetOption('LabelText','{MName}, {Year}'));
	}
	for i,v in pairs(var) do SetVariable(i,v) end --Read var and sets skin variables.
end -- function Draw

function Forward() --Advance Calendar by one month.
	Month,Year=Month%12+1,Month==12 and Year+1 or Year
	InMonth=tobool(Month==Time.month and Year==Time.year) --Check if in the current month.
	SetVariable('NotCurrentMonth',1-InMonth) --Set Skin Variable NotCurrentMonth
end -- function Forward

function Back() --Regress Calendar by one month.
	Month,Year=Month==1 and 12 or Month-1,Month==1 and Year-1 or Year
	InMonth=tobool(Month==Time.month and Year==Time.year) --Check if in the current month.
	SetVariable('NotCurrentMonth',1-InMonth) --Set Skin Variable NotCurrentMonth
end -- function Back

function Home() --Returns Calendar to current month.
	Month,Year,InMonth=Time.month,Time.year,1
	SetVariable('NotCurrentMonth',0)
end -- function Home

--===== These Functions are used to make life easier =====

function BuiltIn() -- Calculates Easter and Good Friday.
	local a,b,c,g,h,L,m=Year%19,math.floor(Year/100),Year%100,0,0,0,0
	local d,e,f,i,k=math.floor(b/4),b%4,math.floor((b+8)/25),math.floor(c/4),c%4
	g=math.floor((b-f+1)/3)
	h=(19*a+b-d-g+15)%30
	L=(32+2*e+2*i-h-k)%7
	m=math.floor((a+11*h+22*L)/451)
	local EM,ED=math.floor((h+L-7*m+114)/31),(h+L-7*m+114)%31+1
	local GF=(ED-2)+(ED-2<1 and cMonth[EM-1] or 0)
	if Month==EM then Hol[ED]='Easter' end
	if Month==(EM-tobool(ED-2<1)) then Hol[GF]='Good Friday' end
end -- function BuiltIn

function Vars(a) -- Makes allowance for {Variables}
	local D,W={sun=0, mon=1, tue=2, wed=3, thu=4, fri=5, sat=6},{first=0, second=1, third=2, fourth=3, last=4}
	local tbl={mname=MLabels[Month], year=Year, today=LZero(Time.day), month=Month}
	for b in string.gmatch(a,'%b{}') do
		local strip=string.match(string.lower(b),'{(.+)}')
		if tbl[strip] then -- Regular variable.
			a=string.gsub(a,b,tbl[strip])
		elseif D[string.match(strip,'.+(...)')] and W[string.match(strip,'(.+)...')] then -- Variable day.
			local v1,v2=string.match(strip,'(.+)(...)')
			local L,wD=36+D[v2]-StartDay,rotate(D[v2])
			local num=W[v1]<4 and wD+1-StartDay+(StartDay>wD and 7 or 0)+7*W[v1] or L-math.ceil((L-cMonth[Month])/7)*7
			a=string.gsub(a,b,num)
		else -- Error
			print('LuaCalendar- Invalid Variable: '..b)
			a=string.gsub(a,b,0) -- Substitute with 0 to avoid formula error.
		end
	end
	return a
end -- function Vars

function rotate(a) -- Used to make allowance for StartOnMonday.
	a=tonumber(a) or 0
	return Set.SMon and (a-1+7)%7 or a
end -- function rotate

function SetVariable(a,b) -- Used to easily set Skin Variables
	SKIN:Bang('!SetVariable '..a..' """'..b..'"""')
end -- function SetVariable

function SetOption(a,b,c) -- Used to easily set Meter/Measure Options
	SKIN:Bang('!SetOption "'..a..'" "'..b..'" """'..c..'"""')
end -- function SetOption

function LZero(a) -- Used to make allowance for LeadingZeros
	return Set.LZer and string.format('%02d',a) or a
end -- function LZero

function GetBool(a,b) -- Used to retrieve Boolean measure options
	return SELF:GetNumberOption(a,b or 0)>0
end -- function GetBool

function tobool(a) -- Converts Boolean to number value
	return a and 1 or 0
end -- function tobool