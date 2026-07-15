# Studio playtest checklist

## Village look (images/home.png)

- [ ] Every building has a pitched terracotta shingle roof with overhanging eaves and a ridge beam - no flat slabs.
- [ ] Walls read as dark timber framing and diagonal braces over cream plaster, on a stone footing.
- [ ] Lanterns glow either side of every door and around the fountain at dusk.
- [ ] Shops are told apart by their banners and plaster tint, not by saturated walls.
- [ ] Home paint options still visibly change the plaster panels.
- [ ] The plaza is cobbled and the light is warm and low, like the reference.
- [ ] Frame rate on the target mobile tier is still acceptable: the town is now ~2,100 parts, up from ~540.

## Quest board and chains

- [ ] The board sits on the right-hand edge and starts closed; nothing covers the middle of the screen.
- [ ] Tapping the header opens and closes it.
- [ ] It shows today's quest, the current chain, every step in order, and what each step pays.
- [ ] Doing a step's action advances only that step; the bar fills and a toast names the next step.
- [ ] Finishing a chain turns the board gold and shows CHEST READY even while closed.
- [ ] OPEN THE CHEST pays the bonus once; the button does not come back.
- [ ] Progress survives rejoining, and an old profile with no quest data starts cleanly at chain 1.
- [ ] After all four chains, the board says every chain is complete and shows the total earned.

## Robux shop

Only testable once real product ids are set in `Config.Monetization`. Use a paid-access test place or Studio purchase prompts.

- [ ] With all ids left at 0, no shop section appears anywhere on the quest board.
- [ ] With a coin pack id set, the pack appears on the board with its Robux price.
- [ ] Buying a pack adds exactly the advertised coins, once, and the coin counter updates.
- [ ] Rejoining keeps the purchased coins (needs Studio API access enabled).
- [ ] Buying the supporter pass marks it as owned and it survives a rejoin.
- [ ] Buying coins never advances a quest chain, step, or chest.

## Minimap

- [ ] The map sits in the top-right corner and shows the town, the roads, the eight homes, and the Wildwood zones.
- [ ] The red arrow tracks the player and turns to face the way they are walking.
- [ ] Your own home is highlighted and labelled MY HOME; the other seven are not.
- [ ] `+` and `-` zoom; the mouse wheel zooms on desktop.
- [ ] Dragging the map pans it, `ME` turns yellow while panned, and tapping `ME` snaps back to the player.
- [ ] `HIDE` collapses the map to its title bar and `SHOW` brings it back.
- [ ] `BIG` opens the map full-screen with place names visible, and `SMALL` returns it to the corner.
- [ ] Zoomed out far enough, the whole map from town to Mystery Cave is visible at once.
- [ ] Buttons are comfortable to tap on a phone and do not overlap the daily gift or the names toggle.

## Walking in and out of buildings

`python scripts/walkability_test.py` proves the routes offline, but confirm them with a real character:

- [ ] Walk in and out of the Family Café, Pet Shop, Flower Shop, and Little School through the front doorway. None of them is a solid block.
- [ ] The café counter, pet bowl, and seed crate are inside their shops and their prompts still fire from in there.
- [ ] Walk in and out of your own home through the front door, and confirm the interior is lit.
- [ ] A home filled to the 12-furniture cap still leaves the doorway and the route to the door clear.
- [ ] Walk into the Mystery Cave; the crystals, cave stone, and all three runes are inside the chamber.
- [ ] Climb the camp tree-house stairs and walk into the cabin on the deck.
- [ ] Walk in and out of the camp cottage (stage 3) and the Adventure Center (stage 6).
- [ ] No camp building overlaps the house it belongs to.
- [ ] Travelling to Café, Pet Shop, Flower Shop, or School by map button lands you inside, and you can walk straight back out.
- [ ] Sunrise Mountain can be climbed on foot from the base: five flights of steps up the front, walking along each terrace to reach the next flight.
- [ ] The mountain crystal is out on the summit and the stone pile is on the second terrace; both can be collected without teleporting.

## Solo smoke test

- [ ] The player spawns at the plaza and receives a labeled private home.
- [ ] The welcome card appears once and all six bottom navigation buttons are usable at phone resolution.
- [ ] The daily gift changes the balance once and cannot be claimed twice on the same UTC day.
- [ ] A Daisy can be planted, watered, and harvested after 20 seconds; the reward appears in both the HUD and leaderstats.
- [ ] Tulip and Lavender seeds can be purchased and planted.
- [ ] Mochi follows after spawning, gains XP from food/play, gets dirty, and can be bathed.
- [ ] The café costs 300 coins to open, applies the serve cooldown, shows a guest, and pays the displayed reward.
- [ ] Café upgrade requirements and NPC helper costs are enforced.
- [ ] Tapping BUY & PLACE opens a movable/rotatable ghost without spending coins or creating furniture.
- [ ] Another furniture purchase cannot start until the current ghost is placed or cancelled.
- [ ] Confirming charges once and places at the chosen pose; cancelling charges nothing. Walls, overlaps, door clearance, the 12-item cap and packing away are enforced.
- [ ] Home paint and all three outfits visibly change.
- [ ] Every map button places the character safely at the intended destination.
- [ ] Rejoining restores coins, home color, furniture, flowers, pet level, café progress, outfit, streak, and onboarding state.

## Multiplayer and security test

- [ ] Start a local server with 4-8 players; every player gets a distinct plot and pet.
- [ ] A player cannot use a prompt on another player's garden.
- [ ] Leaving releases the plot and removes the player's pet/furniture visuals.
- [ ] Repeated café, reward, shop, and harvest requests do not bypass cooldowns, balances, or ownership.
- [ ] Invalid item names, slot numbers, destinations, and payload types fail without a server error.
- [ ] The server closes without DataStore timeout warnings when API services are enabled.

## Wildwood adventure test

- [ ] The Adventure navigation tab scrolls into view on a phone and opens without hiding existing menus.
- [ ] All five adventure map buttons travel to safe positions: Camp, Wildwood Forest, Mountain, River, and Mystery Cave.
- [ ] Wood, herbs, stone, fish, and crystals can be collected only from valid zones and respect the eight-second cooldown.
- [ ] Camp upgrades consume the displayed resources, persist after rejoin, and render beside the player's own home.
- [ ] Fox doubles forest finds, Dog doubles mountain finds, Owl doubles cave finds and reveals the next rune, and Rabbit grants a Daisy seed after harvest.
- [ ] Companion unlock costs are enforced and the selected companion persists and follows the player.
- [ ] The cave accepts Leaf → River → Sun, resets on a wrong rune, rewards once, and enforces its reset timer.
- [ ] A player can share one saved resource with the nearest loaded explorer inside 50 studs; distant, invalid, and empty-inventory requests fail.
- [ ] Existing home, garden, pet, café, dress-up, map, daily reward, and save tests still pass with a version-1 profile fixture.

## Device and accessibility test

- [ ] Test phone portrait, phone landscape, tablet, and desktop emulation.
- [ ] Navigation remains visible; panels scroll; no activity button is clipped.
- [ ] Touch targets are comfortable for a young player and critical actions do not require precise 3D clicking.
- [ ] Text remains readable against the world and the experience is understandable without chat.
- [ ] Check the MicroProfiler with 8 players; pet following and generated parts should remain stable on the target mobile tier.
