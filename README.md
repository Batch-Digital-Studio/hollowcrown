# Hollowcrown

A co-op dark-fantasy ARPG prototype, built in Godot 4.7. This is Milestone 0, the combat prototype.

## Play it
1. Open Godot 4.7.2 → **Import** → pick this folder's `project.godot` → **Import & Edit**.
2. Press **F5** (or the ▶ Play button, top right).

The first import takes a few seconds while Godot scans the files.

## Controls (Xbox controller)
| Button | Action |
|---|---|
| Left stick | Move |
| Right stick | Aim. Let go and it auto-targets the nearest enemy you're facing |
| A or RT (hold) | Ember Bolt |
| X | Ashen Cleave |
| B | Rimeburst |
| Y | Stormthread |
| RB | Cinderfall |
| LT | Dodge roll |
| LB | Life flask |
| View | Inventory (left stick = cursor, A equip, X twice shatter, B close) |
| D-pad Up | Ember Constellation (left stick cursor, A allocate, X refund, right stick pan, LB/RB zoom, B close) |
| Menu | Pause |

Taps are buffered for 0.3 s, so pressing a skill during another cast still fires it. Rumble on hits, slams, level-ups, uniques, boss kill.

## Controls (keyboard + mouse)
| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Aim |
| Left click (hold) | **Ember Bolt**: fire projectile that ignites |
| Right click (hold) | **Ashen Cleave**: wide weapon swing |
| Q | **Rimeburst**: cold nova that chills (cooldown) |
| E | **Stormthread**: chain lightning, 4 chains |
| R | **Cinderfall**: burning ground at cursor (cooldown) |
| Space | Dodge roll (brief invulnerability) |
| 1 | Life flask (charges refill from kills) |
| I / Tab | Inventory + character sheet |
| Esc | Pause |

## What's in it
- PoE-style damage engine: flat / increased / more, conversion chains, crits, armour, resistances,
  Ignite / Chill / Shock.
- 5 Rites, 3 monster types, magic and rare monsters with modifiers, and a two-phase boss (The Ashen Regent).
- Loot: normal / magic / rare / unique, tiered affixes, 5 build-enabling uniques.
- Hover an item to see what equipping it would change, including per-skill DPS.
- Endless descent: kill the boss → portal → next depth, harder, better loot.
- Autosave (character, gear, depth).

## For developers (and Claude)
- Design doc: `docs/DESIGN.md`. Roadmap: `docs/ROADMAP.md`.
- Tests:
  - `godot --headless --path . -s res://scripts/tests/test_damage.gd`
  - `godot --headless --path . res://scenes/test_items.tscn`
  - Controller test: `godot --headless --path . --fixed-fps 60 -- --fresh --seed=3 --pad-test`
  - Bot smoke test: `godot --headless --path . --fixed-fps 60 -- --autoplay --fresh --quit-after=300`
