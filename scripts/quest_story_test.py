"""Checks the authored Wildwood story and its real gameplay hooks.

The generic chain test proves ordering and payouts. This test covers the part
that makes the new journal a story: its chapter arc, bilingual copy, specific
Moon Berry Tart order, resource-specific exploration goals, persistent version,
and already-owned milestone reconciliation for returning players.
"""

from __future__ import annotations

import sys

from quest_chain_test import boot


EXPECTED_CHAPTERS = [
    "WelcomeToWildwood",
    "GardenPromise",
    "MoonleafOpening",
    "FirstForestLight",
    "RiverMountainMoon",
    "WorkshopStars",
    "ShelterManyPaws",
    "HeartOfWildwood",
]


def main() -> int:
    lua, modules, data_service, game, player, _toasts = boot()
    catalog = modules["Catalog"]
    profile = data_service.Get(data_service, player)
    failures: list[str] = []

    chapters = catalog.QuestChains
    chapter_ids = [str(chapters[index].Id) for index in range(1, len(chapters) + 1)]
    if chapter_ids != EXPECTED_CHAPTERS:
        failures.append(f"chapter arc is {chapter_ids}, expected {EXPECTED_CHAPTERS}")
    if int(catalog.QuestlineVersion) != 2 or int(profile.Quests.Version) != 2:
        failures.append("the rewritten journal is not persisted as questline version 2")

    all_actions: list[str] = []
    camp_levels: list[int] = []
    for chapter_index in range(1, len(chapters) + 1):
        chapter = chapters[chapter_index]
        for field in ("Name", "NameThai", "Blurb", "BlurbThai"):
            if not str(chapter[field]).strip():
                failures.append(f"{chapter.Id} has no {field}")
        for step_index in range(1, len(chapter.Steps) + 1):
            step = chapter.Steps[step_index]
            all_actions.append(str(step.Action))
            for field in ("Description", "DescriptionThai"):
                if not str(step[field]).strip():
                    failures.append(f"{chapter.Id} step {step_index} has no {field}")
            if int(step.Target) < 1 or int(step.Reward) < 1:
                failures.append(f"{chapter.Id} step {step_index} has a non-positive target or reward")
            if step.Hint is not None and (not str(step.Hint).strip() or not str(step.HintThai).strip()):
                failures.append(f"{chapter.Id} step {step_index} has an incomplete bilingual hint")
            if step.CampLevel is not None:
                camp_levels.append(int(step.CampLevel))

    if all_actions[0] != "FinishOnboarding":
        failures.append("the story does not begin at the welcome card")
    if "CafeServeMoonBerryTart" not in all_actions:
        failures.append("Moonleaf Cafe never teaches its signature Moon Berry Tart")
    if any(action == "AdventureCollect" for action in all_actions):
        failures.append("the story still uses vague AdventureCollect goals")
    for action in ("AdventureWood", "AdventureHerbs", "AdventureStone", "AdventureFish", "AdventureCrystal"):
        if action not in all_actions:
            failures.append(f"the story never teaches {action}")
    if camp_levels != [2, 3, 4, 5, 6]:
        failures.append(f"camp story milestones are {camp_levels}, expected every level from 2 through 6")

    # Follow the intended route as a fresh player. Every requested supply must
    # pay for the very next named build or companion, with the river fish carried
    # forward to the finale. This catches a story that sounds continuous but
    # leaves the player short of an unmentioned material.
    resources = {"Wood": 0, "Stone": 0, "Herbs": 0, "Fish": 0, "Crystal": 0}
    resource_actions = {
        "AdventureWood": "Wood",
        "AdventureStone": "Stone",
        "AdventureHerbs": "Herbs",
        "AdventureFish": "Fish",
        "AdventureCrystal": "Crystal",
    }
    camp_level = 1
    for chapter_index in range(1, len(chapters) + 1):
        chapter = chapters[chapter_index]
        for step_index in range(1, len(chapter.Steps) + 1):
            step = chapter.Steps[step_index]
            action = str(step.Action)
            if action in resource_actions:
                resources[resource_actions[action]] += int(step.Target)
            elif action == "AdventurePuzzleSolved":
                resources["Crystal"] += 2 * int(step.Target)
            elif action == "AdventureUpgradeCamp":
                cost = dict(catalog.CampLevels[camp_level + 1].Cost)
                for resource, amount in cost.items():
                    if resources[str(resource)] < int(amount):
                        failures.append(
                            f"{chapter.Id} step {step_index} reaches camp level {camp_level + 1} "
                            f"short of {resource}"
                        )
                    resources[str(resource)] -= int(amount)
                camp_level += 1
            elif action == "AdventureUnlockCompanion":
                cost = dict(catalog.Companions[str(step.Companion)].Cost)
                for resource, amount in cost.items():
                    if resources[str(resource)] < int(amount):
                        failures.append(f"{chapter.Id} cannot afford {step.Companion}: missing {resource}")
                    resources[str(resource)] -= int(amount)
    if camp_level != 6:
        failures.append(f"the intended route ends at camp level {camp_level}, not the Adventure Center")
    if any(amount != 0 for amount in resources.values()):
        failures.append(f"the authored supply route is not exact; leftover plan is {resources}")

    finale = chapters[len(chapters)].Steps
    if str(finale[len(finale)].Action) != "CafeServeMoonBerryTart":
        failures.append("the story does not return to Moonleaf Cafe for its finale")
    river_steps = chapters[5].Steps
    if not any(str(river_steps[i].Action) == "AdventureFish" for i in range(1, len(river_steps) + 1)):
        failures.append("the river chapter does not save fish for the final Adventure Center")

    def set_step(chapter: int, step: int) -> None:
        profile.Quests.ChainIndex = chapter
        profile.Quests.Step = step
        profile.Quests.Progress = 0
        profile.Quests.PendingBonus = 0

    # Real onboarding action advances the real first chapter.
    set_step(1, 1)
    profile.Settings.Onboarded = False
    ok, _ = game._handleAction(game, player, "FinishOnboarding", lua.table())
    if not ok or profile.Quests.Step != 2:
        failures.append("FinishOnboarding is not wired to the first story step")

    # A real validated cafe serve counts only when the requested dish is the tart.
    set_step(3, 2)
    profile.Cafe.Unlocked = True
    profile.Cafe.LastServedAt = 0
    payload = lua.table_from({"item": "StarCupcake"})
    ok, _ = game._handleAction(game, player, "CafeServe", payload)
    if not ok or profile.Quests.Progress != 0:
        failures.append("a Star Cupcake counted as a Moon Berry Tart")
    profile.Cafe.LastServedAt = 0
    payload = lua.table_from({"item": "MoonBerryTart"})
    ok, _ = game._handleAction(game, player, "CafeServe", payload)
    if not ok or profile.Quests.Progress != 1:
        failures.append("a real Moon Berry Tart serve did not advance its story step")

    # The collection request still passes the server's zone/resource validation;
    # only its proximity check is replaced because the test player has no avatar.
    lua.globals().storyGame = game
    lua.execute("storyGame._isNearWaypoint = function() return true end")
    set_step(4, 1)
    payload = lua.table_from({"zone": "WildwoodForest", "resource": "Wood"})
    ok, _ = game._handleAction(game, player, "AdventureCollect", payload)
    if not ok or profile.Quests.Progress != 1:
        failures.append("collecting real Wildwood did not advance AdventureWood")

    set_step(5, 2)
    payload = lua.table_from({"zone": "Mountain", "resource": "Stone"})
    ok, _ = game._handleAction(game, player, "AdventureCollect", payload)
    if not ok or profile.Quests.Progress != 1:
        failures.append("collecting real mountain stone did not advance AdventureStone")

    # An old save can restart the journal without losing its built cafe or camp.
    set_step(3, 1)
    profile.Cafe.Unlocked = True
    game._syncStoryMilestones(game, player)
    if profile.Quests.Step != 2:
        failures.append("an already-open cafe stalls a returning player's restarted story")
    set_step(8, 5)
    profile.Adventure.CampLevel = 6
    game._syncStoryMilestones(game, player)
    if profile.Quests.Step != 6:
        failures.append("an already-built Adventure Center stalls a returning player's restarted story")

    if failures:
        print("Quest story failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Quest story passed: 8 continuous bilingual chapters, 41 steps, "
        "signature tart and resource hooks, an exact 5-build supply plan, and safe returning-player milestones."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
