$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$WindowsRoot = Join-Path $RepoRoot "windows"
$ConfigPath = Join-Path $WindowsRoot "config\ground_station.json"

if (-not $IsWindows -and [System.Environment]::OSVersion.Platform -ne "Win32NT") {
    throw "deploy/bootstrap.ps1 must run on Windows."
}

Write-Host "A2G Windows bootstrap"
python (Join-Path $RepoRoot "deploy\detect_platform.py")

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "PowerShell 5 or newer is required."
}

if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {
    Write-Warning "OpenSSH Client was not found in PATH."
}

if (-not (Test-Path $ConfigPath)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ConfigPath) | Out-Null
    @{
        jetson_ip = "192.168.1.219"
        dashboard_port = 8080
        dashboard_url = "http://192.168.1.219:8080"
        status_url = "http://192.168.1.219:8080/status"
        stream_url = "http://192.168.1.219:8080/stream"
    } | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $ConfigPath
    Write-Host "Created windows/config/ground_station.json"
}

$GroundCheck = Join-Path $WindowsRoot "scripts\a2g_ground_check.ps1"
if (Test-Path $GroundCheck) {
    powershell -ExecutionPolicy Bypass -File $GroundCheck -SkipNetwork
}
else {
    Write-Warning "windows/scripts/a2g_ground_check.ps1 not found; skipping local ground check."
}

Write-Host "Windows bootstrap complete."
