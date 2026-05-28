from __future__ import annotations

import argparse
import csv
from pathlib import Path
from statistics import mean, pstdev


def parse_args():
    parser = argparse.ArgumentParser(description="Summarize ArUco distance calibration samples")
    parser.add_argument("--samples", default="logs/aruco_calibration_samples.csv")
    return parser.parse_args()


def main():
    args = parse_args()
    path = Path(args.samples)
    if not path.exists():
        raise RuntimeError(f"Sample file not found: {path}")

    values = []
    with path.open("r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            values.append(float(row["suggested_marker_length_m"]))

    if not values:
        raise RuntimeError("No samples found")

    avg = mean(values)
    spread = pstdev(values) if len(values) > 1 else 0.0
    print(f"samples={len(values)}")
    print(f"suggested marker_length_m={avg:.5f}")
    print(f"stddev={spread:.5f}")


if __name__ == "__main__":
    main()
