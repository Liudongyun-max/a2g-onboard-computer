# Windows Quick Link Test

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\scripts\quick_link_test.ps1 -JetsonIp 192.168.1.219 -Port 8080 -OpenDashboard
```

This checks ping, Dashboard port 8080, `/status`, and optionally opens the Dashboard.
