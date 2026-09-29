$dir = $PSScriptRoot
Start-Process pwsh -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$dir\run-watch.ps1" -WindowStyle Hidden -Wait
Start-Process pwsh -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$dir\run-apply.ps1" -WindowStyle Hidden -Wait
