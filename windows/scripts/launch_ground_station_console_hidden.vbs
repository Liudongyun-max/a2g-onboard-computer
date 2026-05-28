Set shell = CreateObject("WScript.Shell")
scriptPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\open_ground_station_console.ps1"
shell.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """", 0, False
