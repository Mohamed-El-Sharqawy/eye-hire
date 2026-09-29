' Launches run-all.ps1 fully hidden (no console window).
' EDIT the two paths below to match your machine (pwsh.exe location and this folder).
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """C:\path\to\pwsh.exe"" -NoProfile -ExecutionPolicy Bypass -File ""C:\path\to\job-watcher\run-all.ps1""", 0, False
