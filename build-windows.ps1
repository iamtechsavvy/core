$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root 'dist'
$winDist = Join-Path $dist 'windows'
$releaseDir = Join-Path $root 'release-builds/windows'
$source = Join-Path $root 'src/windows'

New-Item -ItemType Directory -Path $winDist -Force | Out-Null
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$zipPath = Join-Path $winDist 'CORE-windows.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$releaseZipPath = Join-Path $releaseDir 'CORE-windows.zip'
if (Test-Path $releaseZipPath) { Remove-Item $releaseZipPath -Force }

Compress-Archive -Path "$source/*" -DestinationPath $zipPath
Copy-Item -Path $zipPath -Destination $releaseZipPath -Force
Write-Host "Created: $zipPath"
Write-Host "Published: $releaseZipPath"
