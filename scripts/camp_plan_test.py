"""Proves a child can find out what the camp upgrade wants.

The reported bug: a player at camp Level 5 could not proceed. The quest step said
"Upgrade your camp" and nothing else, and when the server refused the build it
named exactly one missing resource - picked out of a Lua `pairs()` loop, which has
no defined iteration order. So a player short of Wildwood, Crystal and Fish was
told about one of the three, went and collected it, came back, and was told about
another. Nothing in the game ever showed the whole list.

This test loads the real Catalog, the real CampPlan and the real GameService
against a mocked engine and asserts, for the Level 5 player specifically:

  - the requirement list names every item the Adventure Center costs,
  - it carries both the amount needed and the amount held,
  - it comes back in the same order every time,
  - the server's refusal names *all* the missing items, not one,
  - and the upgrade goes through the moment the last item is collected.

It also asserts the old behaviour fails it, so a passing run means something.

Usage:
    python scripts/camp_plan_test.py [--verbose]
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

from quest_chain_test import boot  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]

# The resource icons are emoji, and the Windows console still defaults to cp1252,
# which cannot encode them. Print UTF-8 rather than quietly dropping the icons the
# whole feature is about.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def lua_table(lua, mapping):
    table = lua.table()
    for key, value in mapping.items():
        table[key] = value
    return table


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    lua, modules, data, game, player, toasts = boot()
    catalog = modules["Catalog"]
    plan_module = modules["CampPlan"]
    profile = data.Get(data, player)
    failures: list[str] = []

    order = [str(name) for name in dict(catalog.AdventureResourceOrder).values()]

    # Every resource must carry a picture and a place to find it: this game is
    # played by five-year-olds and the label alone is not readable to them.
    for resource_id in order:
        resource = catalog.AdventureResources[resource_id]
        if not resource.Icon:
            failures.append(f"{resource_id} has no Icon, so a child who cannot read cannot identify it")
        if not resource.FoundIn:
            failures.append(f"{resource_id} does not say where it is found")

    # The player who filed the bug: camp Level 5, so the next build is the
    # Adventure Center - Wood 25, Stone 15, Crystal 6, Fish 5.
    level = 5
    final = catalog.CampLevels[level + 1]
    cost = {str(k): int(v) for k, v in dict(final.Cost).items()}
    if args.verbose:
        print(f"Level {level} -> {final.Name}: {cost}\n")

    # An empty bag. Nothing is met, and every item of the cost must be listed.
    empty = lua_table(lua, {name: 0 for name in order})
    plan = plan_module.requirements(level, empty)

    if plan is None:
        return report(["CampPlan.requirements returned nothing for a Level 5 player"])

    items = [plan.Items[i] for i in range(1, len(plan.Items) + 1)]
    listed = {str(item.Id): int(item.Need) for item in items}

    if listed != cost:
        failures.append(
            f"the requirement list is {listed}, but the {final.Name} costs {cost} - "
            "the player cannot see what the build actually wants"
        )

    # Fixed order. `pairs()` over the cost table is what made the old error message
    # unpredictable, so the list must follow the catalog's own order every time.
    expected_order = [name for name in order if name in cost]
    actual_order = [str(item.Id) for item in items]
    if actual_order != expected_order:
        failures.append(f"requirements came back as {actual_order}, expected the catalog order {expected_order}")

    for item in items:
        if int(item.Have) != 0 or int(item.Short) != int(item.Need) or item.Met:
            failures.append(f"{item.Id}: an empty bag should read 0/{int(item.Need)} and not be met")

    if plan.Ready or int(plan.Missing) != len(cost):
        failures.append(f"an empty bag reports Ready={plan.Ready}, Missing={int(plan.Missing)}")

    # The refusal message must name everything that is missing. This is the heart
    # of the bug: one item at a time is a guessing game.
    text = str(plan_module.missingText(level, empty, False))
    for resource_id in cost:
        name = str(catalog.AdventureResources[resource_id].DisplayName)
        if name not in text:
            failures.append(f'the "still need" message does not mention {name}: "{text}"')
    if args.verbose:
        print(f'  empty bag -> "{text}"\n')

    # A half-full bag: what is met drops off the message, what is short stays on
    # it with the right number.
    partial = lua_table(lua, {"Wood": 25, "Stone": 15, "Herbs": 0, "Fish": 1, "Crystal": 2})
    half = plan_module.requirements(level, partial)
    half_items = {str(half.Items[i].Id): half.Items[i] for i in range(1, len(half.Items) + 1)}

    if not half_items["Wood"].Met or not half_items["Stone"].Met:
        failures.append("a bag with the full 25 Wildwood and 15 Stone does not mark them as met")
    if int(half_items["Crystal"].Short) != 4 or int(half_items["Fish"].Short) != 4:
        failures.append(
            f"short counts are wrong: Crystal {int(half_items['Crystal'].Short)} (expected 4), "
            f"Fish {int(half_items['Fish'].Short)} (expected 4)"
        )

    half_text = str(plan_module.missingText(level, partial, False))
    if "Wildwood" in half_text or "Mountain Stone" in half_text:
        failures.append(f'the message still asks for items the player already has: "{half_text}"')
    if "Cave Crystal" not in half_text or "River Fish" not in half_text:
        failures.append(f'the message drops an item the player is still short of: "{half_text}"')
    if args.verbose:
        print(f'  half-full bag -> "{half_text}"\n')

    # Now drive the real server. A Level 5 player with an empty bag is refused, and
    # the refusal must name every missing item - not one of them.
    profile.Adventure.CampLevel = level
    for resource_id in order:
        profile.Adventure.Resources[resource_id] = 0

    ok, message = game._handleAction(game, player, "AdventureUpgradeCamp", lua.table())
    message = str(message)
    if ok:
        failures.append("the server let a player with an empty bag build the Adventure Center")
    named = [rid for rid in cost if str(catalog.AdventureResources[rid].DisplayName) in message]
    if len(named) != len(cost):
        failures.append(
            f"the server's refusal names {len(named)} of the {len(cost)} missing items: \"{message}\". "
            "This is the reported bug: the player is told about one thing at a time."
        )
    if args.verbose:
        print(f'  server refusal -> "{message}"\n')

    # Fill the bag exactly. The build must now go through, spend the resources, and
    # raise the camp - nothing left over, nothing still owed.
    for resource_id, amount in cost.items():
        profile.Adventure.Resources[resource_id] = amount

    ok, message = game._handleAction(game, player, "AdventureUpgradeCamp", lua.table())
    if not ok:
        failures.append(f"a player carrying exactly the cost was still refused: {message}")
    if int(profile.Adventure.CampLevel) != level + 1:
        failures.append(f"the camp is still Level {int(profile.Adventure.CampLevel)} after a successful build")
    for resource_id, amount in cost.items():
        left = int(profile.Adventure.Resources[resource_id])
        if left != 0:
            failures.append(f"building spent the wrong amount of {resource_id}: {left} left, expected 0")
    if args.verbose:
        print(f'  paid in full -> "{message}"  camp is now Level {int(profile.Adventure.CampLevel)}\n')

    # The camp is fully built: there is no next level, and the UI is told so rather
    # than being handed an empty checklist to render.
    if plan_module.requirements(len(dict(catalog.CampLevels)), empty) is not None:
        failures.append("a fully built camp still reports an upgrade to work towards")

    # Teeth: the old message named a single resource. If naming one item could pass
    # this test, the test could not have caught the bug it was written for.
    single = str(catalog.AdventureResources["Stone"].DisplayName)
    if len([rid for rid in cost if str(catalog.AdventureResources[rid].DisplayName) in single]) == len(cost):
        failures.append("naming one resource satisfies this test - it cannot detect the reported bug")

    if failures:
        print(f"Camp plan FAILED ({len(failures)} problem(s)):")
        for line in failures:
            print(f"  - {line}")
        return 1

    print(
        f"Camp plan passed: a Level 5 player is shown all {len(cost)} items the {final.Name} needs "
        f"({', '.join(f'{k} {v}' for k, v in sorted(cost.items()))}), with have/need counts, in a fixed "
        "order, and the server's refusal names every missing item at once."
    )
    return 0


def report(failures: list[str]) -> int:
    print("Camp plan failed:")
    for failure in failures:
        print(f"  - {failure}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
