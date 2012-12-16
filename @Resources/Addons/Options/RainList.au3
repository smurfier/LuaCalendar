#NoTrayIcon
#include <Array.au3>
#include <File.au3>
#include <SendMessage.au3>

If $CmdLine[0]<2 Or Not ProcessExists("Rainmeter.exe") Then
	Exit
EndIf

If $CmdLine[0]=3 Then
	$ArrayType = $CmdLine[3]
Else
	$ArrayType = 0
EndIf

$Folders = _FileListToArray($CmdLine[1], "*", $ArrayType)
$Text = StringReplace($CmdLine[2], "$FileList$", _ArrayToString($Folders, "|", 1))
$Text = StringReplace($Text, "&quot;", Chr(34))
_SendBang($Text)

Func _SendBang($szBang)

   Local Const $hWnd = WinGetHandle("[CLASS:RainmeterMeterWindow]")

   If $hWnd <> 0 Then
      Local Const $iSize = StringLen($szBang) + 1

      Local Const $pMem = DllStructCreate("wchar[" & $iSize & "]")
      DllStructSetData($pMem, 1, $szBang)

      Local Const $pCds = DllStructCreate("dword;dword;ptr")
      DllStructSetData($pCds, 1, 1)
      DllStructSetData($pCds, 2, ($iSize * 2))
      DllStructSetData($pCds, 3, DllStructGetPtr($pMem))

      Local Const $WM_COPYDATA = 0x004A
      _SendMessage($hWnd, $WM_COPYDATA, 0, DllStructGetPtr($pCds))
  EndIf

EndFunc