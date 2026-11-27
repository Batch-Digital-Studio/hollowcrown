class_name EnemiesDB
extends RefCounted

const ENEMIES := {
	"husk": {
		"name": "Ashen Husk", "life": 24, "speed": 165.0, "radius": 16.0, "xp": 9,
		"skills": ["husk_claw"], "ai": "melee", "range": 40.0,
		"color": Color(0.55, 0.55, 0.5), "eye": Color(1.0, 0.55, 0.2),
		"stats": {"armour": 20},
	},
	"cinderling": {
		"name": "Cinderling", "life": 24, "speed": 150.0, "radius": 13.0, "xp": 11,
		"skills": ["cinder_spit"], "ai": "ranged", "range": 420.0, "keep_away": 260.0,
		"color": Color(0.65, 0.25, 0.12), "eye": Color(1.0, 0.8, 0.3),
		"stats": {"res_fire": 40},
	},
	"brute": {
		"name": "Hollow Brute", "life": 115, "speed": 105.0, "radius": 26.0, "xp": 30,
		"skills": ["brute_slam"], "ai": "melee", "range": 80.0,
		"color": Color(0.35, 0.38, 0.45), "eye": Color(0.5, 0.85, 1.0),
		"stats": {"armour": 160, "res_cold": 25},
	},
	"regent": {
		"name": "The Ashen Regent", "life": 2200, "speed": 125.0, "radius": 44.0, "xp": 400,
		"skills": ["regent_sweep", "regent_nova", "regent_volley"], "ai": "boss", "range": 140.0,
		"color": Color(0.3, 0.27, 0.25), "eye": Color(1.0, 0.75, 0.25),
		"stats": {"armour": 250, "res_fire": 30, "res_cold": 30, "res_lightning": 30},
		"boss": true,
	},
}

## Modifiers that can appear on magic/rare monsters.
const MONSTER_MODS := {
	"hasted": {"label": "Hasted", "stats": {"inc_attack_speed": 40, "inc_cast_speed": 40, "inc_move_speed": 35}},
	"bulwark": {"label": "Bulwark", "stats": {"more_life": 80, "armour": 300}},
	"emberborn": {"label": "Emberborn", "stats": {"added_fire_min": 4, "added_fire_max": 8, "res_fire": 60}},
	"rimebound": {"label": "Rimebound", "stats": {"added_cold_min": 3, "added_cold_max": 7, "chill_chance": 40, "res_cold": 60}},
	"stormtouched": {"label": "Stormtouched", "stats": {"added_lightning_min": 1, "added_lightning_max": 12, "res_lightning": 60}},
	"vampiric": {"label": "Vampiric", "stats": {"life_leech": 15}},
	"brutal": {"label": "Brutal", "stats": {"more_damage": 35}},
}
