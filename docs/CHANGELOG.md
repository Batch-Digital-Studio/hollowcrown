# Changelog

## 2026-11-26: Milestone 0, first night
- Project created. Design doc, roadmap.
- Stat/damage engine with unit tests (conversion, increased/more, crit, armour, resist cap).
- Player: movement, dodge, flask, 5 Rites. Monsters: Husk, Cinderling, Brute; magic/rare packs with mods.
- Boss: The Ashen Regent (sweep, telegraphed flare, ember volley, summons, enrage at 50%).
- Loot: 20 bases, 27 affixes with tiers, 5 uniques. Inventory, equip, comparison tooltips, character sheet.
- Generated zones with themes per depth; portal descent; autosave.
- Test bot (`--autoplay`) used for smoke tests and screenshots.
- Procedural SFX (19 sounds), minimap with fog of war, Ember Constellation passive tree with keystones.
- Fix: game input now works while paused (closing passive tree / pause menu).

## 2026-11-26: Art pass (night one, part two)
- Art direction: dark pixel art using 0x72's CC0 16x16 DungeonTileset II (see assets/0x72/CREDITS.md).
- 8 animated heroes with a character select screen; equipped weapon drawn in hand and swung.
- Monsters on sprites (zombie, imp, ogre, big demon boss); 3 new monsters: Bone Rattler, Rimecaller, Gravecaller (summons).
- Tiled dungeons: floor variants, brick walls, banners, fountains, skulls, spikes, crates; treasure chests.
- Real 2D lighting: dark ambient, player light, flickering braziers, glowing casters and boss, light flashes on spells.
- Unlit FX layer + world overlay for life bars and names; weapon sprite icons; flask sprite on HUD.
