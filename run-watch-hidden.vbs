' Runs run-watch.ps1 hidden (no window). Works from any clone location:
' resolves its own folder, so no hardcoded paths.
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "pwsh -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\run-watch.ps1""", 0, False
