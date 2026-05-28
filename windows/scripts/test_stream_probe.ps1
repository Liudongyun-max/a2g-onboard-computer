param(
    [string]$JetsonIp = "192.168.1.219",
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"
$Url = "http://$JetsonIp`:$Port/stream"
$Response = Invoke-WebRequest -Method Get -Uri $Url -Headers @{ Range = "bytes=0-1024" } -TimeoutSec 5
Write-Host "stream_status=$($Response.StatusCode)"
Write-Host "content_type=$($Response.Headers.'Content-Type')"
