All settings can be found in Settings.inc

========== Calendar Settings ==========
StartOnMonday
	Set to 1 to have the week start on Monday.

DayLabels
	A pipe delimited list of custom text for Weekday labels.
	Uses the following format: Sun|Mon|Tue|Wed|Thu|Fri|Sat
	NOTE: Do not adjust for StartOnMonday. This is done automatically.
	
MonthLabels
	A pipe delimited list of custom text for Month labels.
	Uses the following format: Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec

LabelText
	Allows for personalized formatting of the calendar title. The following variables may be used.
		!MName - The name of the current displayed month. If neither UseLocalMonths or MonthLabels is used, a number is returned.
		!Year - The year of the current displayed month.
		!Today - The current day number. Note that if LeadingZeroes is used, the number returned will be double digit.
		!Month - The number of the current displayed month.
	EXAMPLE: LabelText= !MName of !Year

LeadingZeroes
	Set to 1 to add a leading zero to any number below 10.
	
HideLastWeek
	Set to 1 to hide week 6 if not included in the current month.
	
UseLocalMonths
	Set to 1 to pull month names from the Localization Settings of your computer. Overrides Custom Month Labels.
	NOTE: This setting will affect all loaded skins that use the time measure. Use with caution.
	
HolidayFile
	A pipe delimited list of paths to Holiday files formatted as described below. These paths are relative to the skin folder unless a full path is specified.
	
DisableBuiltInEvents
	Set to 1 to disable Easter which is built into the script becasue of the need for complicated formulas.

========== Using Holiday Files ==========

To use Holiday Files set HolidayFile to the full path of a text file on the calendar measure.
	Example: HolidayFile=#CURRENTPATH#Holidays.hol
	
Multiple files can be aggregated together using a pipe delimiter.
	Example: HolidayFile=#CURRENTPATH#Holidays.hol|#CURRENTPATH#BDays.hol

The number of events in any month are only limited by the number days there are.

Two Holidays are hard coded into the script because of the need for formulas. These are Easter and Election Day. To disable these events, use DisableBuiltInEvents=1 on the calendar measure.

Events must to be listed in the following format:
	<Event Month="Month" Day="Day" Year="Year" Formula="1/0">Event Description</Event>
		NOTE: The quotes surrounding the parameters are required.
		
		The Year field is optional. Including it will cause the script to treat the event as an anniversary. Using a year in the future will display a negative number denoting how many years until that event occurs.
		
			Example: <Event Month="1" Day="4" Year="1986">Smurfier's BDay</event>
				Appears as: Smurfier's BDay (25)

		The Month field must be set to a number between 1 and 12. An asterisk (*) may be used to denote that the event occurs monthly.
		
		The Day field must be set to either a number, Formula, or a VariableDay.
			
			VariableDays are used to calculate holidays that occur on days like the Second Tuesday of the month. They are defined using the keywords and are surrounded by curly brackets.
				Starts with: First, Second, Third, Fourth, Last
				Ends with: Sun, Mon, Tue, Wed, Thu, Fri, Sat
			
				Example: <Event Month="11" Day="{FourthThu}">Thanksgiving Day</Event>
			
			Formulas are used to calculate some more complicated Holidays such as Election Day. The same !Variables may be used as with LabelText as well as VariableDays.
		
				Example: <Event Month="11" Day="({FirstMon}+1)*((!Year%2)=0)">Election Day</Event>
					Election day is defined as the Tuesday folllowing the First Monday in November ever even numbered Year.

========== Changelog ==========

2.0 (8/8/2011)-
	Fixed one line of code involving included variables.

2.1 (8/8/2011)-
	Fixed MonthLabels to use non-english characters.
	Added UseLocalMonths and HideLastWeek.

2.2 (8/13/2011)-
	Added the ability to retrieve and show multiple Google Calendar feeds.
	Added the ability to use multiple holiday files.
	Added option for anniversaries.
	Added option for WeekendColor.
	Made many code optimizations.

2.2.1 (8/14/2011)-
	Updated to fix error with dates in Holiday files.

2.2.2 (8/22/2011)-
	Fixed error with StartOnMonday where wrong day was indicated.
	Added calendar names to events.
	Added <Title></Title> to holiday files to comply with showing calendar names in events.
	Worked to fix problem with all day events with google calendar.
	Moved most calendar settings to Settings.inc and set rmskin to migrate settings on upgrade.

2.2.3 (1/15/2012)-
	Squashed a few bugs and made several code optimizations.

3.0 (1/21/2012)-
	Fixed the calculation used for Leap Years.
	Holiday files are now only loaded at startup.
	Removed support for Google Calendars. (It was messy and never really worked properly.)
	Removed the option to show only the current week.
	Made several code optimizations.
	Added LabelText for custom formatting of the Month Label.
	Added highlighting for the current weekday and the current day of the month.
	Added a different option for highlighting the current day.
	Added a new variable, LastWkHidden, which is set to 1 if the last week of the month is hidden.
	
3.0.1 (1/2/2012)-
	Fixed an error regarding StartOnMonday.
	Added %3 for current day with LabelText.
	
3.1 (2/5/2012)-
	Changed to use Style Sheets.
	Minor code optimizations.

3.1.1 (2/7/2012)-
	Fixed Bug regarding Holidays and StartOnMonday.

3.1.2 (2/24/2012)-
	Removed reference to non-existent variable.
	
3.1.3 (3/1/2012)-
	Minor code optimizations.
	Increased script readability.
	Fixed a bug regarding highlighted WeekDay and Current Day styles.
	Fixed a bug that prevented the calendar from switching to a new month.

3.2 (3/11/2012)-
	Minor code optimizations.
	Holiday File paths are now relative to the skins folder unless an absolute path is provided.
	Converted to use a different method of retrieving settings.
	Added support for formulas in Day parameter of Holidays.
	
3.2.1 (3/12/2012)
	Added support for VariableDays in Day Formulas.
	Removed Formula parameter in Holiday Files, now unnecessary.