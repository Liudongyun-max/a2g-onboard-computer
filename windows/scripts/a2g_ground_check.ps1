param(
    [switch]$SkipNetwork
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Config = Join-Path $Root "windows\config\ground_station.json"

Write-Host "A2G Windows ground check"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

if (-not (Test-Path $Config)) {
    throw "Missing config: $Config"
}

if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {
    Write-Warning "OpenSSH Client was not found."
}

$Browser = Get-Command msedge.exe -ErrorAction SilentlyContinue
if (-not $Browser) {
    $Browser = Get-Command chrome.exe -ErrorAction SilentlyContinue
}
if (-not $Browser) {
    Write-Warning "Chrome / Edge was not found in PATH."
}

if ($SkipNetwork) {
    Write-Host "PASS: local Windows checks completed with -SkipNetwork."
    exit 0
}

$Cfg = Get-Content $Config -Raw | ConvertFrom-Json
$Tcp = Test-NetConnection -ComputerName $Cfg.jetson_ip -Port $Cfg.dashboard_port
if (-not $Tcp.TcpTestSucceeded) {
    throw "Cannot connect to Jetson Dashboard at $($Cfg.jetson_ip):$($Cfg.dashboard_port)"
}

Write-Host "PASS: Windows can reach Jetson Dashboard TCP port."
