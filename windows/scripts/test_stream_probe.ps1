param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),
    [int]$Seconds = 3
)

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$streamUrl = "{0}://{1}:{2}/stream" -f $config.jetson.dashboard.scheme, $config.jetson.host, $config.jetson.dashboard.port
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outPath = Join-Path $ReportDir "stream_probe_$timestamp.mjpg"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

curl.exe --max-time $Seconds --silent --show-error --output $outPath --dump-header - $streamUrl
$file = Get-Item -LiteralPath $outPath
Write-Host "Stream URL: $streamUrl"
Write-Host "Probe file: $($file.FullName)"
Write-Host "Bytes received: $($file.Length)"
