param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json"),
    [ValidateSet("udpH264", "rtsp")]
    [string]$Stream = "udpH264"
)

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$portableVlc = Join-Path $root $config.backupVideo.vlc.portablePath
$candidates = @(
    $portableVlc,
    "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
    "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
)

$vlc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $vlc) {
    throw "vlc.exe was not found. Install VLC or deploy portable VLC under tools/vlc."
}

$streamUrl = $config.backupVideo.futureStreams.$Stream
Start-Process -FilePath $vlc -ArgumentList @($streamUrl)
