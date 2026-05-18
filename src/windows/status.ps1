$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/CoreConfig.ps1"

$config = Get-CoreConfig
$scriptPath = (Resolve-Path "$PSScriptRoot/outlook-reminder-center.ps1").Path.Replace('\\','\\\\')

$procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine -match [Regex]::Escape($scriptPath) }

$running = $procs.Count -gt 0

Write-Host "=== CORE Windows Status ==="
Write-Host "Running: $running"
Write-Host "Interval: $($config.Interval)s"
Write-Host "Lead Time: $($config.LeadTimeMinutes)m"
Write-Host "Debug: $($config.Debug)"
Write-Host "Log Dir: $($config.Paths.LogDir)"
if (Test-Path $config.Paths.ErrorLog) {
    Write-Host "Recent Errors:" 
    Get-Content -Path $config.Paths.ErrorLog -Tail 10
}
