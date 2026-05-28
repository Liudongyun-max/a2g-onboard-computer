$launcher = Join-Path $PSScriptRoot "launch_ground_station_console_hidden.vbs"
Start-Process wscript.exe -ArgumentList "`"$launcher`""
