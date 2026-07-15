# CLAUDE.md

Cute Family Town is a bilingual Roblox family-roleplay game. Runtime Luau lives under `src/`; offline regression tests live under `scripts/`.

## Source of truth and Studio safety

**`src/` is authoritative. `CuteFamilyTown-Wildwood.rbxlx` is a generated copy.**

The place embeds every script so it can run in Studio without Rojo. After changing anything under `src/`, close Roblox Studio and run:

```powershell
python scripts/sync_place.py --place CuteFamilyTown-Wildwood.rbxlx --prune
python scripts/sync_place.py --check --place CuteFamilyTown-Wildwood.rbxlx
```

Rules learned the hard way:

- Close every Studio instance before syncing. An open Studio can later overwrite the synced place with its in-memory copy.
- If Studio asks to save changes after an external sync, choose **Don't Save** and reopen the place.
- Do not edit scripts inside Studio; the next source sync will replace those edits.
- Do not drive Studio with synthetic keystrokes or simulated clicks. Ask the user to perform interactive Studio actions.
- `sync_place.py --check` must pass before handoff.

## Current gameplay contracts

### Furniture purchase and placement

Furniture purchases are preview-first and server-authoritative:

1. The shop sends `BeginFurniturePurchase` for one item.
2. The client shows a movable/rotatable placement ghost. No coins or ownership change yet.
3. Only one purchase may be pending. The shop cannot reopen another Buy flow until the current ghost is confirmed or cancelled.
4. `BuyFurniture` sends the exact `x`, `z`, and `r` chosen by the player.
5. The server validates balance, capacity, wall/door clearance, overlap and the exact pose before spending.
6. A valid confirmation atomically spends, records ownership and places the item. `CancelFurniturePurchase` spends nothing.

Do not restore automatic/random final placement. `Placement.findFreeSpot` is only the ghost's initial pose. `PlaceFurniture` remains for an already-owned boxed item; `MoveFurniture` remains for a placed item.

### Home paint

Player paint changes exactly eight parts:

- Six structural walls: `BackWall`, `LeftWall`, `RightWall`, `FrontLeft`, `FrontRight`, `DoorHeader`.
- Two `RoofPlane` parts for the main roof.

Because a Roblox `BasePart` colour covers every face, these parts show the selected colour inside and outside. Everything else retains its authored palette: floor, ceiling, seams, posts, rails, roof courses/ridge, gables, porch, stone, windows, door, chimney, lanterns, plants, mailbox, garden, furniture and camp pieces. Do not rebuild `PaintParts` by scanning the whole home.

### Colour systems

- Architecture, landscape and world props use the centralized Bakery Bay palette in `WildwoodStyle.World`.
- The 51 furniture items use the 12-colour Woodland Canopy palette in `WildwoodStyle.Furniture`.
- Furniture brown `TimberTrim` is limited to structural trim; the catalogue test currently measures 11.6% by volume.
- Character, pet and UI rarity colours are deliberately separate.
- Do not add direct world/furniture RGB literals outside the centralized palettes.

## Invariants worth preserving

- **The server is authoritative.** Prices, pending purchases, placement, ownership, timers, rewards, cooldowns, quests and balances are decided in `GameService`. `DataService` never accepts a complete client profile.
- **Never hardcode text colour on a coloured fill.** Use `Theme.textOn(background)` so every pairing keeps WCAG AA contrast.
- **The client does no panel-layout arithmetic.** Shared geometry belongs in `Shared/HudLayout.lua`, where tests can exercise it without Roblox.
- **Content is data.** Furniture, seeds, outfits and rarities are tables in shared modules; adding an entry should not require a new action path.
- **Money cannot buy story progress.** `validate.py` checks that monetization never advances quests or chests.
- **Keep doorways walkable.** Client ghosts and server placement both use `Shared/Placement.lua`; the server must still revalidate every request.
- UI is mobile-first and bilingual. `bilingual(english, thai)` formats labels Thai-first with English underneath.

## Required verification

Run validation and all 22 regression tests before claiming completion:

```powershell
python scripts/validate.py CuteFamilyTown-Wildwood.rbxlx
python scripts/adventure_guild_test.py
python scripts/avatar_outfit_test.py
python scripts/bag_inventory_test.py
python scripts/bakery_bay_town_palette_test.py
python scripts/cafe_3d_test.py
python scripts/cafe_exterior_test.py
python scripts/camp_plan_test.py
python scripts/contrast_test.py
python scripts/environment_navigation_test.py
python scripts/furniture_test.py
python scripts/home_paint_test.py
python scripts/hud_layout_test.py
python scripts/mochi_cat_test.py
python scripts/pet_scale_test.py
python scripts/quest_board_layout_test.py
python scripts/quest_chain_test.py
python scripts/quest_story_test.py
python scripts/shop_test.py
python scripts/town_layout_test.py
python scripts/village_style_test.py
python scripts/walkability_test.py
python scripts/wildwood_redesign_test.py
```

The most relevant guards are:

- `adventure_guild_test.py`: balanced three-way centre, physical Guild actions, and server-enforced hub-only map travel.
- `furniture_test.py`: exclusive preview-before-purchase, exact confirmed pose, no charge on invalid/cancelled previews, collision, move/rotate/pack, persistence, all 51 items and XP.
- `home_paint_test.py`: exactly eight paint targets and every other cottage part unchanged across all swatches and rejoin.
- `bakery_bay_town_palette_test.py`: centralized Bakery Bay and Woodland Canopy colours.
- `walkability_test.py`: every enterable structure and the mountain remain traversable.
- `contrast_test.py` and `hud_layout_test.py`: readable, mobile-safe UI.

Only a final interactive or multiplayer playtest genuinely requires Roblox Studio.

## Repository state

- `.git/` exists but is not a working repository; normal `git` commands currently fail. Treat destructive changes carefully and consider initializing version control.
- `WorldService` generates the town, homes and Wildwood region at runtime. The place is primarily a baseplate plus embedded scripts.
