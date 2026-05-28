# Portable VLC

This folder contains the project-local VLC runtime used by the Windows ground
station backup video script.

Current runtime:

```text
tools/vlc/vlc-3.0.23/vlc.exe
```

It is intentionally kept inside the workspace so backup video validation does
not depend on a machine-wide VLC installation or PATH changes.
