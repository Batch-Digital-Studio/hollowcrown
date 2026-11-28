# Hollowcrown decisions log

What Jason has confirmed, and what is still open. Newest first.

How we decide: `docs/PHILOSOPHY.md` (Jason's ARPG design philosophy brief, 2026-11-27). Every significant system
gets the brief's checklist: player need, pillar, moment-to-moment action, decision added, how it is explained,
respect for time, risks, smallest prototype, keep/change/remove evidence.

## Confirmed
- 2026-11-27 **Combat pace: a blend of all three** (Jason: "a great game has a blend"). Fast packs to tear through,
  deliberate elites/rares with tells, tactical bosses. Classes may lean different ways.
- 2026-11-27 **Map interaction, first form: world shortcuts** (gates, bridges, levers that change routes). Optional
  challenge modifiers come later in the campaign; an endgame map system is planned later.
- 2026-11-27 **Gathering and crafting: a substantial side path.** Regional materials and recipes that matter, never
  required for core gear.
- 2026-11-27 **The current "Chapter I: The Hollow Crown" is a test chapter**, not the real campaign opening. It is the
  testbed where mechanics, visuals, monsters and systems are proven before the story campaign is designed and built.
  Names, story beats and layout there are placeholders.
- 2026-11-27 **Test chapter tests everything:** all spells stay unlocked there. Restrictions and pacing (earning
  elements, the "hook") come once it runs smoothly, then roll out to the real campaign chapters.
- 2026-11-27 **Chapter I goal (until the story is written):** fun, introduces mechanics one by one, basic gathering and
  crafting, visually appealing, and a hook that makes players chase progress.
- 2026-11-27 **Engine: Godot** (final, Jason: "Godot it is"). Unreal test project kept only for reference.
- 2026-11-27 **New build first:** Chapter I is perfected on its own, then rolled out to the rest of the game.
- 2026-11-27 **World feel:** open-world-feeling chapters that flow region to region (forest -> swamp -> barrow), like PoE / Last Epoch acts.
- 2026-11-27 **One class first:** a Mage with Fire, Ice, Lightning, Chaos and Light; each element must look like itself.
- 2026-11-27 **Monsters fit their region; rares are named with real abilities; the boss is a real boss** (arena, phases, tells).
- 2026-11-27 **Co-op 1-4 is part of the vision** (DESIGN.md pillar 4); the core game must also be fully playable solo (philosophy brief).
- 2026-11-27 **Controller first:** everything playable on an Xbox controller (CLAUDE.md).
- 2026-11-27 **No MMO structures by default:** no dailies, always-online, auction house, or paid power (philosophy brief).
- 2026-11-27 **Engine:** stay in Godot for now; run a *small* Unreal side-by-side test (same camera, the same exported assets, one spell, one patch of forest, on Jason's PC) before any migration decision. Godot moves to the Forward+ renderer so the comparison is fair.
- 2026-11-27 **Art style:** grounded, slightly stylized (Path of Exile 2 / Diablo IV mood; real proportions and materials, shapes pushed a little so they read from the isometric camera).
- 2026-11-27 **KayKit models:** placeholders, replaced by our own original models over time, region by region.
- 2026-11-27 **First scenery region:** Whisperwood (dying forest): trees, undergrowth, fungi, animals, falling leaves, mist, a landmark.
- 2026-11-27 **Production rule (Jason's brief):** shipped art is our own (Blender scripts, procedural textures, our drawings); keep the source and the recipe for every asset.
- 2026-11-27 Camera: fixed isometric (45 deg yaw, 52 deg elevation, orthographic). Keep unless agreed otherwise.
- 2026-11-27 Art route: real-time 3D (chosen over 2D sprites).

## Assumptions (made by Claude, not confirmed; easy to reverse)
- Chapter I's map is authored by data (route, glades, river, caches placed in `chapter_db.gd`) and filled in by a seeded
  generator; the same seed every time, so players can learn it. Not a random map per run.
- Combat pace so far: mid-speed (deliberate monster tells, fast spells). Not tuned against a stated target.
- First trade: herbalism (one herb per region, brewed at the camp). Chosen by Claude to fit the Mage; easy to swap.

## Open
- Fab / Quixel Bridge (installed by Jason): third-party stock; reference only under the original-art rule unless Jason decides otherwise.
- First minute of play: enhance the Ashfall Crypt opening or build a new opening region?
- World structure (linked zones as now, or seamless), platforms and minimum hardware.
