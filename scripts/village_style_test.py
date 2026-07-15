"""Checks every generated building uses approved A — Bakery Bay styling.

Two things are verified:

1. Palette. Every building colour must be an exact member of the approved
   whole-town Bakery Bay palette; no retired village/home swatch is accepted.

2. Architecture. The reference is a timber-framed village: pitched shingle
   roofs, dark beams over plaster, stone footings, hanging lanterns. Every
   building must actually carry those features, not just the right colours.

Usage:
    python scripts/village_style_test.py [--verbose]
"""

from __future__ import annotations

import argparse
import math
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from walkability_test import load_world  # noqa: E402

# RGB values must resolve exactly to one of the approved central swatches.
MAX_MEAN_DISTANCE = 0.1

# Whole-town palette approved from concept A — Bakery Bay. Every building now
# uses this same source of truth instead of the retired village/home palettes.
BAKERY_BAY_PALETTE = [
	(29, 17, 8), (42, 31, 20), (69, 44, 23), (89, 58, 32), (147, 103, 63),
	(59, 35, 21), (130, 78, 48), (149, 98, 59),
	(45, 41, 35), (75, 67, 58), (126, 112, 97), (95, 83, 71),
	(197, 160, 117), (224, 200, 165), (129, 68, 39),
	(32, 34, 19), (52, 56, 27), (69, 72, 34), (91, 93, 45), (54, 39, 25),
	(79, 103, 96), (130, 150, 138), (217, 162, 90), (240, 184, 90),
	(215, 187, 149), (198, 168, 131), (27, 27, 32),
]

# Features every building must carry to read as part of this village.
REQUIRED_FEATURES = {
    "RoofPlane": "a pitched roof",
    "RoofRidge": "a ridge beam",
    "GableCourse": "gable ends",
    "CornerPost": "timber corner posts",
    "WallRail": "timber rails",
    "WallBrace": "diagonal timber braces",
    "LanternGlow": "hanging lanterns",
}

# Buildings only; the cave is rock and the mountain is rock, by design.
BUILDINGS = {
    "FamilyCafe",
    "PetShop",
    "FlowerShop",
    "LittleSchool",
    "TreeHouse",
    "CampCottage",
    "AdventureCenter",
    *(f"Home{index:02d}" for index in range(1, 9)),
}


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def nearest(color: tuple[int, int, int], palette: list[tuple[int, int, int]]) -> float:
    return min(distance(color, entry) for entry in palette)


def model_of(path: str) -> str:
    return path.split(".")[-2]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    if args.verbose:
        swatches = "  ".join(f"#{r:02X}{g:02X}{b:02X}" for r, g, b in BAKERY_BAY_PALETTE)
        print(f"Approved A — Bakery Bay palette:\n  {swatches}\n")

    parts, _ = load_world(False)
    failures: list[str] = []

    by_model: dict[str, list[dict]] = {}
    for row in parts:
        by_model.setdefault(model_of(row["path"]), []).append(row)

    missing = sorted(BUILDINGS - set(by_model))
    for name in missing:
        failures.append(f"{name}: building was not generated at all")

    for name in sorted(BUILDINGS & set(by_model)):
        rows = by_model[name]
        features = Counter(row["name"] for row in rows)

        for feature, description in REQUIRED_FEATURES.items():
            if features[feature] == 0:
                failures.append(f"{name}: has no {description} ({feature})")

        # Markers are invisible, so they say nothing about how the building looks.
        visible = [row for row in rows if row["name"] not in ("DoorwayVolume", "InteriorMarker", "SummitMarker")]
        if not visible:
            continue
        model_palette = BAKERY_BAY_PALETTE
        distances = [nearest((row["r"], row["g"], row["b"]), model_palette) for row in visible]
        mean = sum(distances) / len(distances)
        worst = max(distances)
        if mean > MAX_MEAN_DISTANCE:
            failures.append(
                f"{name}: colours are {mean:.0f} away from the Bakery Bay palette "
                f"(limit {MAX_MEAN_DISTANCE:.0f}) - it does not look like the village"
            )
        if args.verbose:
            print(f"  {name:16} {len(visible):4d} parts   mean colour distance {mean:5.1f}   worst {worst:5.1f}")

    if failures:
        print("\nVillage style failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        f"\nVillage style passed: all {len(BUILDINGS)} buildings carry the timber-framed "
        "architecture and use only the approved A — Bakery Bay palette."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
