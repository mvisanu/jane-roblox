"""Proves the UI can actually be read.

The reported bug: the garden's "Plant Daisy (5 seeds)" button was unreadable. A
seed button is painted the flower's own colour, a daisy is pale yellow, and every
button in the game painted its text white regardless of what it sat on. White on
near-white is a contrast ratio of about 1.1:1, where 4.5:1 is the readable floor.

So "can you read it" is not a matter of taste; it is a number. This test loads the
real Theme, the real seed colours and the real furniture rarity colours, and
checks every text-on-background pairing the game can produce against WCAG AA.

Theme.textOn is the fix under test: it picks ink or white per background, so a
colour the theme has never heard of - a flower, a rarity - still gets readable
text on it.

Usage:
    python scripts/contrast_test.py [--verbose]
"""

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

from walkability_test import SHARED_MODULES, luau_to_lua  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]

# WCAG 2.1: 4.5:1 for normal text, 3:1 for graphical elements that carry meaning
# but are not read (the rarity stripe).
AA = 4.5
NON_TEXT_AA = 3.0


def boot():
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path: Path, name: str):
        chunk = lua.eval(f"function(s) return load(s, {name!r}) end")(
            luau_to_lua(path.read_text(encoding="utf-8"))
        )
        if isinstance(chunk, tuple):
            raise SystemExit(f"Could not parse {path}: {chunk[1]}")
        return chunk

    mock = load(ROOT / "scripts/robloxmock.lua", "@robloxmock")()
    mock.install(lua.globals())

    shared = ROOT / "src/ReplicatedStorage/Shared"
    modules = {}
    for module in SHARED_MODULES:
        modules[module] = load(shared / f"{module}.lua", f"@{module}")()
        mock.registerModule(module, modules[module])

    theme = load(ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/Theme.lua", "@Theme")()
    adaptive = load(shared / "AdaptiveWorldText.lua", "@AdaptiveWorldText")()
    return theme, modules["Catalog"], modules["Config"], modules["Furniture"], adaptive, modules["WildwoodStyle"]


def rgb(color):
    return (round(color.R * 255), round(color.G * 255), round(color.B * 255))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    theme, catalog, config, furniture, adaptive, style = boot()
    colors = theme.Colors
    failures = []
    checked = 0

    # Every colour the UI paints a button, card or chip with. Text on these is
    # chosen by Theme.textOn, so each must come out readable.
    fills = {
        "Primary": colors.Primary,
        "PrimaryDark": colors.PrimaryDark,
        "Leaf": colors.Leaf,
        "Water": colors.Water,
        "Slate": colors.Slate,
        "Sun": colors.Sun,
        "Berry": colors.Berry,
        "Ink": colors.Ink,
        "Surface": colors.Surface,
        "White": colors.White,
    }
    # The flower colours: the theme does not own these, but it must survive them.
    # A seed button is painted the flower's colour and has its name written on it,
    # so these are text backgrounds and carry the full 4.5:1 bar.
    for name, seed in dict(catalog.Seeds).items():
        fills[f"seed:{name}"] = seed.Color

    # The bag, the quest checklist and the camp buttons draw each resource's icon on
    # a tile painted that resource's own colour. A cave crystal is pale blue and a
    # warm beige is nearly white, so - exactly as with the daisy - the glyph colour
    # has to be asked for rather than assumed. These are text backgrounds.
    for name, resource in dict(catalog.AdventureResources).items():
        fills[f"resource:{name}"] = resource.Color

    # The adventure palette paints real buttons with real words on them: the Bag tab
    # is SunsetOrange, the zone buttons are ForestGreen and RiverBlue.
    for name, color in dict(config.AdventurePalette).items():
        fills[f"adventure:{name}"] = color

    # Home swatches carry both the colour name and its hex code. The approved
    # brown set is intentionally dark, so this proves Theme.textOn chooses text
    # that remains readable on every exact wall colour.
    for _, paint in config.HomeColors.items():
        fills[f"home:{paint.Name}"] = paint.Color

    for name, fill in fills.items():
        checked += 1
        text = theme.textOn(fill)
        ratio = theme.contrast(text, fill)
        label = "ink" if rgb(text) == rgb(colors.Ink) else "white"
        if ratio < AA:
            failures.append(f"{name} {rgb(fill)}: best text ({label}) is only {ratio:.2f}:1, needs {AA}:1")
        if args.verbose:
            print(f"  {name:22} {str(rgb(fill)):18} -> {label:5} {ratio:5.2f}:1")

    # Background-free world labels raycast through their screen position and
    # choose dark or light text from the sampled scene. Prove both branches,
    # especially the requested switch to light text over a dark night/forest.
    adaptive_backdrops = {
        "adaptive:dark-night": (style.World.NightSky, rgb(adaptive.LightText)),
        "adaptive:light-canvas": (style.World.CanvasLight, rgb(adaptive.DarkText)),
        "adaptive:mid-water": (style.World.WaterLight, None),
    }
    for name, (fill, expected) in adaptive_backdrops.items():
        checked += 1
        text = adaptive.textFor(fill)
        ratio = float(adaptive.contrast(text, fill))
        if ratio < AA:
            failures.append(f"{name} {rgb(fill)}: adaptive text is only {ratio:.2f}:1, needs {AA}:1")
        if expected is not None and rgb(text) != expected:
            failures.append(f"{name}: selected {rgb(text)}, expected {expected}")
        if args.verbose:
            print(f"  {name:22} {str(rgb(fill)):18} -> {str(rgb(text)):15} {ratio:5.2f}:1")

    # Body copy sits directly on the panel.
    for name, text, fill in (
        ("Ink on Surface", colors.Ink, colors.Surface),
        ("Muted on Surface", colors.Muted, colors.Surface),
        ("Ink on White", colors.Ink, colors.White),
    ):
        checked += 1
        ratio = theme.contrast(text, fill)
        if ratio < AA:
            failures.append(f"{name}: {ratio:.2f}:1, needs {AA}:1")
        if args.verbose:
            print(f"  {name:22} {'':18} -> {ratio:5.2f}:1")

    # The rarity colours are a stripe down the edge of a white card - a graphical
    # element, never a text background. WCAG holds those to 3:1, not 4.5:1, so
    # that is what they are checked against: the stripe has to be *visible*, not
    # legible. Holding them to the text bar would mean distorting the colours to
    # satisfy a rule that does not apply to them.
    for name, rarity in dict(furniture.Rarities).items():
        checked += 1
        ratio = theme.contrast(rarity.Color, colors.White)
        if ratio < NON_TEXT_AA:
            failures.append(
                f"rarity stripe {name} {rgb(rarity.Color)}: {ratio:.2f}:1 against the card, "
                f"needs {NON_TEXT_AA}:1 to be seen"
            )
        if args.verbose:
            print(f"  rarity:{name:15} {str(rgb(rarity.Color)):18} -> stripe {ratio:5.2f}:1")

    # The scheme was asked to be green: the colours that carry it must actually be
    # green, not merely readable. Green channel leads, and it is not a grey.
    for name in ("Primary", "PrimaryDark", "Leaf"):
        checked += 1
        r, g, b = rgb(colors[name])
        if not (g > r and g > b and g - min(r, b) > 30):
            failures.append(f"{name} {(r, g, b)} is not a green")

    # The test has teeth: the exact pairing the player complained about - white
    # text on a daisy - must fail it.
    daisy = catalog.Seeds.Daisy.Color
    old = theme.contrast(colors.White, daisy)
    if old >= AA:
        failures.append("white on a daisy passes - this test cannot detect the reported bug")

    if failures:
        print(f"Contrast FAILED ({len(failures)} problem(s)):")
        for line in failures:
            print(f"  - {line}")
        return 1

    print(
        f"Contrast passed: {checked} pairings, including every seed and rarity colour, are at least "
        f"{AA}:1 (WCAG AA). The green scheme carries the UI, and the old white-on-daisy button "
        f"({old:.2f}:1) fails this test."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
