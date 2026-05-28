param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json"),
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),
    [switch]$SkipNetwork
)

$ErrorActionPreference = "Continue"

function Add-CheckResult {
    param(
        [System.Collections.Generic.List[object]]$Results,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Status,
        [string]$Detail = "",
        [string]$Evidence = ""
    )

    $Results.Add([pscustomobject]@{
        time     = (Get-Date).ToString("s")
        name     = $Name
        status   = $Status
        detail   = $Detail
        evidence = $Evidence
    }) | Out-Null
}

function Test-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-ExecutableAvailable {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$KnownPaths = @()
    )

    if (Test-CommandAvailable $Command) {
        return [pscustomobject]@{ Found = $true; Source = $Command }
    }

    foreach ($path in $KnownPaths) {
        if (Test-Path -LiteralPath $path) {
            return [pscustomobject]@{ Found = $true; Source = $path }
        }
    }

    return [pscustomobject]@{ Found = $false; Source = "" }
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$jetsonIp = $config.jetson.host
$dashboardPort = [int]$config.jetson.dashboard.port
$dashboardHome = "{0}://{1}:{2}" -f $config.jetson.dashboard.scheme, $jetsonIp, $dashboardPort
$dashboardStatus = "{0}{1}" -f $dashboardHome, $config.jetson.dashboard.statusPath
$sshTarget = "{0}@{1}" -f $config.jetson.user, $jetsonIp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $ReportDir "a2g_ground_check_$timestamp.json"
$results = [System.Collections.Generic.List[object]]::new()

Write-Host "========== A2G Windows Ground Station Check =========="
Write-Host "Config: $ConfigPath"
Write-Host "Dashboard: $dashboardHome"
Write-Host "Safety: monitor only; MAVLink control disabled by policy"

if ($config.safetyBoundary.monitorOnly -eq $true -and
    $config.safetyBoundary.mavlinkControlEnabled -eq $false -and
    $config.safetyBoundary.visionLandingServiceAllowed -eq $false) {
    Add-CheckResult $results "Safety boundary" "PASS" "Monitor-only boundary is preserved."
} else {
    Add-CheckResult $results "Safety boundary" "FAIL" "Config violates current validation safety boundary."
}

Write-Host "`n[1] Local tool checks..."
if (Test-CommandAvailable "ssh.exe") {
    $sshVersion = (cmd.exe /c "ssh -V 2>&1").Trim()
    Add-CheckResult $results "OpenSSH client" "PASS" "ssh.exe is available." $sshVersion
    Write-Host "OpenSSH: PASS ($sshVersion)"
} else {
    Add-CheckResult $results "OpenSSH client" "FAIL" "ssh.exe is not available."
    Write-Host "OpenSSH: FAIL"
}

$browserKnownPaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)
$browserFound = $null
foreach ($browser in @("msedge.exe", "chrome.exe")) {
    $candidate = Test-ExecutableAvailable $browser $browserKnownPaths
    if ($candidate.Found) {
        $browserFound = $candidate
        break
    }
}
if ($browserFound) {
    Add-CheckResult $results "Browser" "PASS" "$($browserFound.Source) is available."
    Write-Host "Browser: PASS ($($browserFound.Source))"
} else {
    Add-CheckResult $results "Browser" "WARN" "Chrome or Edge was not found in PATH or common install paths."
    Write-Host "Browser: WARN"
}

$qgcCandidate = Test-ExecutableAvailable "QGroundControl.exe" @(
    "F:\QGroundControl\bin\QGroundControl.exe",
    "$env:ProgramFiles\QGroundControl\QGroundControl.exe",
    "${env:ProgramFiles(x86)}\QGroundControl\QGroundControl.exe",
    "$env:LOCALAPPDATA\QGroundControl\QGroundControl.exe"
)
Add-CheckResult $results "QGroundControl command" ($(if ($qgcCandidate.Found) { "PASS" } else { "WARN" })) ($(if ($qgcCandidate.Found) { "$($qgcCandidate.Source) is available." } else { "QGroundControl was not found in PATH or common install paths; verify manually if installed." }))
Write-Host ("QGroundControl: " + $(if ($qgcCandidate.Found) { "PASS ($($qgcCandidate.Source))" } else { "WARN" }))

$vlcCandidate = Test-ExecutableAvailable "vlc.exe" @(
    (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "tools\vlc\vlc-3.0.23\vlc.exe"),
    "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
    "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
)
Add-CheckResult $results "VLC command" ($(if ($vlcCandidate.Found) { "PASS" } else { "WARN" })) ($(if ($vlcCandidate.Found) { "$($vlcCandidate.Source) is available." } else { "VLC was not found in PATH or common install paths; verify manually if installed." }))
Write-Host ("VLC: " + $(if ($vlcCandidate.Found) { "PASS ($($vlcCandidate.Source))" } else { "WARN" }))

if (-not $SkipNetwork) {
    Write-Host "`n[2] Ping Jetson..."
    $pingOk = Test-Connection -ComputerName $jetsonIp -Count 4 -Quiet -ErrorAction SilentlyContinue
    Add-CheckResult $results "Ping Jetson" ($(if ($pingOk) { "PASS" } else { "FAIL" })) "Target: $jetsonIp"
    Write-Host ("Ping: " + $(if ($pingOk) { "PASS" } else { "FAIL" }))

    Write-Host "`n[3] Test Dashboard port $dashboardPort..."
    $portResult = Test-NetConnection $jetsonIp -Port $dashboardPort -WarningAction SilentlyContinue
    $portEvidence = [pscustomobject]@{
        target              = "${jetsonIp}:$dashboardPort"
        tcpTestSucceeded    = [bool]$portResult.TcpTestSucceeded
        interfaceAlias      = $portResult.InterfaceAlias
        sourceAddress       = $portResult.SourceAddress.IPAddress
        networkIsolation    = $portResult.NetworkIsolationContext
    } | ConvertTo-Json -Compress
    Add-CheckResult $results "Dashboard port" ($(if ($portResult.TcpTestSucceeded) { "PASS" } else { "FAIL" })) "Target: ${jetsonIp}:$dashboardPort" $portEvidence
    Write-Host ("Dashboard port: " + $(if ($portResult.TcpTestSucceeded) { "PASS" } else { "FAIL" }))

    Write-Host "`n[4] Request Dashboard status..."
    try {
        $statusBody = & curl.exe --max-time 5 --silent --show-error $dashboardStatus 2>&1
        if ($LASTEXITCODE -eq 0 -and $statusBody) {
            Add-CheckResult $results "Dashboard status" "PASS" "GET $dashboardStatus" ($statusBody | Out-String).Trim()
            Write-Host "Dashboard status: PASS"
            Write-Host $statusBody

            try {
                $statusJson = $statusBody | ConvertFrom-Json
                Add-CheckResult $results "Dashboard running" ($(if ($statusJson.running -eq $true) { "PASS" } else { "FAIL" })) "running must be true." ("running={0}" -f $statusJson.running)
                Add-CheckResult $results "Aruco target id" ($(if ([int]$statusJson.target_id -eq [int]$config.jetson.aruco.markerId) { "PASS" } else { "FAIL" })) ("target_id must be {0}." -f $config.jetson.aruco.markerId) ("target_id={0}" -f $statusJson.target_id)
                Add-CheckResult $results "Dashboard FPS" ($(if ([double]$statusJson.fps -gt 0) { "PASS" } else { "FAIL" })) "fps must be greater than 0." ("fps={0}" -f $statusJson.fps)
                Add-CheckResult $results "Dashboard range" ($(if ([double]$statusJson.range_m -gt 0) { "PASS" } else { "WARN" })) "range_m should be greater than 0 when marker is detected." ("range_m={0}; detected={1}" -f $statusJson.range_m, $statusJson.detected)
            } catch {
                Add-CheckResult $results "Dashboard status schema" "WARN" "Status response was not valid JSON or missed expected fields." $_.Exception.Message
            }
        } else {
            Add-CheckResult $results "Dashboard status" "FAIL" "GET $dashboardStatus" ($statusBody | Out-String).Trim()
            Write-Host "Dashboard status: FAIL"
        }
    } catch {
        Add-CheckResult $results "Dashboard status" "FAIL" "GET $dashboardStatus" $_.Exception.Message
        Write-Host "Dashboard status: FAIL"
    }

    Write-Host "`n[5] Test SSH port..."
    $sshPort = [int]$config.jetson.ssh.port
    $sshPortResult = Test-NetConnection $jetsonIp -Port $sshPort -WarningAction SilentlyContinue
    $sshEvidence = [pscustomobject]@{
        target              = "${jetsonIp}:$sshPort"
        tcpTestSucceeded    = [bool]$sshPortResult.TcpTestSucceeded
        interfaceAlias      = $sshPortResult.InterfaceAlias
        sourceAddress       = $sshPortResult.SourceAddress.IPAddress
        networkIsolation    = $sshPortResult.NetworkIsolationContext
    } | ConvertTo-Json -Compress
    Add-CheckResult $results "SSH port" ($(if ($sshPortResult.TcpTestSucceeded) { "PASS" } else { "FAIL" })) "Target: ${jetsonIp}:$sshPort" $sshEvidence
    Write-Host ("SSH port: " + $(if ($sshPortResult.TcpTestSucceeded) { "PASS" } else { "FAIL" }))
} else {
    Add-CheckResult $results "Network checks" "SKIP" "Network checks skipped by -SkipNetwork."
    Write-Host "`nNetwork checks skipped."
}

Write-Host "`n[6] Operator commands..."
Write-Host "Dashboard URL: $dashboardHome"
Write-Host "Status URL:    $dashboardStatus"
Write-Host "SSH command:   ssh $sshTarget"
Write-Host "QGC UDP port:  $($config.flightController.qgroundcontrol.udpPort)"

$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("s")
    configPath  = (Resolve-Path -LiteralPath $ConfigPath).Path
    dashboard   = $dashboardHome
    sshCommand  = "ssh $sshTarget"
    results     = $results
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Host "`nReport: $reportPath"
Write-Host "========== Check Finished =========="
