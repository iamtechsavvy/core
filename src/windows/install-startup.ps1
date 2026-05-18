$ErrorActionPreference = 'Stop'

$scriptPath = (Resolve-Path "$PSScriptRoot/outlook-reminder-center.ps1").Path
$startupDir = [Environment]::GetFolderPath('Startup')
$linkPath = Join-Path $startupDir 'CORE Reminder Center.lnk'

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($linkPath)
$shortcut.TargetPath = (Get-Command powershell.exe).Source
$shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.IconLocation = "$env:SystemRoot\System32\SHELL32.dll,44"
$shortcut.Save()

Write-Host "Startup shortcut installed: $linkPath"
