# Hollowcrown — Design Doc

> Working title. Living document: this file and ROADMAP.md are the project's memory.
> Every session (human or Claude) starts by reading them and ends by updating them.

## Pitch
A dark-fantasy co-op ARPG for a small group of friends. Few zones, deep builds.
The goal is not to out-content Path of Exile or Grim Dawn; it is to match their
**build-crafting depth** with a smaller, tighter world we fully own and keep expanding.

## Pillars
1. **Builds are the game.** Every system feeds theorycrafting: damage types,
   conversion, increased vs more, ailments, skill interactions. Off-meta should be viable.
2. **Combat feels great in the first 10 seconds.** Hit-stop, knockback, shake, numbers, light.
3. **Loot you read.** Rolled affixes with tiers; a rare can be better than a unique.
4. **Co-op from the foundation.** 1–4 players. Code is written so multiplayer is an
   addition, not a rewrite (see Architecture).
5. **Ours.** No expansion fees. Content grows as we build it.

## Setting (placeholder — replace freely)
The kingdom of Vael crowned its last king with a relic called the Ember Crown.
When he died, the crown went hollow and the fire inside it scattered across the land
as embers that take root in the dead. The Hollowing spreads: ash, cold light, things
that remember being people. The player is a **Kindled**: someone who can take embers
into themselves. Progression flavor: the passive tree is the **Ember Constellation**,
and skills are **Rites**.

## Core loop (prototype)
Enter zone → clear packs → loot drops → equip / compare → level up → boss → next zone.

## Combat model
- Top-down 2D, mouse aim, WASD move, Space to dodge (i-frames).
- Skills: LMB, RMB, Q, E, R. Each skill is data (`scripts/data/skills_db.gd`) plus a behavior.
- Damage types: physical, fire, cold, lightning, chaos.
- Final damage per type = (base + flat added) × (1 + Σ increased) × Π(1 + more) after conversion.
- Conversion runs physical → lightning → cold → fire → chaos (PoE order). Converted damage
  is affected by modifiers to both its original and final types ("gained as" later).
- Crit: chance and multiplier. Resistances cap at 75%.
- Ailments: **Ignite** (fire DoT from fire hits), **Chill** (slow from cold hits),
  **Shock** (increased damage taken from lightning hits).

## Items
- Slots: weapon, helm, body, gloves, boots, ring ×2, amulet.
- Rarity: normal (0 affixes), magic (1–2), rare (3–6), unique (fixed mods, later).
- Affixes come in tiers gated by item level; prefixes/suffixes max 3 each.

## Architecture (for future co-op)
- **Simulation vs presentation.** Damage, stats, AI and loot rolls are plain logic in
  `scripts/core`, `scripts/items`, `scripts/data`. Visual feedback goes through `FX`
  signals so a client can replay effects without running the simulation.
- **Input abstraction.** The player reads intents from a `PlayerInput` object, never the
  keyboard directly. Networking will swap local input for a remote one.
- **Seeded randomness.** Loot and level generation use explicit RandomNumberGenerator
  seeds so the host can be authoritative.
- **Data-driven content.** Skills, affixes, base items and enemies are dictionaries in
  `scripts/data/`. New content should rarely need new code.

## Art direction (for now)
No sprite art yet: shapes, glow and particles drawn in code, high contrast on a dark ground.
A real art pipeline (AI-generated or licensed sprites) is a later milestone; entity
visuals are isolated in `_draw()` / visual child nodes so they can be swapped.
