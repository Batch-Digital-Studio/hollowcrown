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

## 2026-11-27 — Balance pass 1
- Benchmark `--ttk` (time to kill a 3000-life husk at level 5, starter weapon, main Rite). Before: Magus 24 s, Shaman 38 s (with 4 husks), Oathsworn 50 s, Ranger 60+ s. After: Magus 24 s, Shaman 20 s, Oathsworn 41 s, Ranger 36 s (Cleave and Split Shot are area Rites, so slower on one target is intended).
- Bone Spear 16-25 (was 12-19), pierces 2. Husk Claw 8-14 (was 6-11). New Shamans start with 60 Spirit.
- Ashen Cleave gets a 6-10 physical base. Split Shot: 4 degree spread (was 7), 1-3 physical base, 85% effectiveness. Projectile Rites can now set their own `spread`.
- Note: skill effectiveness only scales added damage, not weapon damage.
- Bot: Shaman no longer spams Raise Husk at the husk cap. The Shaman bot still clears slowest (about 70 kills vs 100-180), which looks like bot behaviour more than damage; worth checking in a real playtest.

## 2026-11-27 — Fixes from Jason's first playtest
- Controller cursor in menus froze after one step on a real PC (the OS pointer warp looked like mouse input). Mouse events caused by the pad cursor are now ignored.
- Boss portal no longer sits on the loot pile: it spawns about 4.5 cells away, and you stand in it for 1 second to descend (ring shows progress), so you can't fall through while looting.
- Minions path around walls (A* over the zone grid, `Game.nav_path`) instead of walking straight into obstacles; a minion stuck for 2 s hops back to you. New `--nav-probe` test (husk behind a wall must reach and hit its target): passes on 3 maps.
- Known, not fixed yet: a Reliquary guardian can spawn inside a wall where it can't be hit.
- Ascension Trial seal and the boss portal could spawn on top of each other. The seal is now placed 3.5-6.5 cells from the boss, at least 300 px from the portal, the loot pile and the player (checked on 3 maps: ~350 px apart).
- A skipped Ascension Trial now reappears after the next Regent until it's done.

## 2026-11-27 — Bosses, Spirit, element visuals (from Jason's playtest)
- Boss rotation by depth: 1 Ashen Regent, 2 The Rot Mother, 3 The Frostwarden, 4 The Pyre Brute, 5 The Gravecaller King, then around again. New `scripts/entities/boss_brain.gd` + `scripts/skills/hazard.gd` (telegraphs: circle = get out, ring = get in, line = sidestep; can follow you, then lock).
  - Rot Mother: following bile slams leave poison pools, rot spray, broods of husks (corpses for Shamans); phase 2 rains pools.
  - Frostwarden: alternates "Come closer" rings and "Get back" bursts, fans of ice lances; phase 2 adds lances and a chilling aura.
  - Pyre Brute: telegraphed charge that leaves fire; charging into a wall staggers him for 2.2 s (+50% damage taken); stomp and cinder rain; phase 2 double charges.
  - Gravecaller King: shielded (90% less damage) while his guard of skeletons lives, bone-spear bursts, blinks away leaving a blast; phase 2 Soul Rend and double bursts.
  - Boss bar shows the boss's name, a phase-2 mark at 50%, and SHIELDED / STAGGERED. Intro hint when a boss first engages. Test flag `--boss=<id>`.
- Spirit: kills give more (4/8/20/40); damaging bosses gives up to 120 Spirit over their life, rares 30; minion hits +0.5; +0.6/s while monsters are near.
- Raise Husk with no corpse nearby now raises an Ash Husk (60% life) for no Spirit.
- Element visuals: burning enemies flicker with rising flames (more with Everburn stacks), chilled ones shed frost and get a blue ring, frozen ones are encased in ice, shocked ones crackle with sparks, poisoned ones bubble green, cursed ones trail purple. Hits flare by element (flames, ice shards + ring, lightning spark, chaos bubbles, blood).
- Verified in the cloud: all 4 new bosses run without errors; the Magus bot (level 10, no gear) killed the Frostwarden, Pyre Brute and Gravecaller King and died once to the Rot Mother. Not yet played by Jason.

## 2026-11-27 — World, town, stash, salvage, loot filter
- See ROADMAP "Stage I". Save now also stores max depth, town state, the stash and the loot filter.
- Tests: pad test 45 checks (adds stash in/out, loot filter toggle, bulk salvage, Waystone -> world map -> travel). Probe adds loot-filter pickup checks and no longer depends on random block/evade or bolt lifetimes. Every biome run with the bot: no script errors.
- Not verified on Jason's PC.

## 2026-11-27 — Isometric 3D visual pass (KayKit)
- See ROADMAP "Stage J". New: `scripts/view3d/` (IsoView, Puppet, Level3D, SpellFx3D), `scripts/data/models_db.gd`, `assets/kaykit/` (CC0, credits in `assets/kaykit/CREDITS.md`).
- Gameplay untouched apart from presentation-event fields on Actor (act_serial, last_act...) set by SkillExec, and screen-relative movement input in the 3D view.
- Tests: all existing tests pass; new `--iso-probe` 16/16; pad test now also toggles the view from the pause menu.
- Not verified on Jason's PC.
