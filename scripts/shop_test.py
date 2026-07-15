"""Checks the Robux shop grants each purchase exactly once.

This is the only code in the project that touches real money, and Roblox will
re-deliver a receipt until the game confirms it. A handler that pays out every
time it sees a receipt hands out free coins; a handler that refuses forever
charges a player for nothing. Both are tested here against the real ShopService.

Usage:
    python scripts/shop_test.py [--verbose]
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

TEST_PRODUCT = 555001
TEST_COINS = 1200


def boot():
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path: Path, name: str):
        result = lua.eval(f"function(s) return load(s, {name!r}) end")(luau_to_lua(path.read_text(encoding="utf-8")))
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

    # Stand in a real product id: shipped config has 0, which keeps the shop off.
    modules["Config"].Monetization.CoinPacks[1].ProductId = TEST_PRODUCT
    modules["Config"].Monetization.CoinPacks[1].Coins = TEST_COINS

    services = ROOT / "src/ServerScriptService/Services"
    data = load(services / "DataService.lua", "@DataService")().new()
    shop = load(services / "ShopService.lua", "@ShopService")()

    remotes = lua.eval(
        "{ Toast = { FireClient = function() end },"
        "  StateChanged = { FireClient = function() end } }"
    )

    player = lua.globals().Instance.new("Player")
    player.Name = "Buyer"
    player.DisplayName = "Buyer"
    player.UserId = 42
    data.Load(data, player)

    # Players:GetPlayerByUserId must find our buyer.
    players = lua.globals().game.GetService(None, "Players")
    players.GetPlayerByUserId = lambda _self, user_id: player if int(user_id) == 42 else None

    instance = shop.new(data, remotes)
    return lua, modules, data, instance, player


def receipt(lua, purchase_id: str, product_id: int, spent: int = 25):
    table = lua.table()
    table.PlayerId = 42
    table.PurchaseId = purchase_id
    table.ProductId = product_id
    table.CurrencySpent = spent
    return table


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    lua, modules, data, shop, player = boot()
    profile = data.Get(data, player)
    failures: list[str] = []

    granted = "Enum.ProductPurchaseDecision.PurchaseGranted"

    def decision(result) -> str:
        return f"Enum.ProductPurchaseDecision.{result.Name}"

    # The shop stays hidden until a product id is configured.
    config = modules["Config"]
    saved_id = config.Monetization.CoinPacks[1].ProductId
    config.Monetization.CoinPacks[1].ProductId = 0
    if shop.IsConfigured():
        failures.append("the shop reports itself configured with no product ids set")
    config.Monetization.CoinPacks[1].ProductId = saved_id
    if not shop.IsConfigured():
        failures.append("the shop stays hidden even with a product id set")

    # A purchase pays out once.
    start = profile.Coins
    first = shop._processReceipt(shop, receipt(lua, "receipt-A", TEST_PRODUCT))
    if decision(first) != granted:
        failures.append(f"a valid purchase was not granted: {decision(first)}")
    if profile.Coins - start != TEST_COINS:
        failures.append(f"purchase paid {profile.Coins - start} coins, expected {TEST_COINS}")

    # Roblox re-delivers the same receipt. It must be confirmed, not paid again.
    before = profile.Coins
    repeat = shop._processReceipt(shop, receipt(lua, "receipt-A", TEST_PRODUCT))
    if decision(repeat) != granted:
        failures.append("a re-delivered receipt was not confirmed, so Roblox would keep resending it forever")
    if profile.Coins != before:
        failures.append(
            f"a re-delivered receipt paid out AGAIN (+{profile.Coins - before} coins) - players get free coins"
        )

    # A different receipt for the same product is a genuine second purchase.
    before = profile.Coins
    second = shop._processReceipt(shop, receipt(lua, "receipt-B", TEST_PRODUCT))
    if decision(second) != granted or profile.Coins - before != TEST_COINS:
        failures.append("a genuine second purchase of the same pack did not pay out")

    # An unknown product must not pay anything.
    before = profile.Coins
    unknown = shop._processReceipt(shop, receipt(lua, "receipt-C", 999999))
    if decision(unknown) == granted:
        failures.append("an unknown product id was granted")
    if profile.Coins != before:
        failures.append("an unknown product id paid out coins")

    # Money must never buy quest progress.
    if profile.Quests.PendingBonus != 0 or profile.Quests.ChainIndex != 1 or profile.Quests.Step != 1:
        failures.append("buying coins moved the player's quest chain along - quests must be earned")

    if args.verbose:
        print(f"  coins after two real purchases: {profile.Coins}")
        print(f"  robux recorded as spent:        {profile.Shop.RobuxSpent}")
        print(f"  receipts remembered:            {len(dict(profile.Shop.Receipts))}")
        print(f"  quest chain untouched:          chain {profile.Quests.ChainIndex} step {profile.Quests.Step}")

    if profile.Shop.RobuxSpent != 50:
        failures.append(f"RobuxSpent is {profile.Shop.RobuxSpent}, expected 50 from two 25-Robux purchases")

    if failures:
        print("Robux shop failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Robux shop passed: purchases pay out once, re-delivered receipts are confirmed "
        "without paying again, unknown products are refused, and money cannot advance a quest chain."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
