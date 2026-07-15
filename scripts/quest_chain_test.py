"""Drives the real GameService through the quest chains and checks the payouts.

The chain logic decides how much money players earn, so it is not something to
eyeball. This loads DataService, WorldService and GameService into a Lua
interpreter with a mocked Roblox API, plays a fake player through every step of
every chain, and asserts the coins, the step order, the banked chest, and that
the chest can only be claimed once.

Usage:
    python scripts/quest_chain_test.py [--verbose]
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:  # pragma: no cover
    print("This test needs the Lua bridge. Install it with: python -m pip install lupa")
    raise SystemExit(2)

sys.path.insert(0, str(Path(__file__).resolve().parent))

from walkability_test import SHARED_MODULES, luau_to_lua  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]

# Long enough to clear Config.RequestCooldown between requests.
COOLDOWN = 0.2


def boot():
    """Loads the real services against the mocked engine and returns a fake session."""
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path: Path, name: str):
        source = luau_to_lua(path.read_text(encoding="utf-8"))
        result = lua.eval(f"function(s) return load(s, {name!r}) end")(source)
        if isinstance(result, tuple):
            raise SystemExit(f"Could not parse {path}: {result[1]}")
        return result

    mock = load(ROOT / "scripts/robloxmock.lua", "@robloxmock")()
    mock.install(lua.globals())

    shared = ROOT / "src/ReplicatedStorage/Shared"
    modules = {}
    for name in SHARED_MODULES:
        modules[name] = load(shared / f"{name}.lua", f"@{name}")()
        mock.registerModule(name, modules[name])

    services = ROOT / "src/ServerScriptService/Services"
    data_service = load(services / "DataService.lua", "@DataService")()
    world_service = load(services / "WorldService.lua", "@WorldService")()
    game_service = load(services / "GameService.lua", "@GameService")()

    toasts = []
    lua.globals().recordToast = lambda _player, message: toasts.append(str(message))
    remotes = lua.eval(
        "{ Toast = { FireClient = function(_, p, m) recordToast(p, m) end },"
        "  StateChanged = { FireClient = function() end },"
        "  Request = {} }"
    )

    data = data_service.new()
    world = world_service.new(remotes)
    game = game_service.new(data, world, remotes)

    player = lua.globals().Instance.new("Player")
    player.Name = "Tester"
    player.DisplayName = "Tester"
    player.UserId = 7
    data.Load(data, player)
    world.AssignHome(world, player)

    return lua, modules, data, game, player, toasts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    lua, modules, data, game, player, toasts = boot()
    catalog = modules["Catalog"]
    profile = data.Get(data, player)
    failures: list[str] = []

    chains = catalog.QuestChains
    chain_count = len(chains)
    if args.verbose:
        print(f"{chain_count} quest chains defined\n")

    # A fresh player starts on the first step of the first chain.
    if profile.Quests.ChainIndex != 1 or profile.Quests.Step != 1:
        failures.append("a new player does not start at the first step of the first chain")

    total_expected = 0

    for chain_index in range(1, chain_count + 1):
        chain = chains[chain_index]
        steps = chain.Steps
        step_count = len(steps)

        for step_index in range(1, step_count + 1):
            step = steps[step_index]

            if profile.Quests.ChainIndex != chain_index or profile.Quests.Step != step_index:
                failures.append(
                    f"{chain.Id}: expected to be on step {step_index} of chain {chain_index}, "
                    f"but the profile is on step {profile.Quests.Step} of chain {profile.Quests.ChainIndex}"
                )
                return report(failures)

            before = profile.Coins

            # An unrelated action must not move the chain along.
            stray = profile.Quests.Progress
            game._progressChain(game, player, "NotARealAction", 1)
            if profile.Quests.Progress != stray:
                failures.append(f"{chain.Id} step {step_index}: an unrelated action advanced the chain")

            # Do exactly what the step asks, one at a time.
            for tick in range(1, int(step.Target) + 1):
                game._progressChain(game, player, step.Action, 1)
                expected = min(tick, int(step.Target))
                if tick < int(step.Target) and profile.Quests.Progress != expected:
                    failures.append(
                        f"{chain.Id} step {step_index}: progress is {profile.Quests.Progress}, expected {expected}"
                    )

            earned = profile.Coins - before
            total_expected += int(step.Reward)
            if earned != int(step.Reward):
                failures.append(
                    f"{chain.Id} step {step_index}: paid {earned} coins, the step promises {int(step.Reward)}"
                )

            if args.verbose:
                print(f"  {chain.Id:16} step {step_index}/{step_count}  {str(step.Description):38} +{int(step.Reward)}")

        # The chain is done: the chest is banked, not paid out.
        if profile.Quests.PendingBonus != int(chain.Bonus):
            failures.append(
                f"{chain.Id}: finishing the chain banked {profile.Quests.PendingBonus}, expected {int(chain.Bonus)}"
            )
        if profile.Quests.ChainsCompleted != chain_index:
            failures.append(f"{chain.Id}: ChainsCompleted is {profile.Quests.ChainsCompleted}, expected {chain_index}")

        # Claim it. The server rate-limits requests, so wait out the cooldown:
        # this must go through the real Handle path, guards and all.
        time.sleep(COOLDOWN)
        before = profile.Coins
        result = game.Handle(game, player, "ClaimChainBonus", lua.table())
        if not result.ok:
            failures.append(f"{chain.Id}: the chest would not open: {result.message}")
        claimed = profile.Coins - before
        total_expected += int(chain.Bonus)
        if claimed != int(chain.Bonus):
            failures.append(f"{chain.Id}: the chest paid {claimed}, expected {int(chain.Bonus)}")

        # And it must not pay twice. Wait out the cooldown again, so a rejection
        # here is the empty-chest guard doing its job and not the rate limiter.
        time.sleep(COOLDOWN)
        before = profile.Coins
        again = game.Handle(game, player, "ClaimChainBonus", lua.table())
        if again.ok or profile.Coins != before:
            failures.append(f"{chain.Id}: the chest could be claimed twice - players could farm it")

        if args.verbose:
            print(f"  {chain.Id:16} CHEST +{int(chain.Bonus)}   coins now {profile.Coins}\n")

    # Every chain is finished.
    if profile.Quests.ChainIndex != chain_count + 1:
        failures.append("after the last chain the player is not marked as having finished them all")
    game._progressChain(game, player, "GardenHarvest", 1)
    if profile.Quests.PendingBonus != 0:
        failures.append("a finished questline kept awarding chests")

    if profile.Quests.TotalEarned != total_expected:
        failures.append(
            f"TotalEarned is {profile.Quests.TotalEarned}, but the chains paid out {total_expected}"
        )

    if not failures:
        print(
            f"Quest chains passed: {chain_count} chains, "
            f"{sum(len(chains[i].Steps) for i in range(1, chain_count + 1))} steps, "
            f"{total_expected} coins paid out in the right order, and no chest can be claimed twice."
        )
        return 0
    return report(failures)


def report(failures: list[str]) -> int:
    print("Quest chains failed:")
    for failure in failures:
        print(f"  - {failure}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
