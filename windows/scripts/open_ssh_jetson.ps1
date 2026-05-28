param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json")
)

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$target = "{0}@{1}" -f $config.jetson.user, $config.jetson.host
Start-Process powershell.exe -ArgumentList @("-NoExit", "-Command", "ssh $target")
