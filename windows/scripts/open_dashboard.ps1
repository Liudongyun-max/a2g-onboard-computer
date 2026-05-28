param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json")
)

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$dashboardHome = "{0}://{1}:{2}" -f $config.jetson.dashboard.scheme, $config.jetson.host, $config.jetson.dashboard.port
Start-Process $dashboardHome
