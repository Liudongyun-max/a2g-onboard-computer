import os
import platform

system = platform.system().lower()

if system == "windows":
    print("windows")
elif system == "linux":
    if os.path.exists("/etc/nv_tegra_release"):
        print("jetson")
    else:
        print("linux")
else:
    print(system)
