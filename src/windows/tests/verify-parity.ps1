$ErrorActionPreference = 'Stop'

function Is-Imminent {
    param(
        [string]$Text,
        [int]$LeadTimeMinutes
    )

    if ($Text -match '(?i)\bnow\b') { return $true }
    if ($LeadTimeMinutes -le 0) { return $false }
    if ($Text -match '(?i)\b(\d+)\s*min') {
        return [int]$matches[1] -le $LeadTimeMinutes
    }
    return $false
}

$cases = @(
    @{ Text = 'Meeting starts now'; Lead = 0; Expected = $true },
    @{ Text = 'Meeting starts in 2 min'; Lead = 2; Expected = $true },
    @{ Text = 'Meeting starts in 3 min'; Lead = 2; Expected = $false },
    @{ Text = 'Meeting starts in 1 min'; Lead = 0; Expected = $false }
)

$failures = @()
foreach ($c in $cases) {
    $actual = Is-Imminent -Text $c.Text -LeadTimeMinutes $c.Lead
    if ($actual -ne $c.Expected) {
        $failures += "Case failed: text='$($c.Text)', lead=$($c.Lead), expected=$($c.Expected), actual=$actual"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Parity checks passed.'
