function Easter()
	local a, b, c, h, L, m = (Time.show.year % 19), math.floor(Time.show.year / 100), (Time.show.year % 100), 0, 0, 0
	local d, e, f, i, k = math.floor(b/4), (b % 4), math.floor((b + 8) / 25), math.floor(c / 4), (c % 4)
	h = (19 * a + b - d - math.floor((b - f + 1) / 3) + 15) % 30
	L = (32 + 2 * e + 2 * i - h - k) % 7
	m = math.floor((a + 11 * h + 22 * L) / 451)
	
	return os.time{
		month = math.floor((h + L - 7 * m + 114) / 31),
		day = ((h + L - 7 * m + 114) % 31 + 1),
		year = Time.show.year,
	}
end -- Easter

-- Function provided by Mordasius, tweaked by Smurfier
function GetPhaseNumber(year, month, day)
	local fixangle = function(a) return a % 360 end
	local eccent = 0.016718 -- Eccentricity of Earth's orbit
	
	-- Convert Gregorian Date into Julian Date
	local gregorian = year >= 1583
	if month == 1 or month == 2 then
		year, month = (year - 1), (month + 12)
	end
	local a = math.floor(year / 100)
	local b = gregorian and (2 - a + math.floor(a / 4)) or 0
	local Jday = math.floor(365.25 * (year + 4716)) + math.floor(30.6001 * (month + 1)) + day + b - 1524
	
	local Day, M, Ec, Lambdasun, ml, Ev, Ae, MM, MmP, mEc, lP
	Day = Jday - 2444238.5 -- Date within epoch
	
	-- (360 / 365.2422) == 0.98564733209908
	M = math.rad(fixangle(fixangle(0.98564733209908 * Day) - 3.762863)) -- Convert from perigee co-ordinates to epoch 1980.0
	
	-- Solve Kepler equation
	local e, delta = M, - eccent * math.sin(M)
	while math.abs(delta) > 1E-6 do
		delta = e - eccent * math.sin(e) - M
		e = e - delta / (1 - eccent * math.cos(e))
	end
	
	-- math.sqrt((1 + eccent) / (1 - eccent)) == 1.0168601118216
	Ec = 2 * math.deg(math.atan(1.0168601118216 * math.tan(e / 2))) -- True anomaly
	
	Lambdasun = fixangle(Ec + 282.596403) -- Sun's geocentric ecliptic Longitude
	ml = fixangle(13.1763966 * Day + 64.975464) -- Moon's mean Longitude
	MM = fixangle(ml - 0.1114041 * Day - 348.383063) -- Moon's mean anomaly
	Ev = 1.2739 * math.sin(math.rad(2 * (ml - Lambdasun) - MM)) -- Evection
	Ae = 0.1858 * math.sin(M) -- Annual equation
	MmP = math.rad(MM + Ev - Ae - (0.37 * math.sin(M))) -- Corrected anomaly
	mEc = 6.2886 * math.sin(MmP) -- Correction for the equation of the centre
	lP = ml + Ev + mEc - Ae + (0.214 * math.sin(2 * MmP)) -- Corrected Longitude
	local PhaseNum = fixangle((lP + (0.6583 * math.sin(math.rad(2 * (lP - Lambdasun))))) - Lambdasun)
	
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
end  -- GetPhaseNumber