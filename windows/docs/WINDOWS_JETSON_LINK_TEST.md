# Windows / Jetson Link Test

Run from repository root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\bootstrap.ps1
powershell -ExecutionPolicy Bypass -File .\windows\scripts\quick_link_test.ps1 -JetsonIp 192.168.1.219 -Port 8080 -OpenDashboard
```

Expected:

- Dashboard opens.
- `/status` returns JSON.
- Monitor-only commands are accepted.
- Flight-control commands are rejected.
