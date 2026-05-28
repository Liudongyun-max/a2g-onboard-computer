Write-Host "A2G Windows Bootstrap"
Write-Host "Checking Windows ground station workspace..."

$paths = @(
  ".\windows",
  ".\windows\scripts",
  ".\windows\config",
  ".\shared\api"
)

foreach ($p in $paths) {
  if (Test-Path $p) {
    Write-Host "[OK] $p"
  } else {
    Write-Host "[WARN] Missing $p"
  }
}

Write-Host "Next:"
Write-Host "powershell -ExecutionPolicy Bypass -File .\windows\scripts\quick_link_test.ps1 -JetsonIp 192.168.1.219 -Port 8080 -OpenDashboard"
