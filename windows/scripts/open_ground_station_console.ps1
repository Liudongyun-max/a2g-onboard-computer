$ErrorActionPreference = "Stop"
$Script = Join-Path $PSScriptRoot "ground_station_console.ps1"
powershell -ExecutionPolicy Bypass -File $Script
