class_name EnemiesDB
extends RefCounted

const ENEMIES := {
	"husk": {
		"name": "Ashen Husk", "life": 24, "speed": 165.0, "radius": 20.0, "sprite": "zombie", "px": 4.0, "xp": 9,
		"skills": ["husk_claw"], "ai": "melee", "range": 40.0,
		"color": Color(0.55, 0.55, 0.5), "eye": Color(1.0, 0.55, 0.2),
		"stats": {"armour": 20},
	},
	"cinderling": {
		"name": "Cinderling", "life": 24, "speed": 150.0, "radius": 18.0, "sprite": "imp", "px": 4.0, "light": Color(1.0, 0.5, 0.2), "xp": 11,
		"skills": ["cinder_spit"], "ai": "ranged", "range": 420.0, "keep_away": 260.0,
		"color": Color(0.65, 0.25, 0.12), "eye": Color(1.0, 0.8, 0.3),
		"stats": {"res_fire": 40},
	},
	"brute": {
		"name": "Hollow Brute", "life": 115, "speed": 105.0, "radius": 42.0, "sprite": "ogre", "px": 4.0, "xp": 30,
		"skills": ["brute_slam"], "ai": "melee", "range": 100.0,
		"color": Color(0.35, 0.38, 0.45), "eye": Color(0.5, 0.85, 1.0),
		"stats": {"armour": 160, "res_cold": 25},
	},
	"rattler": {
		"name": "Bone Rattler", "life": 16, "speed": 230.0, "radius": 18.0, "xp": 8, "sprite": "skelet", "px": 4.0,
		"skills": ["rattler_slash"], "ai": "melee", "range": 38.0,
		"color": Color(0.85, 0.85, 0.8), "eye": Color(0.9, 0.9, 1.0),
		"stats": {"res_cold": 30},
	},
	"rimecaller": {
		"name": "Rimecaller", "life": 30, "speed": 135.0, "radius": 20.0, "xp": 14, "sprite": "orc_shaman", "px": 4.0,
		"skills": ["rime_bolt"], "ai": "ranged", "range": 460.0, "keep_away": 280.0, "light": Color(0.5, 0.8, 1.0),
		"color": Color(0.3, 0.5, 0.35), "eye": Color(0.5, 0.85, 1.0),
		"stats": {"res_cold": 50},
	},
	"gravecaller": {
		"name": "Gravecaller", "life": 40, "speed": 120.0, "radius": 20.0, "xp": 22, "sprite": "necromancer", "px": 4.0,
		"skills": ["raise_dead"], "ai": "summoner", "range": 520.0, "keep_away": 340.0, "light": Color(0.6, 1.0, 0.6),
		"color": Color(0.3, 0.3, 0.35), "eye": Color(0.6, 1.0, 0.6),
		"stats": {"res_fire": 20, "res_cold": 20, "res_lightning": 20},
	},
	# --- Hollow Rift monsters (violet, fast, many) ---
	"rift_fiend": {
		"name": "Rift Fiend", "life": 20, "speed": 240.0, "radius": 18.0, "xp": 9, "sprite": "chort", "px": 4.0,
		"skills": ["rift_claw"], "ai": "melee", "range": 40.0, "rift": true,
		"color": Color(0.6, 0.4, 0.9), "eye": Color(0.8, 0.5, 1.0), "stats": {"res_chaos": 40},
	},
	"rift_maw": {
		"name": "Rift Maw", "life": 26, "speed": 150.0, "radius": 20.0, "xp": 11, "sprite": "wogol", "px": 4.0,
		"skills": ["rift_spit"], "ai": "ranged", "range": 420.0, "keep_away": 240.0, "rift": true, "light": Color(0.7, 0.45, 1.0),
		"color": Color(0.5, 0.35, 0.8), "eye": Color(0.8, 0.5, 1.0), "stats": {"res_chaos": 40},
	},
	"rift_brute": {
		"name": "Rift Colossus", "life": 120, "speed": 110.0, "radius": 40.0, "xp": 30, "sprite": "big_zombie", "px": 4.0,
		"skills": ["brute_slam"], "ai": "melee", "range": 100.0, "rift": true,
		"color": Color(0.5, 0.35, 0.8), "eye": Color(0.8, 0.5, 1.0), "stats": {"res_chaos": 40, "armour": 150},
	},
	"rift_lord": {
		"name": "The Hand That Wore the Crown", "life": 4200, "speed": 135.0, "radius": 66.0, "xp": 600, "sprite": "big_demon", "px": 6.0,
		"skills": ["rift_sweep", "rift_nova", "rift_volley"], "ai": "boss", "range": 180.0, "rift": true, "light": Color(0.7, 0.45, 1.0),
		"color": Color(0.4, 0.3, 0.6), "eye": Color(0.85, 0.55, 1.0), "enrage_text": "THE HOLLOW OPENS",
		"stats": {"armour": 250, "res_chaos": 50, "res_fire": 30, "res_cold": 30, "res_lightning": 30},
		"boss": true,
	},
	"regent": {
		"name": "The Ashen Regent", "life": 3000, "speed": 125.0, "radius": 66.0, "sprite": "big_demon", "px": 6.0, "light": Color(1.0, 0.45, 0.15), "xp": 400,
		"skills": ["regent_sweep", "regent_nova", "regent_volley"], "ai": "boss", "range": 180.0,
		"color": Color(0.3, 0.27, 0.25), "eye": Color(1.0, 0.75, 0.25),
		"stats": {"armour": 250, "res_fire": 30, "res_cold": 30, "res_lightning": 30},
		"boss": true,
	},
	# ---- rotating bosses (scripts/entities/boss_brain.gd) ----
	"rot_mother": {
		"name": "The Rot Mother", "life": 3300, "speed": 95.0, "radius": 70.0, "sprite": "big_zombie", "px": 6.5, "light": Color(0.5, 1.0, 0.3), "xp": 420,
		"skills": ["rot_slam", "rot_spray", "rot_sweep"], "ai": "brain", "brain": "rot", "range": 180.0, "tint": Color(0.75, 1.15, 0.6),
		"stats": {"armour": 200, "res_chaos": 40, "res_cold": 20}, "boss": true,
		"intro": "Her brood crawls from the bog.", "enrage_text": "THE BOG OVERFLOWS",
	},
	"frostwarden": {
		"name": "The Frostwarden", "life": 2900, "speed": 115.0, "radius": 62.0, "sprite": "ice_zombie", "px": 7.0, "light": Color(0.5, 0.85, 1.0), "xp": 420,
		"skills": ["frost_sweep", "frost_lance_b", "frost_burst"], "ai": "brain", "brain": "frost", "range": 170.0, "tint": Color(0.8, 0.95, 1.25),
		"stats": {"armour": 220, "res_cold": 60, "res_lightning": 20}, "boss": true,
		"intro": "Rings and lances: read the floor.", "enrage_text": "WINTER WITHOUT END",
	},
	"pyre_brute": {
		"name": "The Pyre Brute", "life": 3400, "speed": 120.0, "radius": 72.0, "sprite": "ogre", "px": 6.5, "light": Color(1.0, 0.5, 0.15), "xp": 420,
		"skills": ["pyre_stomp", "pyre_charge", "pyre_meteor"], "ai": "brain", "brain": "pyre", "range": 180.0, "tint": Color(1.2, 0.8, 0.65),
		"stats": {"armour": 320, "res_fire": 60}, "boss": true,
		"intro": "Bait the charge into a wall.", "enrage_text": "THE PYRE ROARS",
	},
	"grave_king": {
		"name": "The Gravecaller King", "life": 2700, "speed": 110.0, "radius": 56.0, "sprite": "necromancer", "px": 7.0, "light": Color(0.75, 0.5, 1.0), "xp": 420,
		"skills": ["grave_spears", "grave_rend", "grave_burst"], "ai": "brain", "brain": "grave", "range": 400.0, "tint": Color(0.9, 0.8, 1.2),
		"stats": {"armour": 120, "res_chaos": 40, "res_fire": 20, "res_lightning": 20}, "boss": true,
		"intro": "Kill his guard to break his shield.", "enrage_text": "THE DEAD ANSWER",
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
