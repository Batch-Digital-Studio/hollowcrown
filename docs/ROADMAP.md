# Roadmap

## Milestone 0 — Combat prototype (current)
- [x] Stat + damage engine (types, conversion, increased/more, crit, resists, ailments)
- [x] Player: move, dodge, 5 Rites
- [x] 3 enemy types + a boss
- [x] Juice: hit-stop, shake, damage numbers, particles, glow
- [x] Loot: rarities, affixes, pickup, inventory, equip, tooltips
- [x] XP and levels
- [x] Generated zone ending in a boss arena

## Milestone 0.5 (also done night one)
- [x] Procedural sound effects (placeholder synth, swap for real samples later)
- [x] Fog-of-war minimap
- [x] Ember Constellation v1: 4 branches, 41 nodes, 4 keystones (P)

## Milestone 1 — Vertical slice
- Ember Constellation expansion to ~120 nodes, cross-links between branches
- Support gems (Rite modifiers): more projectiles, chain, added fire, etc.
- ~15 Rites, one fully realized class fantasy
- [x] Art pass v1 (CC0 pixel pack, lighting). Next: attack/death animations, armour icons, real audio samples
- Save/load, stash

## Milestone 2 — Co-op
- Host-authoritative multiplayer (Godot high-level multiplayer / ENet), 1–4 players
- Shared world, instanced loot

## Milestone 3+
- More zones/acts, uniques, crafting, endgame loop

## Stage A — Class framework + Bog Shaman (done 2026-11-26)
- [x] Class select, 6-slot bar, Class / Rite / Ember points from level, respec free until 20
- [x] Class screen (K / D-pad Down): 3-branch class tree, Rite specializations, bar assignment
- [x] Bog Shaman: Spirit resource, Grand Rite Special (LB+RB / T), 10 Rites, 24-node class tree, spec trees
- [x] Systems: permanent minions, Grim Pillar totems, poison stacks + chaos resistance, curses, roots, ward aura, corpses
- [x] Dual-class hook at level 10 (activates when stage B classes exist)
- [ ] Balance pass from Jason's playtesting (Shaman vs boss especially)

## Stage B — Other three classes (done 2026-11-27)
- [x] Ember Magus, Oathsworn, Hollow Ranger with resources, Specials, trees, specs
- [x] Dual-class live
- [x] First balance pass (2026-11-27): starter Rites evened out with a time-to-kill benchmark (`--ttk`)
- [ ] Balance from Jason's playtest (Shaman bot still clears slowest; Trial at depth 5 may be hard)

## Stage E — Hollow Rifts (done 2026-11-27)
- [x] Rift Seals in ~35% of zones; walking up opens a rift that widens on kills, shrinks when idle, closes at 60 s
- [x] Rift monsters (Rift Fiend, Maw, Brute) spawn at the edge, aggroed; violet tint
- [x] Rift Splinters, 100 fuse into a Rift Heart; open it from the inventory purse to fight the Rift Lord
- [x] Rift Lord "The Hand That Wore the Crown" (3-skill boss) drops the 3 rift-only uniques
- [x] Currency system: Ember Shards + 5 crafting currencies + Ash Dust drop as magnetized pickups; purse panel in the inventory
- [ ] Crafting currencies are collected but not usable yet (stage F)

## Stage F — Economy (done 2026-11-27)
- [x] Crafting: Kindling Shard, Coal of Ascension, Ash Salt, Hollow Ember, Crown Fragment (select in purse, apply to item; held for repeats)
- [x] Essences: 8 types x 4 tiers (Whispering..Searing) from Bound Embers; guarantee a modifier while making a rare
- [x] Ashen Peddler next to every zone start: 6 items for Ember Shards, currencies for Ash Dust; shatter near him to sell
- [x] Reliquaries (2-3 per zone): Ambushed, Gilded, Volatile, Cursed, Echoing, Arcane; stand beside for 1 s to open
- [x] Bound Embers (~half of zones): empowered rare breaks out of a crystal, drops an Essence
- [x] Writs of the Hollow King: one objective per zone on the HUD, pays shards + currency + rare/unique
- [ ] Peddler stock is per zone and doesn't persist through save/load (regenerates)

## Stage C — Ascensions (done 2026-11-27)
- [x] 12 ascensions x 6 notables (data in `scripts/data/ascensions_db.gd`, behaviour in `scripts/classes/asc.gd`)
- [x] Ascension Trials after the Regent on depths 5/10/15/20: golden seal, 3 waves + champion, +2 points each (8 total)
- [x] Ascension tab in the class screen (choose once, take/refund notables; controller A/X/B)
- [x] Probe test `--asc-probe` (18 behaviour checks) + every ascension run fully allocated with the bot
- [ ] Balance: bot (level 22) dies in the depth 5 Trial without god mode; Trial may be too hard or the bot too weak
- [ ] Approximations to revisit: Shieldwall/Rallying Cry/Shared Oath affect you + your minions (no co-op allies yet); Glacial Echo = second lance projectile; Perfect Focus = projectiles return once

## Stage D — Constellation v2 (done 2026-11-27)
- [x] 145 nodes: 8 regions (Steel, Pyre, Rime, Storm, Wind, Venom, Grave, Heart), inner + outer rings
- [x] Class entry stars on the outer ring (dual-class adds the second star); classic characters keep the centre start
- [x] 8 Masteries (allocate, then A / click again to switch between 3 effects for free)
- [x] 12 keystones: the 4 old ones + Echo of the Crown, Ashen Avatar, Wildfire, Pack Leader, Unbroken Vow, Tide of Venom, Fleetfoot Pact, Shared Flame
- [x] Old saves: v1 passive ids are dropped and their points refunded automatically
- [ ] Ember Sockets (jewels) - later
- [ ] Shared Flame is "50% stronger buffs on you" until co-op exists

## Stage H — Blood Altars, Ember Fog, respec costs, loadouts (done 2026-11-27)
- [x] Blood Altars (~30% of zones): three waves of risen monsters from this zone's kills, Tribute, three offerings bought by standing on them
- [x] Ember Fog (~25% of zones): Fog Lantern, 45 s of Fogborn that scale with fog depth, Fog Cache scaled by fog kills, better drops inside the fog
- [x] Respecs cost 4 x level Ember Shards per point from level 20 (class tree, Rite specs, Ascension, Constellation)
- [x] Two loadouts (weapon + six Rites) on D-pad Left/Right, X key
- [ ] Peddler is in every zone (the design guide said ~25%); kept for convenience, Jason to decide

## Stage I — World, town and quality of life (done 2026-11-27)
- [x] Seven regions x 3 depths, each with its own biome and generator: Ashfall Crypt (corridors), Whisperwood (forest clearings), Mirefen (swamp), Hollow Deep (caverns), Duskhold (castle halls), Frostmere (ice caverns), Cinder Wastes (ashlands). Then The Hollow Crown cycles them.
- [x] Procedural pixel tiles for the non-dungeon biomes (`scripts/world/biome_art.gd`), biome decorations and themed lights
- [x] Emberhold town: Ember Vault stash (3 x 48), Grimm the Smelter (salvage Common / Magic- / Rare- / everything, two presses), Ashen Peddler (moved here from the dungeons), Waystone, portal back to your depth
- [x] World map: travel to any reached region, continue at deepest depth, or go home. Pause menu: Return to Emberhold, World Map. H key.
- [x] Loot filter (rarity + category, show hidden); hidden drops are invisible and never auto-picked up
- [x] Rite list on the class screen scrolls (right stick / wheel)
- [ ] Biome-specific monsters (all regions still use the same monster pool)
- [ ] Full isometric art conversion (Jason's choice, 2026-11-27) and the visual pass from his creative brief
