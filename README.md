# Hollowcrown

A co-op dark-fantasy ARPG prototype, built in Godot 4.7. This is Milestone 0, the combat prototype.

## Play it
1. Open Godot 4.7.2 → **Import** → pick this folder's `project.godot` → **Import & Edit**.
2. Press **F5** (or the ▶ Play button, top right).

The first import takes a few seconds while Godot scans the files.

## Controls
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
  - Bot smoke test: `godot --headless --path . --fixed-fps 60 -- --autoplay --fresh --quit-after=300`
