param(
    [string]$JetsonIp = "192.168.1.219",
    [int]$Port = 8080,
    [int]$Samples = 5
)

$ErrorActionPreference = "Stop"
$Url = "http://$JetsonIp`:$Port/status"

for ($i = 1; $i -le $Samples; $i++) {
    $Status = Invoke-RestMethod -Method Get -Uri $Url
    Write-Host ("sample={0} running={1} detected={2} fps={3} mavlink_enabled={4}" -f $i, $Status.running, $Status.detected, $Status.fps, $Status.mavlink_enabled)
    Start-Sleep -Milliseconds 300
}
