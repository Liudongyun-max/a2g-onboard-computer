#!/usr/bin/env bash
set -euo pipefail

GROUND_STATION_IP="${GROUND_STATION_IP:-}"
PORT="${VIDEO_PORT:-5600}"
DEVICE="${VIDEO_DEVICE:-/dev/video0}"
WIDTH="${VIDEO_WIDTH:-640}"
HEIGHT="${VIDEO_HEIGHT:-480}"
FPS="${VIDEO_FPS:-30}"
BITRATE="${VIDEO_BITRATE_KBPS:-1500}"

if [[ -z "$GROUND_STATION_IP" ]]; then
  echo "Set GROUND_STATION_IP first, for example:" >&2
  echo "  GROUND_STATION_IP=192.168.1.100 bash scripts/run_udp_video.sh" >&2
  exit 2
fi

if ! gst-inspect-1.0 x264enc >/dev/null 2>&1; then
  echo "GStreamer x264enc is not available on this Jetson." >&2
  exit 3
fi

echo "Streaming $DEVICE ${WIDTH}x${HEIGHT}@${FPS} to udp://${GROUND_STATION_IP}:${PORT}"
echo "Do not run this while dashboard or another process owns $DEVICE."

gst-launch-1.0 -v \
  v4l2src device="$DEVICE" ! \
  "video/x-raw,width=${WIDTH},height=${HEIGHT},framerate=${FPS}/1" ! \
  videoconvert ! \
  x264enc tune=zerolatency bitrate="$BITRATE" speed-preset=ultrafast key-int-max=30 ! \
  rtph264pay config-interval=1 pt=96 ! \
  udpsink host="$GROUND_STATION_IP" port="$PORT" sync=false async=false
