class_name SkillsDB
extends RefCounted
## Rites (skills). Pure data; behaviour is chosen by "behavior".
## base_damage: {type: [min, max]} at gem level 1.
## time: base seconds per use (scaled by attack/cast speed). cost: mana. cooldown: seconds.

const SKILLS := {
	"ember_bolt": {
		"name": "Ember Bolt", "kind": "spell", "behavior": "projectile",
		"desc": "Hurl a bolt of ember-fire that ignites what it strikes.",
		"base_damage": {"fire": [11, 18]}, "crit": 7.0, "time": 0.42, "cost": 5,
		"ignite_chance": 25.0, "tags": ["projectile"], "speed": 820.0, "radius": 12.0,
		"color": Color(1.0, 0.5, 0.15), "range": 900.0,
	},
	"cleave": {
		"name": "Ashen Cleave", "kind": "attack", "behavior": "melee_arc",
		"desc": "A wide swing with your weapon. Hits everything in the arc.",
		"base_damage": {}, "crit": 5.0, "time": 0.5, "cost": 0, "effectiveness": 130.0,
		"tags": ["melee", "area"], "arc_deg": 140.0, "radius": 120.0,
		"color": Color(0.95, 0.9, 0.8),
	},
	"frost_nova": {
		"name": "Rimeburst", "kind": "spell", "behavior": "nova",
		"desc": "Freezing light bursts from you, chilling everything nearby.",
		"base_damage": {"cold": [16, 24]}, "crit": 6.0, "time": 0.35, "cost": 14, "cooldown": 2.5,
		"chill_chance": 80.0, "tags": ["area"], "radius": 190.0,
		"color": Color(0.5, 0.85, 1.0),
	},
	"arc_spark": {
		"name": "Stormthread", "kind": "spell", "behavior": "chain",
		"desc": "Lightning leaps between foes. Highly variable damage, chains 4 times.",
		"base_damage": {"lightning": [3, 34]}, "crit": 9.0, "time": 0.5, "cost": 9,
		"shock_chance": 30.0, "tags": ["chain"], "chains": 4, "range": 520.0, "chain_range": 300.0,
		"color": Color(1.0, 0.95, 0.45),
	},
	"cinder_field": {
		"name": "Cinderfall", "kind": "spell", "behavior": "ground",
		"desc": "Call burning ash onto the ground at your cursor for 4 seconds.",
		"base_damage": {"fire": [5, 7]}, "crit": 3.0, "time": 0.5, "cost": 18, "cooldown": 5.0,
		"tags": ["area", "duration"], "radius": 150.0, "duration": 4.0, "tick": 0.25,
		"color": Color(1.0, 0.35, 0.1), "range": 700.0,
	},
	# --- Monster skills ---
	"husk_claw": {"name": "Claw", "kind": "attack", "behavior": "melee_arc", "base_damage": {"physical": [3, 5]},
		"crit": 5.0, "time": 1.25, "arc_deg": 90.0, "radius": 46.0, "tags": ["melee"], "color": Color(0.8, 0.8, 0.7)},
	"cinder_spit": {"name": "Cinder Spit", "kind": "spell", "behavior": "projectile", "base_damage": {"fire": [4, 7]},
		"crit": 5.0, "time": 1.6, "speed": 380.0, "radius": 10.0, "tags": ["projectile"],
		"color": Color(1.0, 0.45, 0.2), "range": 600.0},
	"rattler_slash": {"name": "Rattle", "kind": "attack", "behavior": "melee_arc", "base_damage": {"physical": [2, 4]},
		"crit": 5.0, "time": 0.8, "arc_deg": 90.0, "radius": 44.0, "tags": ["melee"], "color": Color(0.9, 0.9, 0.85)},
	"rime_bolt": {"name": "Rime Bolt", "kind": "spell", "behavior": "projectile", "base_damage": {"cold": [4, 7]},
		"crit": 5.0, "time": 1.8, "speed": 420.0, "radius": 10.0, "tags": ["projectile"], "chill_chance": 35.0,
		"color": Color(0.5, 0.85, 1.0), "range": 650.0},
	"raise_dead": {"name": "Raise Dead", "kind": "spell", "behavior": "summon", "base_damage": {},
		"time": 1.2, "cooldown": 6.5, "count": 2, "minion": "rattler", "max_minions": 6, "tags": [],
		"color": Color(0.6, 1.0, 0.6)},
	"brute_slam": {"name": "Slam", "kind": "attack", "behavior": "telegraph", "base_damage": {"physical": [16, 24]},
		"crit": 5.0, "time": 2.2, "radius": 135.0, "windup": 0.75, "tags": ["area"], "color": Color(0.9, 0.6, 0.4)},
	"regent_sweep": {"name": "Crown Sweep", "kind": "attack", "behavior": "melee_arc", "base_damage": {"physical": [26, 38]},
		"crit": 5.0, "time": 0.9, "arc_deg": 180.0, "radius": 190.0, "tags": ["melee"], "color": Color(1.0, 0.8, 0.4)},
	"regent_nova": {"name": "Hollow Flare", "kind": "spell", "behavior": "telegraph", "base_damage": {"fire": [38, 54]},
		"crit": 5.0, "time": 1.25, "radius": 300.0, "windup": 1.1, "tags": ["area"], "color": Color(1.0, 0.4, 0.1)},
	"regent_volley": {"name": "Ember Volley", "kind": "spell", "behavior": "radial", "base_damage": {"fire": [12, 18]},
		"crit": 5.0, "time": 0.8, "speed": 360.0, "radius": 12.0, "count": 16, "tags": ["projectile"],
		"color": Color(1.0, 0.6, 0.2), "range": 900.0},
}

const PLAYER_BAR := ["ember_bolt", "cleave", "frost_nova", "arc_spark", "cinder_field"]
const BAR_KEYS := ["LMB", "RMB", "Q", "E", "R"]
