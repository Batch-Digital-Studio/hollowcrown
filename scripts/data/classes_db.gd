class_name ClassesDB
extends RefCounted
## Classes, class skill trees and Rite specialization trees. Pure data.
##
## Class tree node: {name, type ("rite"|"small"|"notable"), stats:{}, rite:"skill_id", desc}
## Branch nodes are taken in order (each needs the one above it).
## Rite spec node: {id, name, max (ranks), stats:{} per rank, skill:{} per rank (adds to the Rite's own fields)}

const CLASSES := {
	"shaman": {
		"name": "Bog Shaman", "built": true, "heroes": ["lizard_m", "lizard_f"],
		"color": Color(0.56, 0.86, 0.42),
		"desc": "Minions, totems, poison and curses. Lets the swamp do the work.",
		"resource": "spirit", "resource_name": "Spirit", "resource_max": 100,
		"special": "grand_rite",
		"starting_rites": ["raise_husk", "bone_spear"], "starter_weapon": "ember_wand",
		"base": {"res_chaos": 10},
		"branches": [
			{"name": "Grave", "color": Color(0.75, 0.85, 0.7), "nodes": [
				{"name": "Corpse Burst", "type": "rite", "rite": "corpse_burst", "stats": {}},
				{"name": "Grave Strength", "type": "small", "stats": {"inc_minion_damage": 15}},
				{"name": "Grave Vigour", "type": "small", "stats": {"inc_minion_life": 15}},
				{"name": "Gravecall", "type": "notable", "stats": {"minion_max_add": 1}, "desc": "+1 maximum husk"},
				{"name": "Restless Dead", "type": "small", "stats": {"minion_attack_speed": 10}},
				{"name": "Ember Bones", "type": "notable", "stats": {"minion_fire": 30}, "desc": "Minions convert 30% of their damage to fire and can ignite"},
				{"name": "Grave Fury", "type": "small", "stats": {"inc_minion_damage": 20}},
				{"name": "Legion of Ash", "type": "notable", "stats": {"minion_max_add": 1, "minion_move": 20}, "desc": "+1 maximum husk, minions move 20% faster"},
			]},
			{"name": "Rot", "color": Color(0.55, 0.9, 0.35), "nodes": [
				{"name": "Venom Spit", "type": "rite", "rite": "venom_spit", "stats": {}},
				{"name": "Festering", "type": "small", "stats": {"inc_chaos_damage": 15}},
				{"name": "Hex of Rot", "type": "rite", "rite": "hex_of_rot", "stats": {}},
				{"name": "Virulent", "type": "notable", "stats": {"poison_chance": 20, "inc_poison_damage": 20}, "desc": "+20% poison chance, +20% poison damage"},
				{"name": "Plague Cloud", "type": "rite", "rite": "plague_cloud", "stats": {}},
				{"name": "Bog-Blooded", "type": "small", "stats": {"inc_chaos_damage": 15, "res_chaos": 10}},
				{"name": "Soul Siphon", "type": "rite", "rite": "soul_siphon", "stats": {}},
				{"name": "Withering Touch", "type": "notable", "stats": {"inc_curse_effect": 50}, "desc": "Curses are 50% stronger"},
			]},
			{"name": "Totem", "color": Color(0.75, 0.7, 0.55), "nodes": [
				{"name": "Spirit Totem", "type": "rite", "rite": "spirit_totem", "stats": {}},
				{"name": "Carved Runes", "type": "small", "stats": {"inc_totem_damage": 20}},
				{"name": "Weathered Stone", "type": "small", "stats": {"inc_totem_life": 25, "inc_totem_duration": 25}},
				{"name": "Swampcall", "type": "rite", "rite": "swampcall", "stats": {}},
				{"name": "Grim Pillars", "type": "notable", "stats": {"totem_max_add": 1}, "desc": "+1 maximum totem"},
				{"name": "Ancestral Ward", "type": "rite", "rite": "ancestral_ward", "stats": {}},
				{"name": "Wide Reach", "type": "small", "stats": {"inc_area": 10}},
				{"name": "Deep Roots", "type": "notable", "stats": {"inc_totem_damage": 20, "totem_cast_speed": 20, "totem_max_add": 1}, "desc": "+1 maximum totem, totems cast 20% faster and hit 20% harder"},
			]},
		],
	},
	"magus": {"name": "Ember Magus", "built": false, "heroes": ["wizzard_m", "wizzard_f"], "color": Color(0.49, 0.78, 1.0),
		"desc": "Elemental spellcaster. Coming in stage B."},
	"oath": {"name": "Oathsworn", "built": false, "heroes": ["knight_m", "knight_f"], "color": Color(1.0, 0.42, 0.17),
		"desc": "Melee, shields, fire-blessed steel. Coming in stage B."},
	"ranger": {"name": "Hollow Ranger", "built": false, "heroes": ["elf_m", "elf_f"], "color": Color(0.81, 0.89, 0.48),
		"desc": "Bows, traps, speed. Coming in stage B."},
	"classic": {"name": "Kindled (classic)", "built": true, "heroes": Art.HEROES, "color": Color(1.0, 0.82, 0.45),
		"desc": "The original five Rites. Kept so current characters still work.",
		"starting_rites": ["ember_bolt", "cleave", "frost_nova", "arc_spark", "cinder_field"], "branches": []},
}

## Rite specialization trees (Rite Points come from character level, shared pool).
const SPECS := {
	"raise_husk": [
		{"id": "brutes", "name": "Brute Husks", "max": 1, "stats": {"husk_brute": 1}, "desc": "Husks are twice as strong, 2 fewer"},
		{"id": "frenzy", "name": "Frenzy", "max": 3, "stats": {"minion_attack_speed": 10}},
		{"id": "thick", "name": "Thick Hide", "max": 3, "stats": {"inc_minion_life": 15}},
		{"id": "ash", "name": "Ash Husks", "max": 1, "stats": {"husk_explode": 1}, "desc": "Husks explode in fire when they die"},
		{"id": "speed", "name": "Grave Speed", "max": 2, "stats": {"minion_move": 15}},
	],
	"bone_spear": [
		{"id": "impale", "name": "Impale", "max": 3, "stats": {"more_damage": 12}},
		{"id": "split", "name": "Split Spear", "max": 2, "stats": {"proj_count_add": 1, "more_damage": -8}},
		{"id": "skewer", "name": "Skewer", "max": 2, "stats": {"pierce_add": 1}},
		{"id": "marrow", "name": "Marrow Seeker", "max": 3, "stats": {"inc_crit_chance": 25}},
		{"id": "venom", "name": "Venom Tip", "max": 1, "stats": {"poison_chance": 35}},
	],
	"venom_spit": [
		{"id": "caustic", "name": "Caustic", "max": 3, "stats": {"more_damage": 12}},
		{"id": "splatter", "name": "Splatter", "max": 2, "skill": {"splash": 25}},
		{"id": "twin", "name": "Twin Spit", "max": 1, "stats": {"proj_count_add": 1}},
		{"id": "virulence", "name": "Virulence", "max": 3, "stats": {"poison_chance": 15}},
		{"id": "bile", "name": "Bile Rush", "max": 2, "stats": {"inc_cast_speed": 15}},
	],
	"hex_of_rot": [
		{"id": "deep", "name": "Deep Rot", "max": 3, "stats": {"inc_curse_effect": 20}},
		{"id": "wide", "name": "Wide Hex", "max": 2, "stats": {"inc_area": 20}},
		{"id": "long", "name": "Long Hex", "max": 2, "stats": {"inc_duration": 25}},
		{"id": "bloom", "name": "Rot Bloom", "max": 1, "stats": {"hex_spread": 1}, "desc": "Cursed enemies pass the hex on when they die"},
	],
	"plague_cloud": [
		{"id": "thick", "name": "Thick Plague", "max": 3, "stats": {"more_damage": 12}},
		{"id": "wide", "name": "Spreading Miasma", "max": 2, "stats": {"inc_area": 20}},
		{"id": "lasting", "name": "Lingering", "max": 2, "stats": {"inc_duration": 25}},
		{"id": "toxic", "name": "Toxic", "max": 2, "stats": {"poison_chance": 20}},
	],
	"spirit_totem": [
		{"id": "strength", "name": "Pillar Strength", "max": 3, "stats": {"inc_totem_damage": 12}},
		{"id": "stone", "name": "Stone Life", "max": 2, "stats": {"inc_totem_life": 25, "inc_totem_duration": 25}},
		{"id": "twin", "name": "Twin Pillars", "max": 1, "stats": {"totem_max_add": 1}},
		{"id": "quick", "name": "Quickcast", "max": 2, "stats": {"totem_cast_speed": 15}},
	],
	"soul_siphon": [
		{"id": "hunger", "name": "Hunger", "max": 3, "stats": {"more_damage": 12}},
		{"id": "drain", "name": "Deep Drain", "max": 2, "skill": {"heal": 15}},
		{"id": "reach", "name": "Reach", "max": 2, "skill": {"range": 90}},
		{"id": "chain", "name": "Forked Siphon", "max": 1, "skill": {"chains": 1}},
	],
	"swampcall": [
		{"id": "grasp", "name": "Grasping", "max": 3, "stats": {"more_damage": 12}},
		{"id": "bog", "name": "Wide Bog", "max": 2, "stats": {"inc_area": 20}},
		{"id": "root", "name": "Deep Roots", "max": 2, "skill": {"root": 0.5}},
		{"id": "twice", "name": "Second Wave", "max": 1, "skill": {"twice": 1}},
	],
	"corpse_burst": [
		{"id": "volatile", "name": "Volatile", "max": 3, "stats": {"more_damage": 12}},
		{"id": "chain", "name": "Chain Reaction", "max": 2, "skill": {"corpses": 1}},
		{"id": "wide", "name": "Wide Blast", "max": 2, "stats": {"inc_area": 20}},
	],
	"ancestral_ward": [
		{"id": "bulwark", "name": "Bulwark", "max": 3, "skill": {"reduction": 4}},
		{"id": "renew", "name": "Renewal", "max": 2, "skill": {"regen": 1}},
		{"id": "wide", "name": "Wide Ward", "max": 2, "stats": {"inc_area": 20}},
	],
}

static func class_def(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES["classic"])

## All class-tree node keys: "branch:index"
static func node(class_id: String, key: String) -> Dictionary:
	var parts := key.split(":")
	var branches: Array = class_def(class_id).get("branches", [])
	var bi := int(parts[0])
	var ni := int(parts[1])
	if bi < branches.size() and ni < branches[bi].nodes.size():
		return branches[bi].nodes[ni]
	return {}
