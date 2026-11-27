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

## 2026-11-27 — Stage C: Ascensions
- 12 ascensions with 72 notables, all implemented (see ROADMAP for the few approximations). New systems they needed: freeze, ignite stacking, chill/shock strength, chaos penetration, Stoneblood dynamic armour, squire/bog-beast permanent companions, minion haste/empower, banner cap separate from totems, returning and forking projectiles, trap tagging (Caltrops, Explosive Bolt, Smoke Veil), following ground effects, per-Rite overrides from notables (`skill` with `_pct` keys).
- Ascension Trials: seal appears beside you after the Regent on depths 5/10/15/20; 3 waves + champion; +2 points each.
- Class screen: Ascension tab. Class screen and passive tree now take clicks through `_input` (same as the inventory) so the controller cursor is reliable.
- Husk cap now counts only husks (hawk, squires, beast don't take husk slots).
- Test flags: `--asc=<id>:<n,n>`, `--asc-probe`, `--trial`, `--kill-boss`, `--god`.
- Not verified on Jason's PC or a real controller. Balance untested beyond bot runs.

## 2026-11-27 — Stage D: Constellation v2
- New 145-node Ember Constellation generated from region data in `scripts/data/passives_db.gd`. Each class enters at its own star; the tree opens centred on it.
- Masteries and 8 new keystones (new hooks: Echo of the Crown recast, more cast speed, ward from life, no regen, crit immunity / no crit, hit-only damage reduction, elemental penetration for all types, shock effect, ignite duration, burning ground on death, flask charges, % life regen).
- Fixed: walking through the centre node cost no point for classed characters.
- `SkillExec.use` now calls `_behave()` for the actual Rite so it can be repeated (Echo of the Crown).
- Tests: probe now 25 checks incl. keystones and Mastery switching; pad test 33 checks incl. allocating from the class star and switching a Mastery with A.
- Not verified on Jason's PC or a real controller.

## 2026-11-27 — Stage H: Blood Altars, Ember Fog, respec costs, loadouts
- Blood Altar and Ember Fog as described in ROADMAP. New currency: Tribute.
- Respecs now cost Ember Shards from level 20 (replaces the "coming soon" message).
- Loadout swap on D-pad Left/Right and X; saved.
- README controls and feature list rewritten for the current game.
- Tuning from bot runs: lower Tribute payouts; early Fogborn mostly normal rarity, fewer and weaker.
- Test flags: `--altar`, `--fog`, `--altar-now`, `--fog-now`. Pad test now 35 checks incl. loadout swap.
- Not verified on Jason's PC or a real controller.
