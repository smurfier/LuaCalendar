function Initialize()
	SetParse(SELF:GetOption('StartColor'))
	Draw()
end -- Initialize

function SetParse(input)
	local temp = {}
	if input:match(',') then
		for rgb in input:gmatch('[^,]+') do
			rgb = tonumber(rgb)
			if rgb then
				table.insert(temp, minmax(rgb, 0, 255))
			else
				print('Invalid color code.')
				temp = {}
				break
			end
		end
	else
		for hex in input:gmatch('%S%S') do
			hex = tonumber(hex, 16)
			if hex then
				table.insert(temp, minmax(hex, 0, 255))
			else
				print('Invalid color code.')
				temp = {}
				break
			end
		end
	end
	Hue, Sat, Lig = HSL(temp[1] or 255, temp[2] or 255, temp[3] or 255)
	Alpha = (temp[4] or 255) / 255
end -- SetParse

function SetHue(num)
	Hue = minmax(num / 100, 0, 1)
	Sat = 1
	Lig = 0.5
	Draw()
end -- SetHue

function SetSat(num)
	Sat = minmax(num / 100, 0, 1)
	Lig = 0.5
	Draw()
end -- SetSat

function SetLig(num)
	Lig = minmax(num / 100, 0, 1)
	Draw()
end -- SetLig

function SetAlpha(num)
	Alpha = minmax(num / 100, 0, 1)
	Draw()
end -- SetAlpha

function SetRGB(Red, Green, Blue)
	Hue, Sat, Lig = HSL(minmax(Red, 0, 255), minmax(Green, 0, 255), minmax(Blue, 0, 255))
	Draw()
end -- SetRGBA

function Draw()
	local Red, Green, Blue = RGB(Hue, Sat, Lig)
	local Avalue = Round(Alpha * 255)
	for k, v in pairs{
		RGB = Concat(',', Red, Green, Blue),
		HEX = string.format('%02X%02X%02X%02X', Red, Green, Blue, Avalue),
		Hue = Hue,
		Sat = Sat,
		Lig = Lig,
		APercent = Alpha,
		Red = Red,
		Green = Green,
		Blue = Blue,
		Alpha = Avalue,
		SatColor = Concat(',', RGB(Hue, 1, 0.5)),
		LightColor = Concat(',', RGB(Hue, Sat, 0.5)),
	} do SKIN:Bang('!SetVariable', k , v) end
end -- Draw

function Round(num, idp)
	return tonumber(('%.' .. (ipd or 0) .. 'f'):format(num))
end -- Round

function Concat(...)
	return table.concat(arg, table.remove(arg, 1))
end -- Concat

function minmax(num, min, max)
	if num < min then
		return min
	elseif num > max then
		return max
	else
		return num
	end
end -- minmax

-- Formulas from http://www.easyrgb.com
function RGB(H, S, L)
	-- HSL from 0 to 1
	-- RGB results from 0 to 255
	local Hue2RGB = function(v1, v2, vH)
		if vH < 0 then vH = vH + 1 end
		if vH > 1 then vH = vH - 1 end
		if (6 * vH) < 1 then
			return v1 + (v2 - v1) * 6 * vH
		elseif (2 * vH) < 1 then
			return v2
		elseif (3 * vH) < 2 then
			return v1 + (v2 - v1) * ((2 / 3) - vH) * 6 
		else
			return v1
		end
	end

	if S == 0 then
		return Round(L * 255), Round(L * 255), Round(L * 255)
	else
		local var2 = L < 0.5 and L * (1 + S) or (L + S) - (S * L)
		local var1 = 2 * L - var2

		return Round(255 * Hue2RGB(var1, var2, H + (1 / 3))), Round(255 * Hue2RGB(var1, var2, H)), Round(255 * Hue2RGB(var1, var2, H - (1 / 3)))
	end
end -- RGB

function HSL(R, G, B)
	-- RGB from 0 to 255
	-- HSL results from 0 to 1
	local H, S, L
	local varR, varG, varB = R / 255, G / 255, B / 255

	varMin = math.min(varR, varG, varB) -- Min. value of RGB
	varMax = math.max(varR, varG, varB) -- Max. value of RGB
	delMax = varMax - varMin -- Delta RGB value

	L = (varMax + varMin) / 2

	if delMax == 0 then -- This is a gray, no chroma...
		H, S = 0, 0
	else -- Chromatic data...
		S = L < 0.5 and delMax / (varMax + varMin) or delMax / (2 - varMax - varMin)

		local delR = (((varMax - varR) / 6) + (delMax / 2)) / delMax
		local delG = (((varMax - varG ) / 6) + (delMax / 2)) / delMax
		local delB = (((varMax - varB) / 6) + (delMax / 2)) / delMax

		if varR == varMax then
	   		H = delB - delG
		elseif varG == varMax then
			H = (1 / 3) + delR - delB
		elseif varB == varMax then
			H = (2 / 3) + delG - delR
		end

		if H < 0 then H = H + 1 end
		if H > 1 then H = H - 1 end
	end
	return H, S, L
end -- HSL