$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/CoreConfig.ps1"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
public static class User32 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
}
"@

function Write-CoreLog {
    param([string]$Level, [string]$Event, [string]$Message, [hashtable]$Data)
    $config = Get-CoreConfig
    $entry = [ordered]@{
        ts      = (Get-Date).ToString('s')
        level   = $Level
        event   = $Event
        message = $Message
        data    = $Data
    } | ConvertTo-Json -Compress

    if ($Level -eq 'error') {
        Add-Content -Path $config.Paths.ErrorLog -Value $entry
    } elseif ($config.Debug -eq 1) {
        Add-Content -Path $config.Paths.DebugLog -Value $entry
    }
}

function Get-ReminderWindows {
    $procs = Get-Process OUTLOOK -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
    $wins = @()
    foreach ($p in $procs) {
        if ($p.MainWindowTitle -and $p.MainWindowTitle -match 'Reminder') {
            $wins += [PSCustomObject]@{
                Id    = "$($p.Id)-$($p.MainWindowHandle)"
                HWnd  = [IntPtr]$p.MainWindowHandle
                Title = $p.MainWindowTitle
            }
        }
    }
    return $wins
}

function Get-MinutesFromText {
    param([string]$Text)
    if ($Text -match '(?i)\bnow\b') { return 0 }
    if ($Text -match '(?i)\b(\d+)\s*min') { return [int]$matches[1] }
    return $null
}

function Center-Window {
    param([IntPtr]$HWnd)
    $rect = New-Object RECT
    [void][User32]::GetWindowRect($HWnd, [ref]$rect)

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    $screenW = [User32]::GetSystemMetrics(0)
    $screenH = [User32]::GetSystemMetrics(1)

    $x = [Math]::Floor(($screenW - $width) / 2)
    $y = [Math]::Floor(($screenH - $height) / 2)

    [void][User32]::SetWindowPos($HWnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001)
}

function Send-CoreNotification {
    param([string]$Title, [string]$Body)
    if (Get-Module -ListAvailable -Name BurntToast) {
        Import-Module BurntToast -ErrorAction SilentlyContinue
        New-BurntToastNotification -Text $Title, $Body | Out-Null
    } else {
        Write-Host "$Title - $Body"
    }
}

function Get-StateMap {
    $config = Get-CoreConfig
    if (Test-Path $config.Paths.StatePath) {
        return (Get-Content -Raw -Path $config.Paths.StatePath | ConvertFrom-Json -AsHashtable)
    }
    return @{}
}

function Save-StateMap {
    param([hashtable]$State)
    $config = Get-CoreConfig
    $State | ConvertTo-Json | Set-Content -Path $config.Paths.StatePath -Encoding UTF8
}

function Check-Imminent {
    $config = Get-CoreConfig
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $state = Get-StateMap

    $wins = Get-ReminderWindows
    foreach ($w in $wins) {
        $minutes = Get-MinutesFromText -Text $w.Title
        $imminent = $false

        if ($minutes -eq 0) {
            $imminent = $true
        } elseif ($null -ne $minutes -and $config.LeadTimeMinutes -gt 0 -and $minutes -le $config.LeadTimeMinutes) {
            $imminent = $true
        }

        if (-not $imminent) {
            Write-CoreLog -Level 'debug' -Event 'window_non_imminent' -Message 'Reminder not imminent' -Data @{ title = $w.Title }
            continue
        }

        Center-Window -HWnd $w.HWnd

        $last = 0
        if ($state.ContainsKey($w.Id)) { $last = [int64]$state[$w.Id] }
        if (($now - $last) -ge 300) {
            $state[$w.Id] = $now
            $subtitle = if ($config.LeadTimeMinutes -eq 0) { 'Meeting starting now' } else { "Meeting starts in $($config.LeadTimeMinutes) min or less" }
            Send-CoreNotification -Title 'CORE' -Body "$subtitle - $($w.Title)"
            Write-CoreLog -Level 'info' -Event 'window_centered' -Message 'Centered imminent reminder window' -Data @{ title = $w.Title; lead = $config.LeadTimeMinutes }
        }
    }

    Save-StateMap -State $state
}

$config = Get-CoreConfig
$errors = 0
Write-CoreLog -Level 'info' -Event 'daemon_start' -Message 'Windows runtime started' -Data @{ interval = $config.Interval; lead = $config.LeadTimeMinutes }

while ($true) {
    try {
        Check-Imminent
        $errors = 0
    } catch {
        $errors++
        Write-CoreLog -Level 'error' -Event 'runtime_error' -Message $_.Exception.Message -Data @{ errors = $errors }
        if ($errors -ge $config.MaxErrors) {
            Write-CoreLog -Level 'error' -Event 'runtime_exit' -Message 'Exiting after max errors' -Data @{ maxErrors = $config.MaxErrors }
            exit 1
        }
    }

    Start-Sleep -Seconds $config.Interval
}
