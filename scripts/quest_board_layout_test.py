"""Checks the half-size Quest menu, enlarged type, scrolling, and hide control."""

from __future__ import annotations

import sys
from pathlib import Path

from quest_chain_test import boot


ROOT = Path(__file__).resolve().parents[1]
VIEWPORTS = {
    (640, 360): ((486, 170), (243, 85)),
    (844, 390): ((620, 200), (310, 100)),
    (390, 844): ((300, 620), (150, 310)),
    (1024, 768): ((620, 578), (310, 289)),
    (1366, 768): ((620, 578), (310, 289)),
    (1868, 1186): ((620, 620), (310, 310)),
    (2560, 1440): ((620, 620), (310, 310)),
}


def main() -> int:
    _lua, modules, _data, _game, _player, _toasts = boot()
    layout = modules["QuestBoardLayout"]
    failures: list[str] = []

    if float(layout.OPEN_SCALE_FROM_ORIGINAL) != 0.5:
        failures.append("open Quest menu is not scaled to exactly 50% of its original geometry")

    for (width, height), (original_size, expected_size) in VIEWPORTS.items():
        opened = layout.open(width, height)
        if int(opened.X) != int(layout.MARGIN) or int(opened.Y) != int(layout.TOP_SAFE):
            failures.append(f"{width}x{height}: open Quest menu is not fixed at upper-left")
        actual_size = (int(opened.Width), int(opened.Height))
        if actual_size != expected_size:
            failures.append(
                f"{width}x{height}: open size is {actual_size[0]}x{actual_size[1]}, "
                f"expected 50% size {expected_size[0]}x{expected_size[1]}"
            )
        if actual_size != tuple(value // 2 for value in original_size):
            failures.append(f"{width}x{height}: open geometry is not half of its original size")
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

    enlarged_type = {
        "HEADER_TEXT_SIZE": 15,
        "TOGGLE_TEXT_SIZE": 13,
        "SECTION_TEXT_SIZE": 13,
        "BODY_TEXT_SIZE": 14,
        "PROMINENT_TEXT_SIZE": 16,
        "TITLE_TEXT_SIZE": 18,
        "STEP_TEXT_SIZE": 15,
        "BUTTON_TEXT_SIZE": 13,
        "SMALL_TEXT_SIZE": 12,
    }
    for name, previous_size in enlarged_type.items():
        if int(getattr(layout, name)) <= previous_size:
            failures.append(f"{name} was not enlarged beyond its previous {previous_size}px size")

    source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/QuestBoard.lua").read_text(encoding="utf-8")
    contracts = {
        "panel.AnchorPoint = Vector2.new(0, 0)": "Quest panel is not top-left anchored",
        "QuestBoardLayout.open": "Quest menu is not using responsive upper-left geometry",
        "QuestBoardLayout.closed": "hidden header is not using upper-left geometry",
        "self._body.Visible = open": "Quest contents cannot be hidden",
        "self:SetOpen(not self._open)": "Quest header no longer toggles open/hidden",
        'self._bilingual("CLOSE", "ปิด")': "Quest menu has no visible close control",
        "geometry.Width < 260": "narrow half-size Quest menu does not use its compact header",
        "self._questIcon.Visible = not compactHeader": "compact header does not reclaim icon space",
        "QuestBoardLayout.HEADER_TEXT_SIZE": "Quest header is not using enlarged type",
        "QuestBoardLayout.TITLE_TEXT_SIZE": "chapter title is not using enlarged type",
        "QuestBoardLayout.STEP_TEXT_SIZE": "quest-step text is not using enlarged type",
        "AutomaticCanvasSize = Enum.AutomaticSize.Y": "Quest content does not expand its scrolling canvas",
        "label.AutomaticSize = Enum.AutomaticSize.Y": "wrapped Quest text cannot grow vertically",
        "label.TextWrapped = true": "Quest text no longer wraps inside the smaller window",
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
        "Quest board layout passed: exact 50% open geometry across 7 phone/desktop viewports, "
        "enlarged typography, wrapped scrolling content, safe-bar clearance, and open/hide toggle."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
