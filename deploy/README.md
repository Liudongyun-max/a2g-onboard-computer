# A2G Deploy Entrypoints

Run exactly one bootstrap for the current platform.

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\bootstrap.ps1
```

Ubuntu / Jetson:

```bash
bash deploy/bootstrap.sh
```

`deploy/` only detects the platform and dispatches to the correct module. Business logic remains in `windows/` or `jetson/`.
