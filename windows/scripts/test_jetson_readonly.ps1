param(
    [string]$JetsonIp = "192.168.1.219",
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"
$BaseUrl = "http://$JetsonIp`:$Port"

$Status = Invoke-RestMethod -Method Get -Uri "$BaseUrl/status"
if ($Status.mavlink_enabled -eq $true) {
    throw "Safety failure: mavlink_enabled=true"
}

$Body = @{
    command = "send_velocity"
    params = @{ vx = 0; vy = 0; vz = 0 }
    client_time = (Get-Date).ToString("o")
    client = "windows-readonly-test"
} | ConvertTo-Json -Depth 5

try {
    $Rejected = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/ground-command" -ContentType "application/json" -Body $Body
    if ($Rejected.accepted -eq $true) {
        throw "Safety failure: forbidden command was accepted"
    }
}
catch {
    if ($_.Exception.Response -eq $null) {
        throw
    }
    $Code = [int]$_.Exception.Response.StatusCode
    if ($Code -ne 403) {
        throw "Expected HTTP 403 for forbidden command, got $Code"
    }
}

Write-Host "PASS: Jetson readonly safety boundary is enforced."
