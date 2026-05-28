param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json")
)

$candidates = @(
    "F:\QGroundControl\bin\QGroundControl.exe",
    "$env:ProgramFiles\QGroundControl\QGroundControl.exe",
    "${env:ProgramFiles(x86)}\QGroundControl\QGroundControl.exe",
    "$env:LOCALAPPDATA\QGroundControl\QGroundControl.exe"
)

$qgc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $qgc) {
    throw "QGroundControl.exe was not found in known paths."
}

Start-Process -FilePath $qgc
