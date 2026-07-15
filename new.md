Roblox Studio - Feature Request

Task 1: Player XP & Level UI

Goal

Create an XP and Level system that is displayed above the player's character.

Requirements

- Display a Level badge above every player's head.
- Format:
  - ⭐ Level 1
  - ⭐ Level 2
  - ⭐ Level 10
- Add an XP progress bar.
- XP should increase from gameplay (create placeholder function if game logic is not finished).
- Example progression:
  - Level 1 → 100 XP
  - Level 2 → 250 XP
  - Level 3 → 450 XP
  - Continue using scalable progression.
- When leveling up:
  - Play a small animation.
  - Show floating text:
    - "Level Up!"
  - Save Level and XP using DataStore.

Code requirements:

- Clean, modular Lua code.
- Separate ModuleScripts when appropriate.
- Avoid duplicate code.
- Comment important sections.

---

Task 2: Furniture Shop System

The Furniture Shop currently allows players to press the Buy button, but no furniture appears.

Please implement the complete purchasing and placement system.

Requirements

When a player purchases furniture:

- Check player currency.
- Deduct the correct amount.
- Spawn the purchased furniture inside the player's house.
- Save ownership.
- Furniture remains after rejoining.

---

Furniture Theme

Style:

- Cute Family Town
- Cozy
- Warm
- Modern Scandinavian
- Soft pastel colors
- Wood textures
- Suitable for children and families

---

Furniture Categories

Living Room

- Sofa
- Coffee Table
- TV Stand
- Television
- Bookshelf
- Floor Lamp
- Rug
- Plant
- Wall Shelf
- Picture Frames

Bedroom

- Bed
- Pillow Set
- Wardrobe
- Desk
- Chair
- Nightstand
- Table Lamp
- Plush Toys

Kitchen

- Refrigerator
- Kitchen Counter
- Stove
- Sink
- Dining Table
- Dining Chairs
- Microwave
- Shelf

Bathroom

- Bathtub
- Toilet
- Sink Cabinet
- Mirror
- Towel Rack
- Laundry Basket

Garden

- Flower Pots
- Trees
- Bushes
- Garden Bench
- Fountain
- Mailbox
- Fence
- Playground Set
- Swing
- Sandbox

Decoration

- Wall Clock
- Curtains
- Ceiling Lamp
- Candles
- Paintings
- Plush Animals
- Indoor Plants
- Carpets

---

Shop Features

- Furniture Preview before buying.
- Rotate furniture before placement.
- Grid snapping.
- Cannot place through walls.
- Move furniture.
- Rotate furniture.
- Delete furniture.
- Store purchased furniture in inventory.
- Search bar.
- Category filter.
- Favorite items.
- Rarity colors:
  - Common
  - Rare
  - Epic
  - Legendary

---

Saving

Use DataStore to save:

- Owned furniture
- Furniture positions
- Rotation
- Inventory
- House upgrades

---

Performance

- Optimize for mobile.
- Avoid memory leaks.
- Use CollectionService when appropriate.
- Keep code modular.

---

Deliverables

1. All required Lua scripts.
2. Folder structure.
3. UI implementation.
4. Furniture spawning system.
5. Placement system.
6. Saving/loading system.
7. Bug fixes for existing furniture purchase issue.

Before writing new code, inspect the existing project to reuse current systems instead of recreating them. Refactor where necessary while preserving compatibility.