# Hallowcrown | ARPG Design Philosophy and Creative Brief

**For Claude Code working in the existing Hallowcrown project**  
**Purpose:** turn lessons from established ARPGs and MMORPGs into a coherent design direction for Hallowcrown.

## The north star

Build a memorable dark-fantasy action RPG that is satisfying to control, easy to understand at first, and rewarding to master over time. Give players a distinctive world to explore, expressive characters to build, exciting enemies to learn, loot that creates real decisions, and optional gathering and crafting that make locations feel useful and alive.

Borrow proven design strengths as principles. Do not combine every system just because a successful game has it. Hallowcrown must remain an ARPG. The repeated core should be direct character control, real-time combat, readable threats, meaningful character growth, equipment and skill choices, and a rewarding loop of exploration, encounters, loot, and greater challenges.

The desired result is a focused identity with breadth earned over time. It should feel like Hallowcrown, not a checklist of borrowed features.

## How to use this brief

1. Read the existing project, current game systems, established lore, assets, and the accompanying research report before proposing changes.
2. Tell me what the project already supports and what appears unfinished. Separate confirmed facts from assumptions.
3. Ask the few high-impact questions that block a confident design decision. Give short options and explain the consequence of each. Do not ask again about choices already recorded in the project or that I have answered.
4. Keep developing independent, reversible improvements while awaiting answers. Do not replace the current engine or make a large, irreversible rework without presenting a concrete comparison and getting my direction.
5. Turn each confirmed decision into a concise design record in the project. When new work conflicts with an earlier decision, explain the conflict and ask before changing the record.
6. Implement a coherent playable slice, check it in the normal game, and iterate on the observed result. A written concept or disconnected asset is not a finished gameplay feature.

## What makes the game an ARPG

Protect these pillars in every feature proposal:

- The player directly controls a character in real time.
- Movement, attacks, spells, enemy telegraphs, and impact feedback feel responsive and understandable.
- Combat is the main activity. Exploration, story, collection, and crafting support it without replacing it.
- Skills and equipment alter tactics, strengths, or combat rhythm, rather than only inflating numbers.
- Enemies and bosses create readable situations that players can learn and respond to.
- Rewards arrive through play and support character improvement or expression.
- The player can meaningfully play alone. If co-op is part of the confirmed vision, design shared play deliberately rather than making solo balance an afterthought.

Do not introduce MMO structures by default. Hallowcrown does not need mandatory raids, daily login chores, multiple character rosters, server economies, auction houses, or always-online systems to borrow what players like about MMOs.

## Borrow these strengths

| Strength | Useful model | Hallowcrown interpretation |
| --- | --- | --- |
| Readable, satisfying combat | Diablo III, Lost Ark, Hero Siege | Strong movement response, clear attack anticipation, sound and hit reactions, and a satisfying spell-to-impact arc. Readability must survive the fixed isometric camera and overlapping effects. |
| Atmospheric world | Diablo IV, Diablo II, Path of Exile | Distinct regional light, weather, materials, audio, landmarks, and environmental history. Make a place recognizable before adding sheer size. |
| Player expression and build depth | Path of Exile, Last Epoch, Grim Dawn | Start with a small set of skills and choices that visibly change how combat works. Add combinations only when players can understand their effect in-game. |
| Approachable item creation | Last Epoch | Let players deliberately improve an item, see costs and risks, and understand why a result changed. Avoid making early progress depend on obscure recipes or third-party tools. |
| Crafting with identity | Final Fantasy XIV, World of Warcraft | Make gathering and crafting useful activities with regional materials, recipes, and a clear role. Let players pursue these systems at their own pace. |
| Exploration that gives something back | Guild Wars 2 | Put discoverable events, resources, paths, landmarks, and optional encounters into the region. Exploration should reward curiosity without making players follow a wiki. |
| Long-term goals | Guild Wars 2, Diablo, WoW | Use optional mastery, rare cosmetic rewards, boss challenges, collection goals, and carefully paced character upgrades. Keep near-term goals rewarding too. |
| Self-paced replay | Grim Dawn, Torchlight II | Support solo play and repeatable content that feels complete without a constant live-service schedule. |

These references describe design strengths, not asset or interface templates. Use Hallowcrown’s own world, lore, characters, visual language, and mechanics.

## Use common failure modes sparingly

Treat each of these as a design risk to solve, not as an assumed genre requirement.

| Risk | Direction for Hallowcrown |
| --- | --- |
| Repetitive chores and campaign replay | Avoid daily attendance requirements. Repeated activities should offer variety, optionality, and persistent progress. If a campaign is replayed, make the route shorter or meaningfully different after the first completion. |
| Opaque character systems | Explain affixes, skills, crafting costs, status effects, and enemy tells in the game. Offer advanced depth after the basics are clear. |
| Loot floods and inventory friction | Make drops distinct, give items useful comparison information, and avoid turning the inventory into a constant cleanup job. Let players tune loot notification only if the system can remain understandable. |
| Build traps and expensive experimentation | Let players test skills and respec at reasonable cost, especially early. Make the cost of a choice visible before it is confirmed. Preserve long-term investment through items, mastery, or specialization rather than punitive lock-in. |
| Balance changes that erase investment | Prefer targeted, communicated adjustments. Keep more than one viable way to play a class. Explain significant changes in patch notes and provide a route for players whose build is affected. |
| Progression designed around payment pressure | Avoid monetization that sells power or bypasses an intentionally unpleasant progression wall. Rewards should feel earned through play and time spent should be respected. |
| Group and gear gates | Keep the central campaign and core progression playable solo. Make cooperative challenges additive and rewarding, with clear requirements and sensible matchmaking if multiplayer is confirmed. |
| Endless number escalation | Add new enemy patterns, terrain decisions, boss mechanics, and build interactions, not only larger health pools and damage values. |
| Required outside guides | Put critical crafting, drop, quest, and combat information into the interface or the game world. External guides can deepen mastery but should not teach basic survival. |
| Screen-filling visual effects | Preserve enemy tells, player position, ground hazards, loot, and paths. Art may be dramatic while keeping important combat information visible. |

A feature is not automatically bad because another game received complaints about it. Identify the underlying friction, then test Hallowcrown’s own version with players.

## Graphics, animation, audio, and readability

Graphics are part of the gameplay experience. They signal threat, distance, material, interactability, rarity, and mood. They also shape first impressions and how memorable a region feels. A high-fidelity renderer by itself does not make a compelling ARPG. Art succeeds when it serves both world identity and play.

### Art direction

- Keep a consistent visual identity across characters, terrain, effects, UI, and animation.
- Use grounded dark-fantasy materials and atmospheric depth while retaining clear silhouettes and readable color groupings.
- Establish a region’s visual signature through a few distinctive elements, such as a landmark silhouette, a material palette, a local lighting condition, and a characteristic plant or creature.
- Create unique focal points and strong composition rather than filling every screen with detail.
- Use environmental storytelling through remains, architecture, creature behavior, paths, resource placement, and changes in the landscape.
- Verify the fixed isometric camera at actual gameplay scale. Check feet placement, pivots, shadows, facing direction, occlusion, animation readability, and spell landing positions.

### Gameplay clarity

At a glance the player should be able to identify:

1. Their own character and current action.
2. Nearby enemies and the dangerous area of an attack.
3. The safe space or movement route.
4. The target or area of their own spell.
5. A meaningful drop or interaction point when it matters.

Use contrast, silhouette, motion timing, sound cues, and restrained effects. Test scenes with several enemies and repeated casting, not only an isolated screenshot. Allow effects and hazards to overlap visually in a way that does not hide key information. The player must not move because the cursor moved over an open menu.

### Performance and scope

Choose the art pipeline after inspecting the current renderer, hardware target, asset formats, and existing project. Reuse the tools and engine systems already working. Prefer a small set of cohesive, well-finished assets before a large amount of inconsistent content. Measure frame time and load time in the real gameplay scene when possible. Provide lower-cost materials, particle counts, shadows, or level-of-detail options where the target hardware needs them.

Do not chase photorealism at the cost of frame rate, combat readability, asset production capacity, or the isometric composition. Distinct art direction and consistency are more important than a raw polygon or texture count.

## World size, region design, and map structure

“Massive world” should mean a world with memorable places, meaningful differences, and reasons to return, not simply a large land area. Build one high-quality region at a time and connect regions through lore, geography, travel, faction history, resources, and escalating threats.

For each region, establish:

- A visual identity and emotional tone.
- A clear layout that supports combat and navigation from the fixed camera.
- One or more landmarks players can recognize and use to orient themselves.
- Optional paths, small secrets, resources, and encounters that reward exploration.
- A believable reason for its monsters, materials, ruins, weather, and settlements to be there.
- A primary route through the region that keeps the main objective understandable.
- A few variations in encounter composition, sight lines, elevation, cover, or hazards.
- Shortcuts or loops where they improve navigation and do not confuse progression.

Choose the world structure after confirming technical and design needs. A handcrafted connected region, linked zones, and procedural maps are all valid choices. They have different costs in authorship, replayability, navigation, and production. Avoid promising seamless world streaming until the project has demonstrated that it needs it and can support it.

Use procedural tools to create variations, not to decide the entire experience. Place landmarks, combat arenas, resource pockets, safe areas, and transitions deliberately. Players should be able to form a mental map and remember where they found something.

## Should players manipulate maps?

Possibly, if manipulation creates clear, enjoyable choices. Map control can extend an ARPG’s endgame, but it can also become a disconnected optimization screen. Decide what “manipulate” means for Hallowcrown before building it.

Potential forms include:

- **World interaction:** open a gate, lower a bridge, redirect water, activate a lift, clear a blockage, or change a route. This gives immediate spatial feedback and can reward exploration.
- **Encounter preparation:** choose an optional challenge or hazard before entering an area. The risk and reward should be visible and understandable.
- **Endgame map selection:** choose a region or mission from a board, with clear modifiers and rewards. This supports replay but can pull players out of the world if it becomes the main loop.
- **Area alteration:** change weather, enemy composition, resource density, or boss behavior through a world action. Make changes legible in the space and prevent one optimal choice from replacing all others.
- **Procedural layout:** vary rooms, routes, or encounters while preserving landmarks and readable navigation. Use this only where replay benefits more than authored structure.

Design principles for any map manipulation system:

1. State the choice, cost, risk, and expected reward before confirming it.
2. Make the result visible in gameplay, not only in a menu.
3. Preserve safe routes and clear combat spaces.
4. Do not hide required story content or essential progression behind a random roll.
5. Give players a way to recover from an unhelpful choice without excessive cost.
6. Keep optional challenge optional. Never make the unmodified map a deliberately dull baseline.
7. Tie modifications to Hallowcrown’s lore and world rather than adding abstract modifiers with no fiction.

Start with a small, testable form such as opening a shortcut or choosing one optional encounter modifier. Let playtests show whether it creates excitement before extending it to a full endgame mapping system.

## Crafting and gathering philosophy

Use crafting to make the world and character progression more connected. A resource should have a recognizable place and purpose. The player should be able to discover it, collect it, understand its uses, and make something relevant without external research.

A good first loop is:

1. Find a recognizable resource in a biome or encounter.
2. Gather it through a brief interaction or combat reward.
3. See it in the inventory with its origin and uses.
4. Use it in one near-term recipe, such as food, a potion, a weapon component, or a field tool.
5. Find a later recipe that gives the resource a longer-term reason to revisit the region.

Use a few distinct gathering activities such as herbs, fishing, mining, or lumber only when each adds a different play choice. Avoid a profession list where every job is a different skin on the same repetitive interaction. Keep essential combat gear obtainable through multiple routes so a player who dislikes gathering is not blocked.

## Progression and endgame philosophy

Plan progression around meaningful decisions and several time horizons:

- A satisfying reward or improvement in a short session.
- A near-term build or regional goal.
- A long-term optional goal such as a boss challenge, a craft, a collection, or a mastery.

Progression should make the character feel more capable while allowing the world’s threats and decisions to remain relevant. Add enemy behaviors and encounter variation alongside stat growth. Make different build paths viable, and tell players what a piece of content expects before they enter it.

If endgame maps or repeatable zones are part of the confirmed scope, ensure they change the player’s decisions. Offer varied objectives, bosses, modifiers, routes, and rewards. Do not rely solely on escalating health, damage, random penalties, or repeated chores. A player who stops for a while should be able to return and understand what to do.

## Story and world-building philosophy

Make the first region’s story understandable on its own. Introduce the local conflict through people, places, enemies, and consequences. Let deeper history emerge through optional dialogue, objects, landmarks, and discoveries. Players who want to move can keep moving; players who want more lore can find it.

Keep each quest tied to a character need, regional change, discovery, or threat. Use combat and exploration to advance the story rather than stopping play for long exposition repeatedly. The main route should provide clear motivation while optional paths deepen the world. Avoid requiring players to know years of prior lore to understand the immediate stakes.

## Decision and testing framework

For every significant proposed system, document:

- Which player need it serves.
- Which ARPG pillar it supports.
- What the player does moment to moment.
- What decision or mastery it adds.
- How it communicates rules and outcomes.
- How it respects player time.
- What can go wrong, including readability, balance, repetition, accessibility, and technical cost.
- What smaller prototype can validate the idea.
- What evidence would make us keep, change, or remove it.

Test with new players and returning players when possible. Observe what they understand without prompting, where they hesitate, what they repeat, what they ignore, and whether they want to continue. Ask what felt good and what felt like work. Do not treat a single loud opinion as proof, and do not dismiss repeated friction because it was not in the original plan.

## Claude Code operating instructions

- Begin by inspecting the existing project and its current design. Do not assume the game has systems that are not present.
- Maintain a short design log of confirmed decisions, open questions, and assumptions.
- Ask me before choosing a new core identity, replacing a major system, switching engines, adding online dependencies, or introducing a large progression model.
- Make reversible improvements autonomously, including bug fixes and small prototypes consistent with confirmed direction.
- Prefer complete playable slices over disconnected features. Wire assets and systems into the normal entry point.
- Check the actual isometric gameplay view for lighting, map scale, occlusion, animation, spell readability, movement, and performance.
- Explain what you changed, why it supports the philosophy, and what you observed in play. Clearly identify what still needs testing.
- If a feature adds complexity, demonstrate the player value that justifies the added rules and maintenance.

## First design questions for the player

Check the project and previous answers before asking. Ask the most important three to five questions first.

1. What is the desired combat speed: deliberate and tactical, fast and explosive, or a blend that varies by class?
2. Should player characters be rendered 3D models, 3D models rendered to directional sprites, or a hybrid? How grounded versus stylized should the art feel at the fixed camera zoom?
3. Should the world use handcrafted linked regions, a connected open world, replayable generated maps, or a combination across campaign and endgame?
4. What kind of map interaction sounds exciting: world shortcuts and mechanisms, optional encounter modifiers, replayable maps with chosen modifiers, or no map manipulation yet?
5. How central should gathering and crafting be: optional utility, a substantial side progression, or a major character path?
6. Is Hallowcrown designed primarily for solo play, co-op, or both equally?
7. What should the first region make a new player feel and remember?

For each answer, show a practical example and the consequence for scope. Keep working on confirmed bug fixes and low-risk foundations while design choices are pending.

## First production milestone

Build one coherent, playable region slice that demonstrates Hallowcrown’s identity:

- A memorable entrance and landmark.
- A clear route with at least one optional detour.
- One representative playable skill with readable cast, travel or area warning, impact, and recovery.
- One common enemy and one more demanding encounter with distinct tells.
- A cohesive local environment with terrain, scenery, lighting, and ambient motion.
- A resource discovery if gathering fits the intended core loop.
- Correct menu behavior, input response, camera framing, collision, occlusion, and audio feedback.

Judge the milestone by play, not asset count. A first-time player should understand where to go, enjoy moving and fighting, see what is dangerous, and want to discover what lies beyond the first landmark.

## Relationship to the companion research report

Use [ARPG_and_MMO_Design_Community_Research.md](ARPG_and_MMO_Design_Community_Research.md) as background for examples of strengths and complaints. It is a qualitative synthesis, not a mandate to copy its rankings. Recheck current versions and community sentiment before using a time-sensitive claim. Hallowcrown’s confirmed project goals and playtest evidence guide implementation.
