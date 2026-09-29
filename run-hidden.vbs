Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.6.0_x64__8wekyb3d8bbwe\pwsh.exe"" -NoProfile -ExecutionPolicy Bypass -File ""D:\UPWORK\job-watcher\run-all.ps1""", 0, False
