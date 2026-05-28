param(
    [string]$JetsonIp = "192.168.1.219",
    [int]$Port = 8080,
    [switch]$OpenDashboard
)

$statusUrl = "http://${JetsonIp}:$Port/status"
$dashboardUrl = "http://${JetsonIp}:$Port"
$streamUrl = "http://${JetsonIp}:$Port/stream"

Write-Host "A2G Windows quick link test"
Write-Host "Jetson: $JetsonIp"
Write-Host "Dashboard: $dashboardUrl"

Write-Host "`n[1] Ping Jetson"
ping $JetsonIp -n 4

Write-Host "`n[2] Test Dashboard port"
Test-NetConnection $JetsonIp -Port $Port

Write-Host "`n[3] Request /status"
curl.exe --max-time 5 --silent --show-error $statusUrl

Write-Host "`n[4] Stream URL"
Write-Host $streamUrl

if ($OpenDashboard) {
    Start-Process $dashboardUrl
}
