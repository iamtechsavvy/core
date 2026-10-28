param(
    [Parameter(Mandatory = $false)]
    [int]$Interval,
    [Parameter(Mandatory = $false)]
    [int]$LeadTimeMinutes,
    [Parameter(Mandatory = $false)]
    [ValidateRange(0,1)]
    [int]$DebugLogging,
    [Parameter(Mandatory = $false)]
    [int]$MaxErrors
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/CoreConfig.ps1"

$current = Get-CoreConfig
$newInterval = if ($PSBoundParameters.ContainsKey('Interval')) { $Interval } else { $current.Interval }
$newLead = if ($PSBoundParameters.ContainsKey('LeadTimeMinutes')) { $LeadTimeMinutes } else { $current.LeadTimeMinutes }
$newDebug = if ($PSBoundParameters.ContainsKey('DebugLogging')) { $DebugLogging } else { $current.Debug }
$newMaxErrors = if ($PSBoundParameters.ContainsKey('MaxErrors')) { $MaxErrors } else { $current.MaxErrors }

$updated = Save-CoreConfig -Interval $newInterval -LeadTimeMinutes $newLead -DebugLogging $newDebug -MaxErrors $newMaxErrors
Write-Host "Saved config: interval=$($updated.Interval)s, lead=$($updated.LeadTimeMinutes)m, debug=$($updated.Debug), maxErrors=$($updated.MaxErrors)"
