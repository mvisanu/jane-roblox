"""Checks that the Quest menu stays upper-left, keeps its size, and can hide."""

from __future__ import annotations

import sys
from pathlib import Path

from quest_chain_test import boot


ROOT = Path(__file__).resolve().parents[1]
VIEWPORTS = {
    (640, 360): (486, 170),
    (844, 390): (620, 200),
    (390, 844): (300, 620),
    (1024, 768): (620, 578),
    (1366, 768): (620, 578),
    (1868, 1186): (620, 620),
    (2560, 1440): (620, 620),
}


def main() -> int:
    _lua, modules, _data, _game, _player, _toasts = boot()
    layout = modules["QuestBoardLayout"]
    failures: list[str] = []

    for (width, height), expected_size in VIEWPORTS.items():
        opened = layout.open(width, height)
        if int(opened.X) != int(layout.MARGIN) or int(opened.Y) != int(layout.TOP_SAFE):
            failures.append(f"{width}x{height}: open Quest menu is not fixed at upper-left")
        if (int(opened.Width), int(opened.Height)) != expected_size:
            failures.append(
                f"{width}x{height}: open size changed to {int(opened.Width)}x{int(opened.Height)}, "
                f"expected previous {expected_size[0]}x{expected_size[1]}"
            )
        if not layout.insideScreen(width, height, opened):
            failures.append(f"{width}x{height}: open Quest menu leaves the screen")
        if float(opened.Y) < float(layout.TOP_SAFE) - 1:
            failures.append(f"{width}x{height}: open Quest menu overlaps the top controls")
        if float(opened.Y) + float(opened.Height) > height - float(layout.BOTTOM_SAFE) + 1:
            failures.append(f"{width}x{height}: open Quest menu overlaps the bottom bar")

        closed = layout.closed(width, height)
        if int(closed.X) != int(opened.X) or int(closed.Y) != int(opened.Y):
            failures.append(f"{width}x{height}: hiding the Quest menu moves its header")
        if int(closed.Width) != min(220, max(180, width - 32)) or int(closed.Height) != 58:
            failures.append(f"{width}x{height}: hidden Quest header changed size")
        if not layout.insideScreen(width, height, closed):
            failures.append(f"{width}x{height}: hidden Quest header leaves the screen")

    source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/QuestBoard.lua").read_text(encoding="utf-8")
    contracts = {
        "panel.AnchorPoint = Vector2.new(0, 0)": "Quest panel is not top-left anchored",
        "QuestBoardLayout.open": "Quest menu is not using responsive upper-left geometry",
        "QuestBoardLayout.closed": "hidden header is not using upper-left geometry",
        "self._body.Visible = open": "Quest contents cannot be hidden",
        "self:SetOpen(not self._open)": "Quest header no longer toggles open/hidden",
        'self._bilingual("CLOSE", "ปิด")': "Quest menu has no visible close control",
        "UDim2.fromOffset(54, 0), 15, true)": "Quest header text was not enlarged",
        "), 18, true, theme.Colors.PrimaryDark)": "chapter title is smaller than 18px",
        "), 15, active, tone)": "quest-step text is smaller than 15px",
        "ScrollBarThickness = 7": "Quest scrollbar is too narrow",
    }
    for contract, message in contracts.items():
        if contract not in source:
            failures.append(message)

    if failures:
        print("Quest board layout failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        "Quest board layout passed: fixed upper-left position across 7 phone/desktop viewports, "
        "unchanged 620x620 desktop size, safe-bar clearance, and working open/hide toggle."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
