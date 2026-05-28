param(
    [string]$JetsonIp = "192.168.1.219",
    [int]$Port = 8080,
    [string]$Token = "",
    [switch]$OpenDashboard
)

$ErrorActionPreference = "Stop"

$BaseUrl = "http://$JetsonIp`:$Port"
$Headers = @{ "Content-Type" = "application/json" }
if ($Token -ne "") {
    $Headers["X-A2G-Token"] = $Token
}

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Send-GroundCommand {
    param(
        [string]$Command,
        [hashtable]$Params = @{}
    )

    $Body = @{
        command = $Command
        params = $Params
        client_time = (Get-Date).ToString("o")
        client = "windows-quick-link-test"
    } | ConvertTo-Json -Depth 5

    try {
        $Response = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/ground-command" -Headers $Headers -Body $Body
        $Accepted = [bool]$Response.accepted
        $Executed = [bool]$Response.executed
        Write-Host ("{0,-18} accepted={1,-5} executed={2,-5} reason={3}" -f $Command, $Accepted, $Executed, $Response.reason)
        return $Response
    }
    catch {
        if ($_.Exception.Response -ne $null) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
            $Stream = $_.Exception.Response.GetResponseStream()
            $Reader = New-Object System.IO.StreamReader($Stream)
            $BodyText = $Reader.ReadToEnd()
            Write-Host ("{0,-18} HTTP {1} {2}" -f $Command, $StatusCode, $BodyText) -ForegroundColor Yellow
            return $null
        }
        throw
    }
}

Write-Step "A2G Ground Quick Link"
Write-Host "Dashboard: $BaseUrl"
Write-Host "Status:    $BaseUrl/status"
Write-Host "Stream:    $BaseUrl/stream"

Write-Step "TCP connectivity"
$Tcp = Test-NetConnection -ComputerName $JetsonIp -Port $Port
Write-Host ("TcpTestSucceeded={0}" -f $Tcp.TcpTestSucceeded)
if (-not $Tcp.TcpTestSucceeded) {
    throw "Cannot connect to $JetsonIp`:$Port. Check Wi-Fi/LAN, Jetson IP, firewall, and dashboard service."
}

Write-Step "Dashboard status"
$Status = Invoke-RestMethod -Method Get -Uri "$BaseUrl/status"
$Status | ConvertTo-Json -Depth 8

Write-Step "Allowed monitor-only commands"
Send-GroundCommand -Command "ping" | Out-Null
Send-GroundCommand -Command "status_snapshot" | Out-Null
Send-GroundCommand -Command "mark_event" -Params @{ note = "windows quick link test" } | Out-Null
Send-GroundCommand -Command "start_record" | Out-Null
Start-Sleep -Milliseconds 300
Send-GroundCommand -Command "stop_record" | Out-Null
Send-GroundCommand -Command "shadow_start" | Out-Null
Start-Sleep -Milliseconds 300
Send-GroundCommand -Command "shadow_stop" | Out-Null

Write-Step "Forbidden flight-control command check"
$Forbidden = Send-GroundCommand -Command "send_velocity" -Params @{ vx = 0; vy = 0; vz = 0 }
if ($Forbidden -ne $null -and $Forbidden.accepted -eq $true) {
    throw "Safety failure: send_velocity was accepted. Stop integration and inspect Jetson safety gates."
}

if ($OpenDashboard) {
    Write-Step "Open dashboard"
    Start-Process $BaseUrl
}

Write-Step "Result"
Write-Host "PASS: Windows can reach Jetson Dashboard and monitor-only command API."
Write-Host "Keep mavlink.enabled=false until Shadow testing has explicit approval."
