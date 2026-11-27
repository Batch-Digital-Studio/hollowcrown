class_name AscensionsDB
extends RefCounted
## Twelve ascensions, three per class, six notables each. Ascension Points come from
## Ascension Trials (2 per trial, after the Regent on depths 5, 10, 15, 20), so 8 at most.
##
## A notable can carry:
##   "stats":       character stats (folded in like gear)
##   "skill":       {skill_id: {key: add}}   numeric changes to a Rite ("_pct" keys scale: cooldown_pct: -30)
##   "skill_stats": {skill_id: {stat: v}}    stats used only when casting that Rite
## Behaviour flags (stats such as "block_nova") are read by scripts/classes/asc.gd.

const POINTS_PER_TRIAL := 2
const TRIAL_DEPTHS := [5, 10, 15, 20]

const ASC := {
	# ---------------- Oathsworn ----------------
	"ashguard": {"class": "oath", "name": "Ashguard", "flavor": "The wall the party stands behind.", "color": Color(0.8, 0.85, 1.0),
		"nodes": [
			{"name": "Unbreakable", "desc": "+15% to the block cap; each block restores 2% of life", "stats": {"block_cap_add": 15, "block_heal": 2, "block_chance": 5}},
			{"name": "Ember Retaliation", "desc": "Blocking releases a fire nova (1 s cooldown)", "stats": {"block_nova": 1}},
			{"name": "Shieldwall", "desc": "You and allies within 6 m take 12% less damage", "stats": {"shieldwall": 12}},
			{"name": "Last Stand", "desc": "Falling below 30% life: take 40% less damage for 4 s (30 s cooldown)", "stats": {"last_stand": 1}},
			{"name": "Stoneblood", "desc": "Gain armour equal to 3x your Resolve", "stats": {"armour_per_resolve": 3}},
			{"name": "Taunting Presence", "desc": "Oath of Embers taunts and grants 4 Resolve per enemy", "stats": {"warcry_resolve": 4}},
		]},
	"pyre_templar": {"class": "oath", "name": "Pyre Templar", "flavor": "Every swing a sermon of fire.", "color": Color(1.0, 0.55, 0.2),
		"nodes": [
			{"name": "Kindled Steel", "desc": "50% of physical damage converted to fire", "stats": {"conv_physical_to_fire": 50, "ignite_chance": 10}},
			{"name": "Searing Faith", "desc": "When an ignited enemy dies its ignite spreads to 2 enemies", "stats": {"ignite_spread": 2}},
			{"name": "Pyre of Judgment", "desc": "Judgment Brand detonations leave burning ground", "stats": {"brand_ground": 1}},
			{"name": "Martyr's Flame", "desc": "Gain 5 Resolve when an ignited enemy dies", "stats": {"resolve_on_ignite_kill": 5}},
			{"name": "Holy Brand", "desc": "Ignites deal 30% more to branded enemies", "stats": {"holy_brand": 30}},
			{"name": "Solar Oath", "desc": "Oathbreaker lasts 4 s longer and burns everything near you", "stats": {"solar_oath": 1}, "skill": {"oathbreaker": {"duration": 4.0}}},
		]},
	"warlord": {"class": "oath", "name": "Warlord", "flavor": "A general without a king. Best in co-op.", "color": Color(1.0, 0.8, 0.4),
		"nodes": [
			{"name": "Raise the Banner", "desc": "Place 2 banners", "stats": {"banner_max_add": 1}},
			{"name": "Sworn Squires", "desc": "2 spectral knights fight at your side", "stats": {"squires": 2}},
			{"name": "Rallying Cry", "desc": "Warcries give you and your minions 20% attack speed", "stats": {"rally_speed": 20}},
			{"name": "Commander's Will", "desc": "Gain 3 Resolve when an ally or minion kills", "stats": {"resolve_on_ally_kill": 3}},
			{"name": "Iron Discipline", "desc": "Buffs and banners you place last 50% longer", "stats": {"inc_buff_duration": 50, "inc_totem_duration": 50}},
			{"name": "Shared Oath", "desc": "Oathbreaker also empowers your minions (40% more damage)", "stats": {"shared_oath": 1}},
		]},
	# ---------------- Ember Magus ----------------
	"pyromancer": {"class": "magus", "name": "Pyromancer", "flavor": "Fire that never goes out.", "color": Color(1.0, 0.45, 0.15),
		"nodes": [
			{"name": "Everburn", "desc": "Ignites stack up to 3 times", "stats": {"ignite_stacks": 3}},
			{"name": "Ashfall Mastery", "desc": "Cinderfall follows you and is 25% larger", "skill": {"cinder_field": {"follow": 1.0, "radius_pct": 25.0}}},
			{"name": "Combustion", "desc": "Burning enemies explode on death for 10% of their life", "stats": {"combustion": 10}},
			{"name": "Fire Within", "desc": "Immune to ignite, +30% fire resistance", "stats": {"res_fire": 30, "ignite_immune": 1}},
			{"name": "Wildfire Heart", "desc": "Ember Bolt always ignites at full Kindling", "stats": {"wildfire_heart": 1}},
			{"name": "Inferno Crown", "desc": "Cataclysm meteors leave burning ground", "stats": {"inferno_crown": 1}},
		]},
	"rimeweaver": {"class": "magus", "name": "Rimeweaver", "flavor": "Freeze it, then break it.", "color": Color(0.55, 0.85, 1.0),
		"nodes": [
			{"name": "Absolute Zero", "desc": "Chilled enemies below 30% life freeze for 1.5 s", "stats": {"freeze_below": 30}},
			{"name": "Shatter", "desc": "Frozen enemies explode into ice shards on death", "stats": {"shatter": 1}},
			{"name": "Rime Mantle", "desc": "+200 armour, +50% armour, chill enemies that hit you", "stats": {"armour": 200, "inc_armour": 50, "chill_attackers": 1}},
			{"name": "Glacial Echo", "desc": "Frost Lance fires a second lance", "skill": {"frost_lance": {"extra_proj": 1.0}}},
			{"name": "Winter's Grasp", "desc": "Chill effect +50%", "stats": {"inc_chill_effect": 50, "chill_chance": 10}},
			{"name": "Still Air", "desc": "Frozen enemies take 25% more damage", "stats": {"frozen_taken": 25}},
		]},
	"stormcaller": {"class": "magus", "name": "Stormcaller", "flavor": "Crits, chains and chaos.", "color": Color(1.0, 0.95, 0.45),
		"nodes": [
			{"name": "Overcharge", "desc": "Critical strikes apply double-strength shock", "stats": {"overcharge": 1}},
			{"name": "Branching Fate", "desc": "Chains +2", "stats": {"chain_add": 2}},
			{"name": "Static Field", "desc": "An aura zaps a nearby enemy every 0.5 s", "stats": {"static_field": 1}},
			{"name": "Thunderstep", "desc": "Blink leaves a burst of lightning orbs behind", "stats": {"thunderstep": 1}},
			{"name": "Conduit", "desc": "Damage to shocked enemies arcs to one neighbour (35%)", "stats": {"conduit": 35}},
			{"name": "Eye of the Storm", "desc": "+25% crit chance with 3+ enemies near you", "stats": {"eye_storm": 25}},
		]},
	# ---------------- Hollow Ranger ----------------
	"deadeye": {"class": "ranger", "name": "Deadeye", "flavor": "One shot, many problems.", "color": Color(0.95, 0.95, 0.75),
		"nodes": [
			{"name": "Far Shot", "desc": "Projectiles deal up to 40% more with distance travelled", "stats": {"far_shot": 40}},
			{"name": "Forking Shafts", "desc": "Projectiles fork once on hit", "stats": {"fork": 1}},
			{"name": "Marked for Death", "desc": "Hawk-marked (cursed) enemies: +25% chance to be crit", "stats": {"mark_crit": 25, "hawk_mark": 10}},
			{"name": "Steady Aim", "desc": "After standing still for 1 s, Rites deal 30% more", "stats": {"steady_aim": 30}},
			{"name": "Quiver of Ash", "desc": "+1 projectile", "stats": {"proj_count_add": 1}},
			{"name": "Perfect Focus", "desc": "Empowered shots return to you, hitting again", "stats": {"perfect_focus": 1}},
		]},
	"trapwright": {"class": "ranger", "name": "Trapwright", "flavor": "The floor is the weapon.", "color": Color(0.8, 0.75, 0.6),
		"nodes": [
			{"name": "Trap Throwing", "desc": "Caltrops reach 50% further and throw one extra field", "stats": {"trap_extra": 1}, "skill": {"caltrops": {"range_pct": 50.0}}},
			{"name": "Chain Detonation", "desc": "Explosive Bolt detonates your Caltrops for a burst", "stats": {"chain_detonation": 1}},
			{"name": "Rigged", "desc": "Traps deal 40% more to rares and bosses", "stats": {"rigged": 40}},
			{"name": "Cluster Caltrops", "desc": "Caltrops slow by 40% more", "skill": {"caltrops": {"slow": 0.25, "radius_pct": 20.0}}},
			{"name": "Quick Hands", "desc": "Trap cooldowns 30% shorter", "skill": {"caltrops": {"cooldown_pct": -30.0}, "explosive_bolt": {"cooldown_pct": -30.0}, "smoke_veil": {"cooldown_pct": -30.0}}},
			{"name": "Smoke Bombs", "desc": "Explosive Bolt explosions release a Smoke Veil", "stats": {"smoke_bombs": 1}},
		]},
	"thornwarden": {"class": "ranger", "name": "Thornwarden", "flavor": "The wood fights with you.", "color": Color(0.55, 0.85, 0.4),
		"nodes": [
			{"name": "Bog Beast", "desc": "A permanent bog beast companion", "stats": {"bog_beast": 1}},
			{"name": "Thorned Arrows", "desc": "Hits have a 30% chance to poison", "stats": {"poison_chance": 30}},
			{"name": "Rooted", "desc": "Thornvine Arrow roots for 2 s", "skill": {"thornvine_arrow": {"vine_root": 1.4}}},
			{"name": "Nature's Gift", "desc": "Your companions heal you for 1% of life per hit", "stats": {"companion_heal": 1}},
			{"name": "Hawk Fury", "desc": "Spirit Hawk attacks twice as often", "stats": {"hawk_fury": 1}},
			{"name": "Overgrowth", "desc": "Poisoned enemies are slowed by 20%", "stats": {"poison_slow": 20}},
		]},
	# ---------------- Bog Shaman ----------------
	"gravebinder": {"class": "shaman", "name": "Gravebinder", "flavor": "An army that remembers dying.", "color": Color(0.7, 0.9, 0.6),
		"nodes": [
			{"name": "Legion", "desc": "+3 maximum husks", "stats": {"minion_max_add": 3}},
			{"name": "Bone Armour", "desc": "2% less damage taken per minion, up to 20%", "stats": {"bone_armour": 2}},
			{"name": "Corpse Pact", "desc": "Minions explode on death for 8% of their life", "stats": {"husk_explode": 1}},
			{"name": "Ember Bones", "desc": "Minions convert 60% of physical damage to fire", "stats": {"minion_fire": 60}},
			{"name": "Undying Will", "desc": "Each husk revives once, 4 s after dying", "stats": {"minion_revive": 1}},
			{"name": "Lord of the Grave", "desc": "Grand Rite's horde stays until you leave the zone (max 10)", "stats": {"horde_cap": 10}, "skill": {"grand_rite": {"duration": 3000.0}}},
		]},
	"plaguebringer": {"class": "shaman", "name": "Plaguebringer", "flavor": "Rot is patient. So are you.", "color": Color(0.55, 0.95, 0.3),
		"nodes": [
			{"name": "Virulence", "desc": "Poison stack limit raised from 40 to 200", "stats": {"virulence": 1}},
			{"name": "Rotting Touch", "desc": "Hex of Rot spreads when the target dies", "stats": {"hex_spread": 1}},
			{"name": "Pandemic", "desc": "Plague Cloud follows you", "skill": {"plague_cloud": {"follow": 1.0}}},
			{"name": "Toxic Blood", "desc": "Enemies that hit you are poisoned", "stats": {"poison_attackers": 1}},
			{"name": "Chaos Bloom", "desc": "Chaos damage ignores 30% of resistance", "stats": {"chaos_pen": 30}},
			{"name": "Withering", "desc": "Enemies take 1% more damage per poison stack, up to 20%", "stats": {"withering": 1}},
		]},
	"totem_sage": {"class": "shaman", "name": "Totem Sage", "flavor": "The Grim Pillars stand again.", "color": Color(0.85, 0.75, 0.5),
		"nodes": [
			{"name": "Grim Pillars", "desc": "+2 maximum totems", "stats": {"totem_max_add": 2}},
			{"name": "Totem Link", "desc": "Spirit Totems fire a second linked bolt", "stats": {"totem_link": 1}},
			{"name": "Ancestral Ward", "desc": "15% less damage taken while near your totem", "stats": {"totem_ward": 15}},
			{"name": "Deep Roots", "desc": "Totems are invulnerable for 3 s after placing", "stats": {"totem_invuln": 3}},
			{"name": "Spirit Conduit", "desc": "Totem kills give 4 Spirit", "stats": {"totem_spirit": 4}},
			{"name": "Pillar of the Crown", "desc": "Near two of your totems: 20% more damage", "stats": {"pillar": 20}},
		]},
}

static func for_class(cls: String) -> Array:
	var out: Array = []
	for k in ASC:
		if ASC[k]["class"] == cls:
			out.append(k)
	return out
