"""Proves the bottom-tab activity panel opens centred and readable."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:  # pragma: no cover
    print("This test needs the Lua bridge. Install it with: python -m pip install lupa")
    raise SystemExit(2)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walkability_test import luau_to_lua  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
HUD_LAYOUT = ROOT / "src" / "ReplicatedStorage" / "Shared" / "HudLayout.lua"
CLIENT = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "Client.client.lua"
BAG_GRID = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "UI" / "BagGrid.lua"


def load_hud_layout():
    lua = LuaRuntime(unpack_returned_tuples=True)
    chunk = lua.eval("function(s) return load(s, 'HudLayout') end")(
        luau_to_lua(HUD_LAYOUT.read_text(encoding="utf-8"))
    )
    if isinstance(chunk, tuple):
        raise SystemExit(f"HudLayout.lua failed to parse: {chunk[1]}")
    return chunk()


def viewports():
    named = [
        (1450, 805, "reference screenshot"),
        (1920, 1080, "desktop 1080p"),
        (2560, 1440, "desktop 1440p"),
        (3440, 1440, "ultrawide"),
        (1366, 768, "laptop"),
        (1024, 768, "tablet landscape"),
        (390, 844, "phone portrait"),
        (844, 390, "phone landscape"),
        (640, 360, "small landscape"),
    ]
    seen = set()
    for width, height, label in named:
        seen.add((width, height))
        yield width, height, label
    for width in range(390, 2601, 30):
        for height in range(360, 1441, 30):
            if (width, height) not in seen:
                yield width, height, "sweep"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    hud = load_hud_layout()
    failures: list[str] = []
    checked = 0

    for width, height, label in viewports():
        checked += 1
        panel_w, panel_h = hud.panelSize(width, height)
        x, y = hud.center(width, height, panel_w, panel_h)

        expected_x = (width - panel_w) / 2
        safe_mid_y = float(hud.TOP_SAFE) + (
            height - float(hud.TOP_SAFE) - float(hud.BOTTOM_SAFE)
        ) / 2
        if abs((x + panel_w / 2) - width / 2) > 1:
            failures.append(f"{label} {width}x{height}: panel is not horizontally centred")
        if abs((y + panel_h / 2) - safe_mid_y) > 1:
            failures.append(f"{label} {width}x{height}: panel is not centred between safe bars")
        if abs(x - expected_x) > 1:
            failures.append(f"{label} {width}x{height}: unexpected centre x={x}")
        if x < hud.MARGIN or x + panel_w > width - hud.MARGIN:
            failures.append(f"{label} {width}x{height}: panel leaves the screen horizontally")
        if y < hud.TOP_SAFE or y + panel_h > height - hud.BOTTOM_SAFE:
            failures.append(f"{label} {width}x{height}: panel overlaps the top or bottom bar")

        for target_x, target_y in ((-9999, -9999), (9999, 9999), (width * 2, -50)):
            dx, dy = hud.clamp(width, height, panel_w, panel_h, target_x, target_y)
            if dx < hud.MARGIN or dx + panel_w > width - hud.MARGIN:
                failures.append(f"{label} {width}x{height}: dragged panel escaped horizontally")
            if dy < hud.TOP_SAFE or dy + panel_h > height - hud.BOTTOM_SAFE:
                failures.append(f"{label} {width}x{height}: dragged panel escaped vertically")

        if args.verbose and label != "sweep":
            print(f"{label:20} {width}x{height}: panel {panel_w}x{panel_h} at ({x},{y})")

    ref_w, ref_h = hud.panelSize(1450, 805)
    if ref_w < 640 or ref_h < 540:
        failures.append(f"reference panel is not large enough for readable copy ({ref_w}x{ref_h})")

    typography = {
        "TITLE_TEXT_SIZE": 20,
        "HEADING_TEXT_SIZE": 17,
        "BODY_TEXT_SIZE": 15,
        "CONTROL_TEXT_SIZE": 15,
        "SCROLLBAR_THICKNESS": 8,
    }
    for name, minimum in typography.items():
        if float(getattr(hud, name)) < minimum:
            failures.append(f"{name} is below its readable minimum of {minimum}")

    source = CLIENT.read_text(encoding="utf-8")
    contracts = {
        "HudLayout.center": "client does not use the centred layout",
        "HudLayout.TITLE_TEXT_SIZE": "panel title does not use the readable contract",
        "HudLayout.HEADING_TEXT_SIZE": "section headings do not use the readable contract",
        "HudLayout.BODY_TEXT_SIZE": "body copy does not use the readable contract",
        "HudLayout.CONTROL_TEXT_SIZE": "activity buttons do not use the readable contract",
        "HudLayout.SCROLLBAR_THICKNESS": "activity scrollbar does not use the wider contract",
        "panelOffset = nil\n\t\trenderMenu(name)": "bottom tabs do not reset the activity panel to centre",
    }
    for contract, message in contracts.items():
        if contract not in source:
            failures.append(message)

    bag_source = BAG_GRID.read_text(encoding="utf-8")
    if "label.TextSize = resource and 12 or 11" not in bag_source:
        failures.append("Bag item names are still too small")
    if "count.TextSize = 13" not in bag_source:
        failures.append("Bag item counts are still too small")

    if failures:
        print(f"HUD layout FAILED ({len(failures)} problem(s)):")
        for line in failures[:16]:
            print(f"  - {line}")
        if len(failures) > 16:
            print(f"  ... and {len(failures) - 16} more")
        return 1

    print(
        f"HUD layout passed: {checked} phone/desktop viewports, centred safe-area geometry, "
        "680px desktop reading width, 20px title, 17px headings, 15px body and controls."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
