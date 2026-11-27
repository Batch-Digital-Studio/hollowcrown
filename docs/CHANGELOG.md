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

## 2026-11-26: Xbox controller support
- Full controller play: stick move, right-stick aim with auto-targeting, face buttons + triggers for Rites, LT dodge, LB flask.
- Menus navigable on pad (title, hero select, pause, death); virtual cursor in inventory and passive tree.
- Button glyphs switch automatically between keyboard and controller; rumble feedback.
- Input buffering (0.3 s) so tapped skills aren't dropped mid-cast. Shatter now needs a second press.
- Automated controller test (`--pad-test`): 14 checks, all passing.

## 2026-11-26: Stage A — class framework and the Bog Shaman
- Class select at New Kindled (Bog Shaman, or Kindled classic). Classic characters and old saves keep working.
- Bog Shaman: Raise Husk, Bone Spear, Venom Spit, Hex of Rot, Plague Cloud, Spirit Totem, Soul Siphon, Swampcall, Corpse Burst, Ancestral Ward; Grand Rite Special.
- New systems: minions that follow/leash/fight, enemies that target minions and totems, corpses, Spirit, poison stacks, chaos res, curses, roots, ward totems.
- 6-slot skill bar (RT A X B Y RB / LMB RMB Q E R F), LB+RB Special chord, buffered Special.
- Fixed: husks and totems spawned with 1 life (a shadowed variable). Input timing now uses game time.
- Controller test now covers the Shaman flow; run it with --seed=3 for a deterministic map.

## 2026-11-26/27 overnight: Stage B — Ember Magus, Oathsworn, Hollow Ranger
- All four classes playable; dual-classing at level 10 is live (pick in the class screen).
- Ember Magus: Kindling charges (spells build, Pyre Lance spends), Cataclysm Special, Ember Ward shield; Blink, Flame Wall, Frost Lance, Glacial Prison, Ball Lightning, Pyre Lance.
- Oathsworn: Resolve (taking/landing hits), block chance; Shield Rush, Earthsplitter, Oath of Embers (taunt), Bastion, Judgment Brand (3rd hit detonates), Chain Hook, Banner of the Last King, Sunder, Iron Will; Oathbreaker Special.
- Hollow Ranger: bows (3 new bases), Focus (builds while moving; full Focus empowers the next Rite), evasion; Split Shot, Vault Shot, Rain of Ash, Pinning Shot, Thornvine Arrow, Caltrops, Spirit Hawk companion, Smoke Veil, Explosive Bolt, Windrunner; Hunter's Moon Special.
- Generic systems: buffs, block, entropy evasion, Ember Ward, slows, brands, dashes, resource HUD.
- Known: Magus is currently the strongest class in bot tests; needs a balance pass.

## 2026-11-27 — Stage E: Hollow Rifts + currency
- Rift Seals, spreading rifts with kill-to-widen timer ring, rift monsters, Rift Splinters → Rift Heart → Rift Lord encounter with rift uniques.
- Currencies (Ember Shards, Kindling Shard, Coal of Ascension, Ash Salt, Hollow Ember, Crown Fragment, Ash Dust) as magnetized pickups, saved with the character, shown in the inventory purse. Shattering items gives Ash Dust.
- Test flags: `--rift` (force a seal near the start), `--heart-at=T` (grant and open a Rift Heart).
- Verified in the cloud: bot cleared forced rifts and killed the Rift Lord (Magus, 43 s); all tests pass. Not verified on Jason's PC/controller.

## 2026-11-27 — Stage F: economy
- Crafting currencies are now usable: pick one up in the inventory purse (A / click), apply to an item; B / right-click drops it. Purse shows all currencies and Essences, two columns.
- Essences (8 affixes x 4 tiers). Design note: an Essence's tier is lowered if the item level is more than 10 below that tier's requirement.
- Ashen Peddler: open the inventory beside him and his shop replaces the character sheet. Shattering beside him also sells for Ember Shards.
- Reliquaries open by standing next to them for one second, so modifiers can be read first and the box skipped (no extra button needed on pad).
- Bound Embers and Writs (rares, clear 80%, Regent without flask, all Reliquaries, Bound Ember, 45 s rift).
- Controller menus now use a game-tracked cursor (`Game.pad_cursor`) instead of reading the OS mouse; the OS mouse is still moved to match. Needed so the headless pad test can drive clicks.
- Tests: new `scenes/test_crafting.tscn` (all currencies + all Essences); pad test now 24 checks incl. crafting and buying with A/B. Flags `--mechanics` (Reliquary/Bound Ember near start), `--rich`, `--writ-rares`.
- Tuning: Bound Ember and Cursed Reliquary guardians are gentler at depth 1 after the Shaman bot died to them.
- Not verified on Jason's PC or a real controller.
