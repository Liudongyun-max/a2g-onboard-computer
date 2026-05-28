# ArUco Scale Calibration Result

Date: 2026-05-24

Current platform:

- Camera: `/dev/video0`
- Resolution: `640x480`
- Dictionary: `DICT_5X5_250`
- Marker ID: `1`

## Raw Gates

Measured black/white outer region reported by operator: `0.086m`.

OpenCV ArUco PnP uses the detected marker corner square. The initial `0.086m`
setting produced a 1m distance estimate of about `2.086m`, so it is not the
effective marker size for this printed target.

Validated samples:

| Gate | Configured size | median_z_m | abs_error_m | rel_error | recommended_marker_size_m |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1.00m | 0.041224 | 1.003448 | 0.003448 | 0.003448 | 0.041082 |
| 1.36m | 0.041080 | 1.287518 | 0.072482 | 0.053295 | 0.043393 |
| 1.50m | 0.041080 | 1.437673 | 0.062327 | 0.041551 | 0.042861 |

## Final Runtime Value

The deployed compromise value is:

```text
marker_size_m = 0.04268
```

Expected normalized error with this value is within about 5% across the tested
1.00m, 1.36m, and 1.50m gates.

## Decision

Marker scale calibration is acceptable for ground visual validation and shadow
testing. Before real closed-loop landing, camera extrinsics must still be
confirmed, and camera intrinsics should be recalibrated if tighter distance
accuracy is required.
