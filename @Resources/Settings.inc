[Variables]
;Name of the Style Sheet
Style=Default

;===== Calendar functionality Options =====
;Uncomment the following settings to use.
[Lua]
;Custom text for Weekday labels. Uses the following format: Sun|Mon|Tue|Wed|Thu|Fri|Sat
;DayLabels=

;Set to 1 to disable Easter which is built into the script becasue of the need for complicated formulas.
;DisableBuiltInEvents=1

;Set to 1 to hide week 6 if not included in the current month
;HideLastWeek=1

;Holidays File names
;Note: For Holiday file names, multiple sources can be used by uisng the pipe delimiter (|).
EventFile=#@#Holidays\Holidays.hol

;Custom Text formatting for Month Labels. See Readme for details.
;LabelText=

;Set to 1 to add a leading zero to any number below 10.
;LeadingZeroes=1

;Custom text for Month labels. Uses the following format: Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec
;MonthLabels=

;Set to 1 to have the week start on Monday
;StartOnMonday=1

;Set to 1 to pull month names from the Localization Settings of your computer. Overrides Custom Month Labels.
UseLocalMonths=1

