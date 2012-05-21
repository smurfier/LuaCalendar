[Rainmeter]
BackgroundMode=2
SolidColor=0,0,0,1
MouseOverAction=[!ToggleMeterGroup Controls][!Redraw]
MouseLeaveAction=[!ToggleMeterGroup Controls][!Redraw]

[BackgroundStyle]
H=170
W=#cWidth#
SolidColor=0,0,0,1

;Day Label Styles
[LblTxtSty]
X=#SpacingX#r
Y=20
FontFace=Trebuchet MS
FontColor=255,255,255
FontSize=8
stringAlign=center
AntiAlias=1
Group=Controls

[LblTxtStart]
X=(#FirstX#-10)

[LblCurrSty]

;Main Calendar Styles
[TextStyle]
X=#SpacingX#r
Y=r
FontColor=255,255,255
FontFace=Trebuchet MS
FontSize=8
stringAlign=Right
AntiAlias=1

[FirstDay]
Y=#FirstY#
X=#FirstX#

[NewWk]
Y=#SpacingY#r
X=38

[CurrentDay]
StringStyle=Bold

[LastWeek]
FontColor=0,0,0,0

[PreviousMonth]
FontColor=255,255,255,108

[NextMonth]
FontColor=255,255,255,108

[HolidayStyle]
FontColor=#Clr.Hrl#

[WeekendStyle]

;========== METERS ==========
[TopBorder]
Meter=Image
SolidColor=#Clr.Brd#
X=10
Y=5
W=(#cWidth#-20)
H=1
Hidden=#HideBordersTop#

[BorderBottom]
Meter=IMAGE
SolidColor=#Clr.Brd#
X=10
Y=165
W=(#cWidth#-20)
H=1
Hidden=#HideBordersBottom#

[mLabel]
Meter=String
Text=#MonthLabel#
W=(112+#SpacingX#*6)
X=(#FirstX#+FLOOR(#SpacingX#)*3-8)
Y=18
FontColor=255,255,255,160
FontFace=Trebuchet MS
FontSize=10
stringAlign=Center
AntiAlias=1
Group=Controls
Hidden=1
DynamicVariables=1

;Day Label BG
[LblBgSty]
X=#SpacingX#r
Y=18
H=16
W=16
SolidColor=255,255,255,25
Group=Controls

[lSunBG]
Meter=image
MeterStyle=LblBgSty
X=(#FirstX#-18)

[lMonBG]
Meter=image
MeterStyle=LblBgSty

[lTuesBG]
Meter=image
MeterStyle=LblBgSty

[lWedBG]
Meter=image
MeterStyle=LblBgSty

[lThurBG]
Meter=image
MeterStyle=LblBgSty

[lFriBG]
Meter=image
MeterStyle=LblBgSty

[lSatBG]
Meter=image
MeterStyle=LblBgSty

;Control Bar
[ControlForward]
Meter=String
MeterStyle=TextStyle
FontFace=Webdings
StringAlign=Left
Text="4"
Y=18
X=(#SpacingX#*6+(#FirstX#-18)-8)
LeftMouseUpAction=[!CommandMeasure "Lua" "Move(1)"][!Update]
Group=Controls
Hidden=1

[ControlBack]
Meter=String
MeterStyle=TextStyle|ControlForward
Text="3"
X=(#FirstX#-18)
LeftMouseUpAction=[!CommandMeasure "Lua" "Move(-1)"][!Update]

[ControlHome]
Meter=String
MeterStyle=TextStyle|ControlForward
Text="="
X=R
LeftMouseUpAction=[!CommandMeasure "Lua" "Move()"][!Update]

;Date Indicator
[TodayHL]
Meter=image
X=(#FirstX#+#Week#*FLOOR(#SpacingX#))
Y=(#FirstY#+#SpacingY#*(#ThisWeek#-1))
H=12
W=2
SolidColor=#Clr.Hrl#
Hidden=#NotCurrentMonth#
DynamicVariables=1