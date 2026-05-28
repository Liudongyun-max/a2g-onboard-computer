param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),
    [int]$Samples = 20,
    [int]$IntervalMs = 500
)

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$statusUrl = "{0}://{1}:{2}{3}" -f $config.jetson.dashboard.scheme, $config.jetson.host, $config.jetson.dashboard.port, $config.jetson.dashboard.statusPath
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $ReportDir "dashboard_sampling_$timestamp.json"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$results = @()
for ($i = 1; $i -le $Samples; $i++) {
    $time = Get-Date
    try {
        $raw = curl.exe --max-time 3 --silent --show-error $statusUrl
        $json = $raw | ConvertFrom-Json
        $results += [pscustomobject]@{
            time          = $time.ToString("s")
            ok            = $true
            detected      = $json.detected
            target_id     = $json.target_id
            fps           = [double]$json.fps
            range_m       = [double]$json.range_m
            frame_id      = [int64]$json.frame_id
            command_valid = $json.command.valid
            reason        = $json.command.reason
            error         = $json.error
        }
    } catch {
        $results += [pscustomobject]@{
            time          = $time.ToString("s")
            ok            = $false
            detected      = $null
            target_id     = $null
            fps           = $null
            range_m       = $null
            frame_id      = $null
            command_valid = $null
            reason        = $null
            error         = $_.Exception.Message
        }
    }
    Start-Sleep -Milliseconds $IntervalMs
}

$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8
$okCount = @($results | Where-Object { $_.ok }).Count
$fpsValues = @($results | Where-Object { $_.ok -and $null -ne $_.fps } | ForEach-Object { [double]$_.fps })
$frameValues = @($results | Where-Object { $_.ok -and $null -ne $_.frame_id } | ForEach-Object { [int64]$_.frame_id })

Write-Host "Status URL: $statusUrl"
Write-Host "Samples: $okCount / $Samples OK"
if ($fpsValues.Count -gt 0) {
    Write-Host ("FPS min/avg/max: {0:N2} / {1:N2} / {2:N2}" -f (($fpsValues | Measure-Object -Minimum).Minimum), (($fpsValues | Measure-Object -Average).Average), (($fpsValues | Measure-Object -Maximum).Maximum))
}
if ($frameValues.Count -gt 1) {
    Write-Host ("Frame delta: {0}" -f ($frameValues[-1] - $frameValues[0]))
}
Write-Host "Report: $reportPath"
