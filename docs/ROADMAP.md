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
- [x] Full isometric art conversion: done as real-time 3D, see Stage J

## Stage J — Isometric 3D visual pass (first playable, 2026-11-27)
Jason's creative brief + choice "Real-time 3D, KayKit". The simulation is unchanged (still 2D); `scripts/view3d/` draws it in 3D.
- [x] Fixed isometric orthographic camera (45 deg, 52 deg elevation) following the hero with the old aim lead and screen shake
- [x] 2D ground effects (telegraphs, novas, rings, pickups' beams) sit exactly on the 3D floor: the canvas uses the camera's ground projection; mouse aim and screen-relative stick/WASD movement follow it
- [x] KayKit (CC0) models: class heroes (Mage, Knight, Rogue, Barbarian), skeleton monsters with weapons, minions, bosses scaled up; idle / run / attack / cast / hit / death animations from gameplay state and cast events
- [x] Ember Bolt upgraded: hand flare on cast, glowing bolt with moving light and ember trail, impact sparks + shock ring + light flash + scorch mark (`scripts/view3d/spell_fx3d.gd`); every other projectile gets a 3D glow bolt
- [x] Ashfall Crypt mood pass: KayKit dungeon tiles and walls (camera-side walls cut low), torches with flame particles, coffins / skull candles / bones / gravestones, a mausoleum landmark behind the Regent's arena, a candle shrine at the entrance, falling ash, dark fog, real shadows
- [x] 2D lights (braziers, spell flashes, the hero's light) mirrored as 3D lights
- [x] Pause menu: View: Isometric 3D / Classic 2D (saved in user://settings.cfg); `--2d` / `--3d` flags
- [x] Tests: `--iso-probe` (16 checks: projection matches Camera3D, aim inverse, move-up goes up the screen, models, Ember Bolt bolt + impact, death animation, view toggle); pad test checks the View toggle with the D-pad
- [ ] Not verified on Jason's PC (frame rate, look on his monitor). Screenshots were taken with software rendering.
- [ ] Other regions only get tinted KayKit tiles (forest/swamp: dead trees for walls). Their own models and props come next, region by region
- [ ] Monster models are all KayKit skeletons (by role); proper models per monster family later
- [ ] Props, chests, NPCs, portals and loot are still the 2D sprites standing upright in the 3D world; convert to models
- [ ] Gathering/crafting foreshadowing not done yet (no ore/herb assets in the packs used)

## Stage K — Godot vs Unreal playtest (2026-11-27)
- [x] Original Whisperwood kit from Blender scripts; shared layout; Godot slice + Unreal slice; how-to in docs/PLAYTEST.md
- [x] Engine decided: Godot (Jason, 2026-11-27)
- [ ] Jason plays both on his PC (controller), compares look and frame time
- [ ] If Godot: bring the Whisperwood kit into the real Whisperwood region (generated zones) and add tree canopy fade near the hero
- [ ] If Unreal: plan a real port (C++/Blueprint gameplay, Niagara effects); needs Visual Studio installed

## Stage L — Chapter I: The Hollow Crown (new build, 2026-11-27)
Jason's brief: a full-scale, open-world-feeling first chapter (PoE / Last Epoch flow), biome monsters, rares that feel rare,
one Mage with Ice, Fire, Lightning, Chaos and Light spells that look like their element, a boss that feels like a boss.
The rest of the game is set aside; this is the build to perfect and then roll out. Title screen: "Chapter I: The Hollow Crown" (`--chapter`).
- [x] One large map, 360 m x 360 m (`scripts/data/chapter_db.gd`, `scripts/world/chapter_gen.gd`): a winding route through
      the Whisperwood (forest) -> Mirefen (swamp) -> the Barrow Hills; seeded, so everyone gets the same world
- [x] Glades on the route: Wayfarer's Camp, the Hollow Oak, Ring of Listening Stones, Drowned Shrine, Stillwater lake,
      Fallen Watchtower, Field of Cairns, Throne of the Hollow King; 4 waystones (touch = respawn point + full heal)
- [x] Water: a river with a plank bridge, swamp lakes and shallows (`scripts/view3d/shaders/water.gdshader`); terrain with
      region textures, height (banks dip into the water, hills under the tree walls), path dirt, wet shores (`terrain.gdshader`)
- [x] Vegetation: ~11,000 props batched per 32 m chunk and culled around the camera; tree walls stay low on the camera side
- [x] 11 hidden side trails; about 10 end in a hidden cache (chest with a faint glint, 3-4 better items); found count on the minimap
- [x] Region moods blend as you walk (fog, sun, ambient), region banners, fireflies / marsh mist
- [x] Biome monsters: Dusk Wolf, Briar Spider, Thornling (forest); Bloated Bogtoad, Drowned Vigil, Marsh Wisp (swamp);
      Barrow Guard, Barrow Archer, Barrow Hexer (barrow). New Blender models: wolf, spider, toad, thornling (animated)
- [x] Named rares ("Grimfang, the Hungering") with two of ten real abilities (Stormcaller, Frostbound, Infernal, Vile,
      Warcaller, Broodmother, Phasing, Volatile, Juggernaut, Soulwarded), an aura in their colour, ability list under the name
- [x] Mage spellbook, 17 spells over five elements on two loadouts (D-pad left/right): new Thunderfall, Blight Orb,
      Withering Mire, Soul Rend, Radiant Lance, Sunburst, Judgment. New damage type Light with Blind (35% miss)
- [x] Element visuals for every spell (`scripts/view3d/element_fx.gd`): fire flames/embers/smoke/scorch, ice crystals/shards/frost
      mist/ice spikes, forked flickering lightning, void orbs/bubbles/dark smoke, radiant beams/rays/motes; novas, chains,
      lances, sky strikes, lingering fields
- [x] Ailments on monsters: burning, frozen (ice shell), chilled, shocked (crawling arcs), poisoned, blinded
- [x] 2D bursts / rings / flashes are drawn in 3D while the 3D view is on (no more flat circles over the fight)
- [x] Boss: Morrhal, the Hollow King. The arena seals with soulfire; letterbox entrance; big bar with phase marks and a
      damage trail; phase 1 Crownbreaker spin, chasing triple slam with a punish window, Grave Rend fissures; phase 2 (70%)
      soul volleys, Crown of Rime (in, then out), summoned guard; phase 3 (40%) leaps to the centre, soulfire ring shrinks
      the arena, chasing Pale Lightning; enrage at 15%; loot shower and "Chapter I complete"
- [x] Tests: `--chapter-probe` (21 checks: map, connectivity, monsters, named rares, 17 spells cast, boss phases, arena seal/open);
      pad test adds 9 chapter checks (title focus, stick, RT/X/B/Y casts, loadout swap, spellbook open/close)
- [x] Chapter I is the test chapter (Jason): all spells unlocked; pacing and spell-earning come later for the real campaign
- [x] Interaction (Jason): chests, items, currency, herbs, levers, kettle are used with A (pad, context prompt), click
      (walk to it) or G; pause-menu toggles Auto-loot and Auto-gather, off by default, saved in settings
- [x] Herbalism, the first trade: Emberhood (forest), Bogbloom (swamp), Gravemoss (barrow), about 70 patches that regrow;
      herbs live in the purse with where they grow and what they brew; the Herbalist's Kettle in the camp: Steeped Flask
      (3 ranks), four 3-minute tonics, Wardstone Philter (needs all three regions). Costs and effects shown before brewing
- [x] World shortcuts: Old Drawbridge (lever on the swamp side lowers it over the river), Barrow Gate (opened from the
      barrow side), Leaning Deadwood (knock the dead tree down across the water)
- [x] Readability: every normal monster attack has a short tell (melee arc / shot line / cast ring) in the test chapter;
      trees and tall props between the camera and the hero dither-fade; flash lights capped at 10 and impact floods drawn small
- [x] Playtest 1 (Jason, 2026-11-27): boss arena reopens after death and reseals on re-entry; boss slowed; open areas with
      linear connectors; river bridge spans the water
- [ ] Not verified on Jason's PC: frame rate, look, controller feel. Screenshots taken with software rendering (1-2 fps)
- [ ] Monster balance and boss tuning are first guesses; needs play
- [ ] Wind sway on vegetation, canopy fade near the hero, footstep/ambience sounds per region
- [ ] Spell icons on the bar for the new spells are placeholders from the old set
- [ ] Waystone travel menu (now: respawn points only); co-op
