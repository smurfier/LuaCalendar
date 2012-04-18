-- LuaCalendar v3.3 by Smurfier (smurfier20@gmail.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Set={ -- Retrieve Measure Settings
		DPrefix=SELF:GetOption('DayPrefix','l'),
		HLWeek=SELF:GetNumberOption('HideLastWeek',0)>0,
		LZer=SELF:GetNumberOption('LeadingZeroes',0)>0,
		MPref=SELF:GetOption('MeterPrefix','mDay'),
		SMon=SELF:GetNumberOption('StartOnMonday',0)>0,
		LText=SELF:GetOption('LabelText','{MName}, {Year}'),
	}
	Old={Day=0,Month=0,Year=0}
	StartDay,Month,Year,InMonth,Error=0,0,0,1,false -- Initialize Variables.
	cMonth={31,28,31,30,31,30,31,31,30,31,30,31} -- Length of the months.
--	========== Weekday labels text ==========
	local Labels={} -- Initialize Labels table in local context.
	-- Separate DayLabels by Delimiter.
	string.gsub(SELF:GetOption('DayLabels','S|M|T|W|T|F|S'),'[^%|]+', function(a) table.insert(Labels,a) end)
	if #Labels<7 then -- Check for Error
		ErrMsg('Invalid DayLabels string')
	else
		for a=1,7 do -- Set DayLabels text.
			SetOption(Set.DPrefix..a,'Text',Labels[Set.SMon and a%#Labels+1 or a])
		end
	end
--	========== Localization ==========
	MLabels={}
	if SELF:GetNumberOption('UseLocalMonths',0)>0 then
		os.setlocale('','time') -- Set current locale. This affects all skins and scripts.
		for a=1,12 do -- Pull each month name.
			table.insert(MLabels,os.date('%B',os.time({year=2000,month=a,day=1})))
		end
	else -- Pull custom month names.
		string.gsub(SELF:GetOption('MonthLabels',''),'[^%|]+', function(a) table.insert(MLabels,a) end)
	end
--	========== Holiday File ==========
	hFile={} -- Initialize Main Event table.
	for i,v in ipairs({'month','day','year','event','title'}) do hFile[v]={} end -- Turn Event Table into a Matrix.
	local sw=switch{ -- Defines Event File tags
		set=function(x) eSet=Keys(x) end,
		['/set']=function(x) eSet={} end,
		eventfile=function(x) eFile=Keys(x) end,
		['/eventfile']=function(x) eFile={} end,
		event=function(x) local match,ev=string.match(x,'<(.+)>(.-)</') local Tmp=Keys(match,{event=ev;})
			for i,v in pairs(hFile) do table.insert(hFile[i],Tmp[i] or (eSet[i] or (eFile[i] or ''))) end end,
		default=function(x,y) ErrMsg('Invalid Event Tag- '..y) end,
	}
	for file in string.gmatch(SELF:GetOption('EventFile',''),'[^%|]+') do -- For each event file.
		local In=io.input(SKIN:MakePathAbsolute(file),'r') -- Open file in read only.
		if not io.type(In)=='file' then -- File could not be opened.
			ErrMsg('File Read Error '..file)
		else -- File is open.
			local text=string.gsub(io.read('*all'),'<!%-%-.-%-%->','') -- Read in file contents and remove comments.
			io.close(In) -- Close the current file.
			if not string.match(string.lower(text),'<eventfile.->.-</eventfile>') then
				ErrMsg('Invalid Event File '..file)
			else
				local eFile,eSet={},{}
				for line in string.gmatch(text,'[^\n]+') do -- For each file line.
					local tag=string.match(line,'^.-<([^%s>]+)')
					sw:case(string.lower(tag),line,tag)
				end
			end
		end
	end
	Update()
end -- Initialize

function Update()
	Time=os.date('*t') -- Retrieve date values.
	if InMonth==1 and Month~=Time.month then  -- If in the current month, set to Real Time.
		Month,Year=Time.month,Time.year
	elseif InMonth==0 and Month==Time.month and Year==Time.year then -- If browsing and Month changes to that month, set to Real Time.
		Home()
	end
	if Month~=Old.Month or Year~=Old.Year then -- Recalculate and Redraw if Month and/or Year changes.
		Old.Month,Old.Year,Old.Day=Month,Year,Time.day
		StartDay=rotate(os.date('%w',os.time({year=Year,month=Month,day=1})))
		cMonth[2]=28+(((Year%4==0 and Year%100~=0) or Year%400==0) and 1 or 0) -- Check for Leap Year.
		Events()
		Draw()
	elseif Time.day~=Old.Day then --Redraw if Today changes.
		Old.Day=Time.day
		Draw()
	end
	return Error and 'Error!' or 'Success!' --Return a value to Rainmeter.
end -- Update

function Events() -- Parse Events table.
	Hol={} -- Initialize Holiday Table.
	if not (SELF:GetNumberOption('DisableBuiltInEvents',0)>0) then -- Add Easter and Good Friday
		local a,b,c,g,h,L,m=Year%19,math.floor(Year/100),Year%100,0,0,0,0
		local d,e,f,i,k=math.floor(b/4),b%4,math.floor((b+8)/25),math.floor(c/4),c%4
		g=math.floor((b-f+1)/3)
		h=(19*a+b-d-g+15)%30
		L=(32+2*e+2*i-h-k)%7
		m=math.floor((a+11*h+22*L)/451)
		local EM,ED=math.floor((h+L-7*m+114)/31),(h+L-7*m+114)%31+1
		if Month==EM then Hol[ED]='Easter' end
		if Month==(EM-(ED-2<1 and 1 or 0)) then Hol[(ED-2)+(ED-2<1 and cMonth[EM-1] or 0)]='Good Friday' end
	end
	for i=1,#hFile.month do -- For each holiday in the main table.
		local Dy=0 -- Set Dy to zero just to be sure.
		if tonumber(hFile.month[i])==Month or hFile.month[i]=='*' then -- If Holiday exists in current month or *.
			Dy=SKIN:ParseFormula(Vars(hFile.day[i])) -- Calculate Day.
			if not Dy then -- Error Checking
				ErrMsg('Invalid Event Day '..hFile.day[i])
			else -- Add to Holiday Table.
				local An=tonumber(hFile.year[i]) and ' ('..math.abs(Year-tonumber(hFile.year[i]))..')' or '' -- Calculate Anniversary.
				Hol[Dy]=(Hol[Dy] and Hol[Dy]..'\n' or '')..hFile.event[i]..An..(hFile.title[i]=='' and '' or ' -'..hFile.title[i])
			end
		end
	end
end -- Events

function Draw() --Sets all meter properties and calculates days.
	local LastWeek=Set.HLWeek and math.ceil((StartDay+cMonth[Month])/7)<6 -- Check if Month is less than 6 weeks.
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
		elseif a>35 and LastWeek then --LastWeek of the month.
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
			Text=LZero(Par[1]),
			MeterStyle=table.concat(Styles,'|'),
			ToolTipText=Par[2],
		}
		for i,v in pairs(tbl) do SetOption(Set.MPref..a,i,v) end -- Read tbl and sets meter properties.
	end
	local var={ --Use this table to define skin variables.
		ThisWeek=math.ceil((Time.day+StartDay)/7),
		Week=rotate(Time.wday-1),
		Today=LZero(Time.day),
		Month=MLabels[Month] or Month,
		Year=Year,
		MonthLabel=Vars(Set.LText),
		LastWkHidden=LastWeek and 1 or 0,
	}
	for i,v in pairs(var) do SetVariable(i,v) end --Read var and sets skin variables.
end -- Draw

function Forward() -- Advance Calendar by one month.
	Month,Year=Month%12+1,Month==12 and Year+1 or Year
	InMonth=(Month==Time.month and Year==Time.year) and 1 or 0 --Check if in the current month.
	SetVariable('NotCurrentMonth',1-InMonth) --Set Skin Variable NotCurrentMonth
end -- Forward

function Back() -- Regress Calendar by one month.
	Month,Year=Month==1 and 12 or Month-1,Month==1 and Year-1 or Year
	InMonth=(Month==Time.month and Year==Time.year) and 1 or 0 --Check if in the current month.
	SetVariable('NotCurrentMonth',1-InMonth) --Set Skin Variable NotCurrentMonth
end -- Back

function Home() -- Returns Calendar to current month.
	Month,Year,InMonth=Time.month,Time.year,1
	SetVariable('NotCurrentMonth',0)
end -- Home

--===== These Functions are used to make life easier =====

function Vars(a) -- Makes allowance for {Variables}
	local D,W={sun=0, mon=1, tue=2, wed=3, thu=4, fri=5, sat=6},{first=0, second=1, third=2, fourth=3, last=4}
	local tbl={mname=MLabels[Month] or Month, year=Year, today=LZero(Time.day), month=Month}
	for b in string.gmatch(a,'%b{}') do
		local strip,c=string.match(string.lower(b),'{(.+)}'),nil
		local v1,v2=string.match(strip,'(.+)(...)')
		if tbl[strip] then -- Regular variable.
			c=tbl[strip]
		elseif W[v1] and D[v2] then -- Variable day.
			local L,wD=36+D[v2]-StartDay,rotate(D[v2])
			c=W[v1]<4 and wD+1-StartDay+(StartDay>wD and 7 or 0)+7*W[v1] or L-math.ceil((L-cMonth[Month])/7)*7
		else -- Error
			ErrMsg('Invalid Variable '..b)
		end
		a=string.gsub(a,b,c or 0)
	end
	return a
end -- Vars

function rotate(a) -- Used to make allowance for StartOnMonday.
	a=tonumber(a) or 0
	return Set.SMon and (a-1+7)%7 or a
end -- rotate

function SetVariable(a,b) -- Used to easily set Skin Variables
	SKIN:Bang('!SetVariable '..a..' """'..b..'"""')
end -- SetVariable

function SetOption(a,b,c) -- Used to easily set Meter/Measure Options
	SKIN:Bang('!SetOption "'..a..'" "'..b..'" """'..c..'"""')
end -- SetOption

function LZero(a) -- Used to make allowance for LeadingZeros
	return Set.LZer and string.format('%02d',a) or a
end -- LZero

function Keys(a,b) -- Converts Key="Value" sets to a table
	local tbl=b or {}
	for c,d in string.gmatch(a,'(%a+)=(%b"")') do
		tbl[string.lower(c)]=string.match(d,'"(.+)"')
	end
	return tbl
end -- Keys

function ErrMsg(a) -- Used to display errors
	Error=true
	print('LuaCalendar: '..a)
end -- ErrMsg

function switch(t)
	t.case=function(self,x,y,z)
		local f=self[x] or self.default
		if f then
			if type(f)=="function" then
				f(y,z)
			else
				print("case "..tostring(x).." not a function")
			end
		end
	end
	return t
end