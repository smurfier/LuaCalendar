[Rainmeter]
BackgroundMode=2
SolidColor=0,0,0,1
MouseOverAction=[!ToggleMeterGroup Controls][!Redraw]
MouseLeaveAction=[!ToggleMeterGroup Controls][!Redraw]

;Day Label Styles
[LblTxtSty]
H=#C.h#
W=#C.w#
X=#Space.X#R
Y=r
FontFace=Trebuchet MS
FontColor=255,255,255,150
FontSize=8
stringAlign=center
AntiAlias=1
Group=Controls

[LblTxtStart]
X=(#Bumper.x#+#C.w#/2)
Y=(#Bumper.top#+2)

[LblCurrSty]

;Main Calendar Styles
[TextStyle]
H=#C.h#
W=#C.w#
X=#Space.X#R
Y=r
FontColor=255,255,255,160
FontFace=Trebuchet MS
FontSize=10
stringAlign=center
AntiAlias=1

[FirstDay]
Y=(#Bumper.top#+#C.h#+#Space.y#)
X=(#Bumper.x#+#C.w#/2)

[NewWk]
Y=#Space.y#R
X=(#Bumper.x#+#C.w#/2)

[CurrentDay]
StringStyle=Bold

[LastWeek]
FontColor=0,0,0,0

[PreviousMonth]
FontColor=128,192,255,160

[NextMonth]
FontColor=128,192,255,160

[HolidayStyle]
FontColor=170,170,170,100

[WeekendStyle]

;========== METERS ==========
[mLabel]
Meter=String
Text=#MonthLabel#
W=(#C.w#*7+#Space.x#*6)
Y=(#C.h#*7+#Space.y#*6+#Bumper.top#)
H=0
FontColor=255,255,255,160
FontFace=Trebuchet MS
FontSize=10
stringAlign=Left
AntiAlias=1
Angle=-1.57
DynamicVariables=1

;Day Label BG
[lBG]
Meter=image
H=#C.h#
W=(#C.W#*7+#Space.x#*6)
SolidColor=255,255,255,25
X=#Bumper.x#
Y=#Bumper.top#

;Control Bar
[ControlForward]
Meter=String
MeterStyle=TextStyle
FontFace=Webdings
StringAlign=Left
Text="4"
Y=#Bumper.top#
X=((#C.w#*6+#Space.x#*6)+#Bumper.x#)
LeftMouseUpAction=[!CommandMeasure "Lua" "Move(1)"][!Update]
Group=Controls
Hidden=1

[ControlBack]
Meter=String
MeterStyle=TextStyle|ControlForward
Text="3"
X=#Bumper.x#
LeftMouseUpAction=[!CommandMeasure "Lua" "Move(-1)"][!Update]

[ControlHome]
Meter=String
MeterStyle=TextStyle|ControlForward
Text="="
X=R
LeftMouseUpAction=[!CommandMeasure "Lua" "Move()"][!Update]

;Date Indicator
[vLine1]
Meter=Image
SolidColor=#Clr.VLine#
W=#C.w#
H=((#C.h#+#Space.y#)*(#ThisWeek#-1)+#Space.y#)
Y=(#Bumper.top#+#C.h#)
X=(#Bumper.x#+(#C.w#+#Space.x#)*#Week#)
DynamicVariables=1
Hidden=#NotCurrentMonth#

[hLine]
Meter=Image
SolidColor=#Clr.HLine#
H=#C.h#
W=((#C.w#+#Space.x#)*6+#C.w#)
X=#Bumper.x#
Y=R
DynamicVariables=1
Hidden=#NotCurrentMonth#

[vLine2]
Meter=Image
MeterStyle=vLine1
H=((#C.h#+#Space.y#)*(6-#LastWkHidden#-#ThisWeek#))
Y=R

[Ghost]
Meter=Image
SolidColor=0,0,0,1
H=1
W=1
X=(#C.w#*7+#Space.x#*6+#Bumper.x#*2-1)
Y=(#Bumper.top#+#Bumper.bottom#+(#C.h#+#Space.y#)*7+#C.h#+1)
