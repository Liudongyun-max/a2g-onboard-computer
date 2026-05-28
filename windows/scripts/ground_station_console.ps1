param(
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ConfigPath = Join-Path $Root "windows\config\ground_station.json"

if (-not (Test-Path $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

if ($SelfTest) {
    Write-Host "PASS: ground_station_console.ps1 self-test"
    exit 0
}

Write-Host "A2G Ground Station Console"
Write-Host "Dashboard: $($Config.dashboard_url)"
Write-Host "Status:    $($Config.status_url)"
Write-Host "Stream:    $($Config.stream_url)"
Write-Host ""
Write-Host "Use quick link test for current monitor-only phase:"
Write-Host "powershell -ExecutionPolicy Bypass -File `"$PSScriptRoot\quick_link_test.ps1`" -JetsonIp $($Config.jetson_ip) -Port $($Config.dashboard_port) -OpenDashboard"

Start-Process $Config.dashboard_url
