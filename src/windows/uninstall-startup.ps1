$ErrorActionPreference = 'Stop'

$startupDir = [Environment]::GetFolderPath('Startup')
$linkPath = Join-Path $startupDir 'CORE Reminder Center.lnk'

if (Test-Path $linkPath) {
    Remove-Item -Path $linkPath -Force
    Write-Host "Removed startup shortcut: $linkPath"
} else {
    Write-Host "Startup shortcut not found."
}
