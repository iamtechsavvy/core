$ErrorActionPreference = 'Stop'

function Assert-InRange {
    param(
        [int]$Value,
        [int]$Min,
        [int]$Max,
        [string]$Name
    )
    if ($Value -lt $Min -or $Value -gt $Max) {
        throw "$Name must be between $Min and $Max. Got: $Value"
    }
}

function Get-CorePaths {
    $root = Join-Path $env:APPDATA 'CORE'
    $logDir = Join-Path $root 'logs'
    $stateDir = Join-Path $root 'state'
    $configPath = Join-Path $root 'config.json'

    New-Item -Path $root -ItemType Directory -Force | Out-Null
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    New-Item -Path $stateDir -ItemType Directory -Force | Out-Null

    [PSCustomObject]@{
        Root       = $root
        LogDir     = $logDir
        StateDir   = $stateDir
        ConfigPath = $configPath
        DebugLog   = Join-Path $logDir 'debug.log'
        ErrorLog   = Join-Path $logDir 'error.log'
        StatePath  = Join-Path $stateDir 'window-state.json'
    }
}

function Get-CoreDefaults {
    [PSCustomObject]@{
        Interval        = 10
        LeadTimeMinutes = 2
        Debug           = 0
        MaxErrors       = 10
    }
}

function Get-CoreConfig {
    $paths = Get-CorePaths
    $defaults = Get-CoreDefaults

    $config = [PSCustomObject]@{
        Interval        = $defaults.Interval
        LeadTimeMinutes = $defaults.LeadTimeMinutes
        Debug           = $defaults.Debug
        MaxErrors       = $defaults.MaxErrors
    }

    if (Test-Path $paths.ConfigPath) {
        $raw = Get-Content -Raw -Path $paths.ConfigPath | ConvertFrom-Json
        if ($null -ne $raw.Interval) { $config.Interval = [int]$raw.Interval }
        if ($null -ne $raw.LeadTimeMinutes) { $config.LeadTimeMinutes = [int]$raw.LeadTimeMinutes }
        if ($null -ne $raw.Debug) { $config.Debug = [int]$raw.Debug }
        if ($null -ne $raw.MaxErrors) { $config.MaxErrors = [int]$raw.MaxErrors }
    }

    if ($env:OUTLOOK_CHECK_INTERVAL) { $config.Interval = [int]$env:OUTLOOK_CHECK_INTERVAL }
    if ($env:OUTLOOK_IMMINENT_MINUTES) { $config.LeadTimeMinutes = [int]$env:OUTLOOK_IMMINENT_MINUTES }
    if ($env:OUTLOOK_DEBUG) { $config.Debug = [int]$env:OUTLOOK_DEBUG }
    if ($env:OUTLOOK_MAX_ERRORS) { $config.MaxErrors = [int]$env:OUTLOOK_MAX_ERRORS }

    Assert-InRange -Value $config.Interval -Min 1 -Max 300 -Name 'Interval'
    Assert-InRange -Value $config.LeadTimeMinutes -Min 0 -Max 30 -Name 'LeadTimeMinutes'
    Assert-InRange -Value $config.Debug -Min 0 -Max 1 -Name 'Debug'
    Assert-InRange -Value $config.MaxErrors -Min 1 -Max 100 -Name 'MaxErrors'

    [PSCustomObject]@{
        Interval        = $config.Interval
        LeadTimeMinutes = $config.LeadTimeMinutes
        Debug           = $config.Debug
        MaxErrors       = $config.MaxErrors
        Paths           = $paths
    }
}

function Save-CoreConfig {
    param(
        [int]$Interval,
        [int]$LeadTimeMinutes,
        [int]$DebugLogging,
        [int]$MaxErrors
    )

    Assert-InRange -Value $Interval -Min 1 -Max 300 -Name 'Interval'
    Assert-InRange -Value $LeadTimeMinutes -Min 0 -Max 30 -Name 'LeadTimeMinutes'
    Assert-InRange -Value $DebugLogging -Min 0 -Max 1 -Name 'Debug'
    Assert-InRange -Value $MaxErrors -Min 1 -Max 100 -Name 'MaxErrors'

    $paths = Get-CorePaths
    [PSCustomObject]@{
        Interval        = $Interval
        LeadTimeMinutes = $LeadTimeMinutes
        Debug           = $DebugLogging
        MaxErrors       = $MaxErrors
    } | ConvertTo-Json | Set-Content -Path $paths.ConfigPath -Encoding UTF8

    return Get-CoreConfig
}
