# Cute Family Town: Wildwood Adventure

A playable Roblox family-roleplay and creator-adventure MVP built from `goal.md` and `prompt.md`. The town and Wildwood region are generated at runtime, so a blank Roblox place becomes playable as soon as this project is synced into Studio.

## What is playable

- Eight automatically assigned private homes with five paint colors and a server-validated furniture shop/placement loop.
- An XP and level system: a star badge and XP bar float over every player's head, XP is earned from gardening, pets, the café, quests, and adventuring, and a level-up pops the badge and floats "Level Up!" over the player.
- A 51-piece furniture shop across Living Room, Bedroom, Kitchen, Bathroom, Garden, and Decoration, with a rotating 3D preview before you spend a coin, search, category filters, favourites, and Common/Rare/Epic/Legendary rarity colours.
- Buying furniture first opens a snapping-grid ghost: the player moves or rotates it, then confirms BUY & PLACE. Coins are charged only for that server-validated pose, and another purchase cannot start until the current preview is placed or cancelled.
- Four garden patches per home with Daisy, Tulip, and Lavender seeds, watering, growth timers, harvesting, and coin rewards.
- A free black voxel cat named Mochi—with a cuboid head and body, triangular ears, block paws, stepped tail, pale-pink triangle nose, and cat-shaped mouth—that follows the player, eats, plays, bathes, gains XP, and levels up.
- A Family Café that can be opened, serves visible NPC guests, upgrades, and hires up to three NPC helpers.
- Three friendly outfit palettes applied to the live avatar.
- A generated town with a plaza, café, flower shop, pet shop, school, playground, park/lake, beach, forest, roads, lights, and player homes.
- Every home and building is a real interior you walk in and out of: the shops are furnished rooms with their counters inside, the Mystery Cave is a chamber holding the crystals and the rune puzzle, and the camp tree house, cottage, and Adventure Center are enterable (the tree house has stairs up to its deck).
- Sunrise Mountain is climbed on foot, up five flights of stone steps, with the stone pile on a terrace along the way and the crystal waiting on the summit.
- The town is built as a timber-framed village drawn from `images/home.png`: dark beams and diagonal braces over cream plaster, pitched terracotta shingle roofs with overhanging eaves, stone footings, balconies, hanging lanterns, banners, and late-afternoon light.
- Place names are small, fade in as you walk up to them, and can be switched off from the top bar.
- A minimap in the top-right corner showing where you are and which way you are facing, with zoom, drag-to-pan, recenter, minimise, and a full-screen view. It is drawn from the layout the server actually built, so it cannot drift out of step with the town.
- Eight continuous bilingual story chapters with 41 steps, worth 19,950 coins. The journey runs from the welcome card through home, garden, Mochi, Moonleaf Cafe, every adventure zone and camp build, then returns to a Moon Berry Tart celebration. Steps pay out as they land, and each chapter banks a chest (250 to 3,000 coins) that the player opens from the board.
- A 20-slot material bag shown as a four-column grid. Wood, stone, herbs, fish, and rare crystals stack to 10 per cell; players can spend earned coins on five-slot expansions up to 60 without any Robux shortcut.
- A Quest panel fixed at the upper-left that keeps its reading size when opened and collapses to a hideable header, plus a large centred activity panel from the bottom tabs with readable bilingual text and responsive safe-area sizing.
- Daily login rewards, streak bonuses, rotating daily quests, leaderstats, and an authoritative coin economy.
- Mobile-first English/Thai UI with large touch targets, onboarding, live status, activity menus, bilingual 3D prompts, toasts, and safe map travel.
- A unified Wildwood visual system transcribed from `theme/stitch_roblox_color_code_extractor`: exact forest/parchment palette, timber-and-shingle architecture, carved glowing signs, tiered hand-painted pines, mossy cobbles, plaza string lights, explorer character gear, and distinct cat, fox, Shiba, owl, and rabbit companions.
- DataStore loading, reconciliation, sanitization, retry behavior, 60-second autosave, leave save, and shutdown save.
- A Wildwood adventure region with a personal campsite, hidden forest path, mining mountain, fishing river and boat, Mystery Cave, collectibles, and a three-rune puzzle.
- Six saved camp stages from Campsite through Tree House, Wooden Cottage, Workshop, Animal Shelter, and Adventure Center.
- Fox, Owl, Dog, and Rabbit adventure companions with distinct collection, puzzle, tracking, and garden abilities.
- Explorer, Trail Builder, and Nature Ranger outfit options plus Thai-first adventure controls.

## Earning Robux

Roblox provides no API that pays Robux **to** players, so nothing in this project pretends to. What it does is let the game **earn** Robux:

- **Coin packs** (developer products) - players buy coins with Robux.
- **A cosmetic supporter pass** - the Golden Lantern.

Both are switched off until you supply real ids. Create them in the Creator Dashboard (Monetization > Developer Products and Passes) and paste the ids into `Config.Monetization`. The shop appears on the quest board the moment one id is non-zero, and stays hidden otherwise.

`ShopService` handles the receipts. Roblox re-delivers a receipt until the game confirms it, so every granted receipt id is written into the player's profile and the profile is saved *before* the purchase is confirmed - a failed save returns `NotProcessedYet` so Roblox delivers it again rather than the player paying for coins that were never persisted.

Purchases buy coins, and coins buy furniture and seeds. **No chest, chain, or quest step can be bought**, so paying money never skips the game for a child playing it. `validate.py` fails if `ShopService` so much as mentions quest progress.

Premium purchases are intentionally not wired to gameplay power. The catalogs are ready for future cosmetic house skins, outfits, furniture, and pet skins.

## Run in Roblox Studio

1. Install Rojo and its Roblox Studio plugin.
2. Open a new Baseplate place in Roblox Studio.
3. From this folder, run `rojo serve`.
4. Connect the Studio plugin to `localhost:34872`, then sync.
5. Press **Play**. The server creates the town automatically.

For persistent data while testing in Studio, publish a private test place and enable **Studio Access to API Services** in the place's security settings. With API access disabled, the game still runs with a fresh in-memory profile for that session and reports save failures in the Output window.

To publish, stop the play session, sync once more, use **File > Publish to Roblox**, choose supported devices, and run the playtest checklist before making the experience public.

## Project layout

```text
default.project.json
src/
  ReplicatedStorage/Shared/       Config, catalogs, remote names, utilities
    Furniture.lua                 The 51-piece furniture catalogue and its part models
    HudLayout.lua                 Where the activity panel docks, as testable geometry
    Placement.lua                 Grid, footprint, and wall/doorway rules (shared by client and server)
    Progression.lua               The XP curve and what each action is worth
  ServerScriptService/
    Server.server.lua             Startup and player lifecycle
    Services/DataService.lua      Profile loading and saving
    Services/GameService.lua      Secure gameplay actions, quest chains, economy
    Services/ShopService.lua      Robux purchases (developer products and passes)
    Services/WorldService.lua     Runtime town, homes, pets, furniture, and level badges
  StarterPlayer/StarterPlayerScripts/
    Client.client.lua             Touch-first HUD and activity panels
    UI/                           Reusable theme, components, and the minimap
    UI/FurnitureShop.lua          Shop and My Home tabs, 3D preview, and the placement ghost
scripts/validate.py               Offline structural checks
scripts/furniture_test.py         Proves buying places furniture, placement rules hold, and the XP curve is correct
scripts/hud_layout_test.py        Proves the activity panel never covers the middle of the screen
scripts/contrast_test.py          Proves every button and label meets WCAG AA contrast
scripts/walkability_test.py       Proves every home and building can be walked into
scripts/village_style_test.py     Proves the buildings match images/home.png
scripts/wildwood_redesign_test.py Proves the supplied Stitch style reaches environment, signs, characters and pets
scripts/quest_chain_test.py       Plays through every quest chain and checks the payouts
scripts/quest_story_test.py       Checks the continuous story and real dish/resource hooks
scripts/pet_scale_test.py         Proves pets are one quarter of player height
scripts/bag_inventory_test.py     Proves the 20-slot grid and coin expansions
scripts/quest_board_layout_test.py Proves the Quest menu stays top-left, keeps its size, and can hide
scripts/shop_test.py              Proves Robux purchases pay out exactly once
scripts/robloxmock.lua            Roblox API test double used by the walkability test
scripts/sync_place.py             Copies src/ into the .rbxlx place file
scripts/studio_smoke.lua          In-Studio generation and doorway checks
docs/PLAYTEST.md                  Studio acceptance checklist
```

## Architecture notes

The client only asks for named actions. Prices, ownership, timers, rewards, cooldowns, quest progress, and balances are checked and changed by `GameService` on the server. `DataService` owns profiles and never accepts a complete profile from the client. `WorldService` only renders authoritative data and refuses garden prompts used from another family's plot.

Content is data-driven in `Catalog.lua`; tuning, the exact Wildwood color palette, and waypoints live in `Config.lua`. Adding furniture, seeds, outfits, resources, companions, camp levels, or destinations does not require changing persistence architecture. Existing version-1 profiles are reconciled into the version-2 adventure schema without resetting town progress.

## Editing the place file

`src/` is the source of truth. `CuteFamilyTown-Wildwood.rbxlx` is a standalone place that carries its own copy of every script, so it can be opened in Studio without Rojo. After changing anything under `src/`, push the sources into the place:

```powershell
python scripts/sync_place.py             # writes src/ into CuteFamilyTown-Wildwood.rbxlx
python scripts/sync_place.py --check     # fails if the place is out of date
```

Editing `src/` alone will not change what Studio runs if you open the `.rbxlx` directly.

## Local validation

Run:

```powershell
python scripts/validate.py
python scripts/walkability_test.py       # needs: python -m pip install lupa
python scripts/cafe_3d_test.py           # every cafe item is detailed 3D geometry
python scripts/environment_navigation_test.py  # local clock, lamps, quest ground path
python scripts/quest_chain_test.py       # all 8 chapters and 41 ordered payouts
python scripts/quest_story_test.py       # story arc and real gameplay hooks
```

`validate.py` checks the Rojo JSON, required source files, Luau delimiter balance, client/server action coverage, and map destination coverage.

`walkability_test.py` proves every home and building can actually be entered, and that Sunrise Mountain can actually be climbed. It loads the real `WorldService` into a Lua interpreter with a mocked Roblox API (`scripts/robloxmock.lua`), generates the town exactly as the server would, and runs a voxel flood fill with a Roblox-sized character over the resulting collision geometry. A structure passes only when a character standing on open ground outside can walk through the doorway to the marker inside and back out again - no jumping, no clipping. It also checks that every map destination drops the player onto real floor.

Enterable structures are tagged with an `Enterable` attribute and carry a `DoorwayVolume` and `InteriorMarker`; climbable ones are tagged `Climbable` and carry a `SummitMarker`. `scripts/studio_smoke.lua` re-checks the doorways and the mountain stairs against real Roblox collision in Studio.

`bakery_bay_town_palette_test.py` proves all generated world geometry uses only the 27 approved A — Bakery Bay colours while leaving character, pet and UI-only rarity colours separate. `village_style_test.py` additionally asserts every building carries the required pitched roof, ridge, gable ends, timber posts, rails, braces and hanging lanterns, and that every visible building part resolves exactly to the same central Bakery Bay palette.

`quest_chain_test.py` plays a fake player through all 41 steps of all 8 story chapters against the real `GameService`, checking every payout, that steps land in order, that unrelated actions cannot advance a chapter, that the chest is banked rather than paid, and that it cannot be claimed twice. It goes through the real request path, so the rate limiter and every guard are exercised.

`quest_story_test.py` checks that those chapters form one bilingual arc from the welcome card to the Adventure Center celebration. It also drives real cafe and adventure actions to prove only Moon Berry Tarts satisfy the signature-dish steps, each requested resource comes from its proper zone, every camp level appears in order, and returning players cannot be trapped by a cafe or camp milestone they already own.

`shop_test.py` drives the real `ShopService` receipt handler: a purchase pays out once, a re-delivered receipt is confirmed without paying again, an unknown product is refused, and money cannot advance a quest chain.

`furniture_test.py` drives the real `GameService` through the whole furniture loop: all 51 items use an exclusive placement preview before purchase, a second purchase is blocked until the first is placed or cancelled, invalid and cancelled previews spend nothing, and confirmation buys at the player's exact server-validated pose. It also checks wall/doorway collision, move/rotate/delete, rejoin persistence and the exact 100/250/450 XP curve.

`hud_layout_test.py` proves the activity panel stays out of the way. The panel used to open dead-centre, directly over the player's own character, so you could not see the pet you were feeding or the home you were decorating. Panel geometry now lives in `HudLayout.lua` as plain Lua with no Roblox API in it, and the client applies it without doing any arithmetic of its own - so the layout can be checked without an engine. The test sweeps 5,250 viewports from a 640px window to an ultrawide and asserts the docked panel never covers the centre of the screen, never collides with the top bar or the tab bar, and cannot be dragged off screen. It also asserts the old centred layout *would* have failed, so the test genuinely detects the bug rather than passing vacuously.

`contrast_test.py` proves the UI can be read. The garden's "Plant Daisy" button was unreadable, and not because the colour was ugly: a seed button is painted the flower's own colour, a daisy is pale yellow, and every button in the game painted its text white regardless of what it sat on - white on near-white, a contrast ratio of 1.11:1 where 4.5:1 is the readable floor. Painting the buttons darker would have hidden that rather than fixed it. The fix is `Theme.textOn`, which asks what a background needs its text to be and answers ink or white, so a colour the theme has never heard of - a flower, a rarity - still gets readable text on it. The test loads the real theme, the real seed colours and the real rarity colours and checks every pairing the game can produce against WCAG AA (4.5:1 for text; 3:1 for the rarity stripe, which is a graphic, not a label). It also asserts white-on-a-daisy fails, so it detects the reported bug rather than passing vacuously.

A final multiplayer playtest still needs Roblox Studio because Roblox engine APIs are not available in a normal shell.

## Next production milestones

- Replace primitive runtime art with optimized authored models while keeping the same service APIs.
- Add egg hatching, vehicle ownership, room-by-room furniture transforms, and school activities.
- Add a cosmetic-only MarketplaceService layer with parental-friendly purchase copy and receipt tests.
- Add analytics for onboarding completion, first harvest, first café serve, day-two return, and mobile frame rate.
- Localize the UI, including Thai copy from the original brief, and complete moderated child/family playtests.
