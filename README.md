# Hollowcrown

A co-op dark-fantasy ARPG prototype, built in Godot 4.7. Built with Claude, one stage at a time (see `docs/ROADMAP.md`).

## Play it
1. Open Godot 4.7.2 → **Import** → pick this folder's `project.godot` → **Import & Edit**.
2. Press **F5** (or the ▶ Play button, top right).

The first import takes a few seconds while Godot scans the files.

## Controls (Xbox controller)
| Button | Action |
|---|---|
| Left stick | Move (and the cursor in menus) |
| Right stick | Aim. Let go and it auto-targets the nearest enemy you're facing |
| RT, A, X, B, Y, RB | Rite slots 1-6 (hold to repeat) |
| LB + RB together | Class Special (Grand Rite, Cataclysm, Oathbreaker, Hunter's Moon) |
| LB | Life flask |
| LT | Dodge roll |
| D-pad Left / Right | Swap loadout (weapon + six Rites) |
| D-pad Up | Ember Constellation (A allocate, A again on a Mastery to switch it, X refund, right stick pan, LB/RB zoom, B close) |
| D-pad Down | Class screen: class tree, Rite specializations, skill bar, Ascension tab (A take, X refund, B close) |
| View | Inventory + purse (A equip / pick up currency / buy, X twice shatter or sell next to the Peddler, B drop currency or close) |
| Menu | Pause |

Taps are buffered for 0.3 s, so pressing a skill during another cast still fires it. Rumble on hits, slams, level-ups, uniques, boss kill.
Walk onto seals to use them (Rift Seal, Ascension Trial). Stand next to a Reliquary for one second to open it.

## Controls (keyboard + mouse)
| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Aim |
| Left click, right click, Q, E, R, F | Rite slots 1-6 |
| T | Class Special |
| Space | Dodge roll |
| 1 | Life flask |
| X | Swap loadout |
| I / Tab | Inventory + purse + Peddler shop |
| P | Ember Constellation |
| K | Class screen |
| Esc | Pause |

## What's in it
- Four classes (Bog Shaman, Ember Magus, Oathsworn, Hollow Ranger), each with a resource, a Special, a 3-branch class tree and its Rites with specialization trees. Pick a second class at level 10.
- 12 Ascensions (3 per class), earned through Ascension Trials after the Regent on depths 5, 10, 15 and 20.
- The Ember Constellation: 145 shared passives, 8 regions with Masteries, 12 keystones, a start star per class.
- PoE-style damage: flat / increased / more, conversion, crits, armour, resistances, ignite / chill / shock / poison / freeze, curses.
- Loot: normal / magic / rare / unique, tiered affixes, rift-only uniques. Crafting currencies and Essences. Two loadouts.
- League-style mechanics: Hollow Rifts (and the Rift Lord), Reliquaries, Bound Embers, Writs of the Hollow King, the Ashen Peddler.
- Endless descent: kill the Regent, take the portal, go deeper. Autosave.
- Controller-first: everything works on an Xbox pad (see the table above).

## For developers (and Claude)
- Design doc: `docs/DESIGN.md`. Roadmap: `docs/ROADMAP.md`.
- Tests:
  - `godot --headless --path . -s res://scripts/tests/test_damage.gd`
  - `godot --headless --path . res://scenes/test_items.tscn`
  - `godot --headless --path . res://scenes/test_crafting.tscn`
  - Controller test: `godot --headless --path . --fixed-fps 60 -- --fresh --seed=3 --pad-test`
  - Class time-to-kill benchmark: `godot --headless --path . --fixed-fps 60 -- --autoplay --fresh --seed=5 --class=magus --ttk`
  - Ascension / keystone probe: `godot --headless --path . --fixed-fps 60 -- --autoplay --fresh --seed=5 --class=magus --asc-probe`
  - Bot smoke test: `godot --headless --path . --fixed-fps 60 -- --autoplay --fresh --quit-after=300`
