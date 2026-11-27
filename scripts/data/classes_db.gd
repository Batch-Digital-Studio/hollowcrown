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
	"magus": {
		"name": "Ember Magus", "built": true, "heroes": ["wizzard_m", "wizzard_f"], "color": Color(0.49, 0.78, 1.0),
		"desc": "Elemental spellcaster. Kindling charges power Pyre Lance and the Cataclysm.",
		"resource": "kindling", "resource_name": "Kindling", "resource_max": 5,
		"special": "cataclysm", "starting_rites": ["ember_bolt", "blink"], "starter_weapon": "ember_wand",
		"base": {"ember_ward_flat": 30, "ember_ward_per_level": 4},
		"branches": [
			{"name": "Pyre", "color": Color(1.0, 0.5, 0.2), "nodes": [
				{"name": "Cinderfall", "type": "rite", "rite": "cinder_field", "stats": {}},
				{"name": "Kindling", "type": "small", "stats": {"inc_fire_damage": 15}},
				{"name": "Flame Wall", "type": "rite", "rite": "flame_wall", "stats": {}},
				{"name": "Pyre Heart", "type": "notable", "stats": {"inc_fire_damage": 15, "ignite_chance": 20}, "desc": "+15% fire damage, +20% ignite chance"},
				{"name": "Pyre Lance", "type": "rite", "rite": "pyre_lance", "stats": {}},
				{"name": "Searing", "type": "small", "stats": {"inc_ignite_damage": 25}},
				{"name": "Quickened Rites", "type": "small", "stats": {"inc_cast_speed": 10}},
				{"name": "Kindled Soul", "type": "notable", "stats": {"kindling_max_add": 2, "more_fire_damage": 10}, "desc": "+2 maximum Kindling, 10% more fire damage"},
			]},
			{"name": "Rime", "color": Color(0.55, 0.85, 1.0), "nodes": [
				{"name": "Rimeburst", "type": "rite", "rite": "frost_nova", "stats": {}},
				{"name": "Frost", "type": "small", "stats": {"inc_cold_damage": 15}},
				{"name": "Frost Lance", "type": "rite", "rite": "frost_lance", "stats": {}},
				{"name": "Deep Chill", "type": "notable", "stats": {"chill_chance": 30, "inc_cold_damage": 15}, "desc": "+30% chill chance, +15% cold damage"},
				{"name": "Glacial Prison", "type": "rite", "rite": "glacial_prison", "stats": {}},
				{"name": "Frozen Ward", "type": "small", "stats": {"ember_ward_flat": 40}},
				{"name": "Cold Snap", "type": "small", "stats": {"inc_cold_damage": 15}},
				{"name": "Winter's Embrace", "type": "notable", "stats": {"ember_ward_flat": 60, "inc_area": 15}, "desc": "+60 Ember Ward, +15% area"},
			]},
			{"name": "Storm", "color": Color(1.0, 0.92, 0.4), "nodes": [
				{"name": "Stormthread", "type": "rite", "rite": "arc_spark", "stats": {}},
				{"name": "Static", "type": "small", "stats": {"inc_lightning_damage": 15}},
				{"name": "Ball Lightning", "type": "rite", "rite": "ball_lightning", "stats": {}},
				{"name": "Forked Fate", "type": "notable", "stats": {"chain_add": 1, "inc_lightning_damage": 10}, "desc": "Chains +1, +10% lightning damage"},
				{"name": "Keen Mind", "type": "small", "stats": {"inc_crit_chance": 30}},
				{"name": "Conduction", "type": "small", "stats": {"shock_chance": 15}},
				{"name": "Ruinous", "type": "small", "stats": {"crit_multi": 20}},
				{"name": "Overcharge", "type": "notable", "stats": {"crit_multi": 30, "inc_crit_chance": 40}, "desc": "+30% crit multiplier, +40% crit chance"},
			]},
		],
	},
	"oath": {
		"name": "Oathsworn", "built": true, "heroes": ["knight_m", "knight_f"], "color": Color(1.0, 0.42, 0.17),
		"desc": "Melee, shields, fire-blessed steel. Resolve builds as you fight; spend it on Sunder and Oathbreaker.",
		"resource": "resolve", "resource_name": "Resolve", "resource_max": 100,
		"special": "oathbreaker", "starting_rites": ["cleave", "shield_rush"], "starter_weapon": "rusted_blade",
		"base": {"block_chance": 15, "armour": 40},
		"branches": [
			{"name": "Bulwark", "color": Color(0.75, 0.8, 1.0), "nodes": [
				{"name": "Bastion", "type": "rite", "rite": "bastion", "stats": {}},
				{"name": "Shield Training", "type": "small", "stats": {"block_chance": 5}},
				{"name": "Plate", "type": "small", "stats": {"armour": 80}},
				{"name": "Unbreakable", "type": "notable", "stats": {"block_chance": 8, "life_flat": 25}, "desc": "+8% block, +25 life"},
				{"name": "Iron Will", "type": "rite", "rite": "iron_will", "stats": {}},
				{"name": "Endurance", "type": "small", "stats": {"life_flat": 30}},
				{"name": "Bulwark", "type": "small", "stats": {"armour": 120}},
				{"name": "Ashen Wall", "type": "notable", "stats": {"block_chance": 10, "res_fire": 15, "res_cold": 15, "res_lightning": 15}, "desc": "+10% block, +15% elemental resistances"},
			]},
			{"name": "Crusade", "color": Color(1.0, 0.75, 0.45), "nodes": [
				{"name": "Earthsplitter", "type": "rite", "rite": "earthsplitter", "stats": {}},
				{"name": "Heavy Blows", "type": "small", "stats": {"inc_melee_damage": 15}},
				{"name": "Chain Hook", "type": "rite", "rite": "chain_hook", "stats": {}},
				{"name": "Crusader", "type": "notable", "stats": {"inc_physical_damage": 20, "inc_attack_speed": 8}, "desc": "+20% physical damage, +8% attack speed"},
				{"name": "Sunder", "type": "rite", "rite": "sunder", "stats": {}},
				{"name": "Relentless", "type": "small", "stats": {"inc_attack_speed": 8}},
				{"name": "Wide Swings", "type": "small", "stats": {"inc_area": 12}},
				{"name": "Executioner", "type": "notable", "stats": {"inc_melee_damage": 25, "crit_multi": 20}, "desc": "+25% melee damage, +20% crit multiplier"},
			]},
			{"name": "Oaths", "color": Color(1.0, 0.45, 0.2), "nodes": [
				{"name": "Oath of Embers", "type": "rite", "rite": "oath_of_embers", "stats": {}},
				{"name": "Blessed Steel", "type": "small", "stats": {"inc_fire_damage": 15}},
				{"name": "Judgment Brand", "type": "rite", "rite": "judgment_brand", "stats": {}},
				{"name": "Zeal", "type": "notable", "stats": {"resolve_gain": 50, "inc_fire_damage": 10}, "desc": "Gain 50% more Resolve, +10% fire damage"},
				{"name": "Banner of the Last King", "type": "rite", "rite": "banner_last_king", "stats": {}},
				{"name": "Kindled Steel", "type": "small", "stats": {"conv_physical_to_fire": 25}},
				{"name": "Ardent", "type": "small", "stats": {"inc_fire_damage": 15}},
				{"name": "Pyre Templar's Vow", "type": "notable", "stats": {"conv_physical_to_fire": 25, "ignite_chance": 20}, "desc": "25% more physical converted to fire, +20% ignite"},
			]},
		],
	},
	"ranger": {
		"name": "Hollow Ranger", "built": true, "heroes": ["elf_m", "elf_f"], "color": Color(0.81, 0.89, 0.48),
		"desc": "Bows, traps, speed. Focus builds while you move; at full, your next Rite is Empowered.",
		"resource": "focus", "resource_name": "Focus", "resource_max": 100,
		"special": "hunters_moon", "starting_rites": ["split_shot", "vault_shot"], "starter_weapon": "short_bow",
		"base": {"evade_chance": 12},
		"branches": [
			{"name": "Marksman", "color": Color(1.0, 0.9, 0.6), "nodes": [
				{"name": "Rain of Ash", "type": "rite", "rite": "rain_of_ash", "stats": {}},
				{"name": "Sharpshooter", "type": "small", "stats": {"inc_projectile_damage": 15}},
				{"name": "Pinning Shot", "type": "rite", "rite": "pinning_shot", "stats": {}},
				{"name": "Deadeye", "type": "notable", "stats": {"inc_crit_chance": 40, "crit_multi": 15}, "desc": "+40% crit chance, +15% crit multiplier"},
				{"name": "Explosive Bolt", "type": "rite", "rite": "explosive_bolt", "stats": {}},
				{"name": "Fletching", "type": "small", "stats": {"inc_projectile_speed": 20, "inc_projectile_damage": 10}},
				{"name": "Barbs", "type": "small", "stats": {"inc_physical_damage": 15}},
				{"name": "Quiver of Ash", "type": "notable", "stats": {"proj_count_add": 1}, "desc": "+1 projectile"},
			]},
			{"name": "Wildcraft", "color": Color(0.55, 0.9, 0.4), "nodes": [
				{"name": "Thornvine Arrow", "type": "rite", "rite": "thornvine_arrow", "stats": {}},
				{"name": "Toxins", "type": "small", "stats": {"poison_chance": 10, "inc_chaos_damage": 10}},
				{"name": "Caltrops", "type": "rite", "rite": "caltrops", "stats": {}},
				{"name": "Venomcraft", "type": "notable", "stats": {"poison_chance": 20, "inc_poison_damage": 25}, "desc": "+20% poison chance, +25% poison damage"},
				{"name": "Spirit Hawk", "type": "rite", "rite": "spirit_hawk", "stats": {}},
				{"name": "Trapper", "type": "small", "stats": {"inc_area": 10, "inc_duration": 15}},
				{"name": "Kinship", "type": "small", "stats": {"inc_minion_damage": 30}},
				{"name": "Thornwarden", "type": "notable", "stats": {"poison_chance": 15, "inc_minion_damage": 30, "inc_minion_life": 30}, "desc": "+15% poison, companions 30% stronger"},
			]},
			{"name": "Wind", "color": Color(0.7, 0.95, 0.9), "nodes": [
				{"name": "Smoke Veil", "type": "rite", "rite": "smoke_veil", "stats": {}},
				{"name": "Fleet", "type": "small", "stats": {"inc_move_speed": 6}},
				{"name": "Windrunner", "type": "rite", "rite": "windrunner", "stats": {}},
				{"name": "Elusive", "type": "notable", "stats": {"evade_chance": 12, "inc_move_speed": 6}, "desc": "+12% evasion, +6% movement"},
				{"name": "Gale", "type": "small", "stats": {"inc_attack_speed": 8}},
				{"name": "Focused Breath", "type": "small", "stats": {"focus_gain": 30}},
				{"name": "Featherstep", "type": "small", "stats": {"evade_chance": 8}},
				{"name": "Hunter's Rhythm", "type": "notable", "stats": {"inc_attack_speed": 12, "focus_gain": 40}, "desc": "+12% attack speed, 40% faster Focus"},
			]},
		],
	},
	"classic": {"name": "Kindled (classic)", "built": true, "heroes": Art.HEROES, "color": Color(1.0, 0.82, 0.45),
		"desc": "The original five Rites. Kept so current characters still work.",
		"starting_rites": ["ember_bolt", "cleave", "frost_nova", "arc_spark", "cinder_field"], "branches": []},
}

## Rite specialization trees (Rite Points come from character level, shared pool).
const SPECS := {
	"ember_bolt": [
		{"id": "twin", "name": "Twin Embers", "max": 1, "stats": {"proj_count_add": 1, "more_damage": -10}},
		{"id": "ignite", "name": "Ignition", "max": 3, "stats": {"ignite_chance": 12}},
		{"id": "overheat", "name": "Overheat", "max": 3, "stats": {"more_damage": 12}},
		{"id": "pierce", "name": "Searing Path", "max": 2, "stats": {"pierce_add": 1}},
	],
	"blink": [
		{"id": "far", "name": "Far Step", "max": 2, "skill": {"range": 100}},
		{"id": "quick", "name": "Quickstep", "max": 2, "skill": {"cooldown": -0.5}},
		{"id": "burst", "name": "Ember Burst", "max": 3, "stats": {"more_damage": 30}},
	],
	"frost_nova": [
		{"id": "wide", "name": "Wide Burst", "max": 2, "stats": {"inc_area": 20}},
		{"id": "chill", "name": "Deep Cold", "max": 3, "stats": {"more_damage": 12}},
		{"id": "cd", "name": "Rapid Frost", "max": 2, "skill": {"cooldown": -0.5}},
	],
	"arc_spark": [
		{"id": "chains", "name": "More Chains", "max": 2, "stats": {"chain_add": 1}},
		{"id": "power", "name": "High Voltage", "max": 3, "stats": {"more_damage": 12}},
		{"id": "shock", "name": "Static Grip", "max": 2, "stats": {"shock_chance": 15}},
	],
	"cinder_field": [
		{"id": "wide", "name": "Ashstorm", "max": 2, "stats": {"inc_area": 20}},
		{"id": "hot", "name": "Hot Ash", "max": 3, "stats": {"more_damage": 12}},
		{"id": "long", "name": "Smoulder", "max": 2, "stats": {"inc_duration": 25}},
	],
	"flame_wall": [
		{"id": "long", "name": "Long Wall", "max": 2, "skill": {"count": 2}},
		{"id": "hot", "name": "Inferno", "max": 3, "stats": {"more_damage": 12}},
		{"id": "ign", "name": "Kindle", "max": 2, "stats": {"ignite_chance": 15}},
	],
	"frost_lance": [
		{"id": "pierce", "name": "Spear of Winter", "max": 2, "stats": {"pierce_add": 2}},
		{"id": "power", "name": "Shatterpoint", "max": 3, "stats": {"more_damage": 12}},
		{"id": "twin", "name": "Twin Lance", "max": 1, "stats": {"proj_count_add": 1}},
	],
	"glacial_prison": [
		{"id": "long", "name": "Deep Freeze", "max": 2, "skill": {"duration": 1.0}},
		{"id": "cd", "name": "Frost Cage", "max": 2, "skill": {"cooldown": -1.0}},
	],
	"ball_lightning": [
		{"id": "fast", "name": "Rapid Zap", "max": 2, "skill": {"zap_interval": -0.05}},
		{"id": "wide", "name": "Wide Arc", "max": 2, "skill": {"zap_radius": 40}},
		{"id": "power", "name": "Overload", "max": 3, "stats": {"more_damage": 12}},
	],
	"pyre_lance": [
		{"id": "wide", "name": "Broad Lance", "max": 2, "skill": {"width": 20}},
		{"id": "power", "name": "Pyre Heart", "max": 3, "stats": {"more_damage": 15}},
		{"id": "long", "name": "Long Lance", "max": 2, "skill": {"range": 150}},
	],
	"cleave": [
		{"id": "whirl", "name": "Whirling Cleave", "max": 1, "skill": {"arc_deg": 220}, "stats": {"more_damage": -20}},
		{"id": "power", "name": "Sundering Edge", "max": 3, "stats": {"more_damage": 12}},
		{"id": "leech", "name": "Blood Arc", "max": 2, "stats": {"life_leech": 1}},
		{"id": "fire", "name": "Ember Edge", "max": 2, "stats": {"added_fire_min": 3, "added_fire_max": 6}},
	],
	"shield_rush": [
		{"id": "far", "name": "Long Charge", "max": 2, "skill": {"range": 80}},
		{"id": "stun", "name": "Concussion", "max": 2, "skill": {"root": 0.4}},
		{"id": "power", "name": "Battering Ram", "max": 3, "stats": {"more_damage": 15}},
	],
	"earthsplitter": [
		{"id": "long", "name": "Deep Fissure", "max": 2, "skill": {"count": 2}},
		{"id": "power", "name": "Tremor", "max": 3, "stats": {"more_damage": 12}},
		{"id": "wide", "name": "Wide Rift", "max": 2, "stats": {"inc_area": 20}},
	],
	"oath_of_embers": [
		{"id": "long", "name": "Enduring Oath", "max": 2, "skill": {"duration": 3.0}},
		{"id": "loud", "name": "Thunderous", "max": 2, "skill": {"radius": 100}},
	],
	"bastion": [
		{"id": "long", "name": "Hold the Line", "max": 2, "skill": {"duration": 1.5}},
		{"id": "cd", "name": "Ready Stance", "max": 2, "skill": {"cooldown": -1.5}},
	],
	"judgment_brand": [
		{"id": "power", "name": "Heavy Brand", "max": 3, "stats": {"more_damage": 12}},
		{"id": "wide", "name": "Wide Judgment", "max": 2, "stats": {"inc_area": 20}},
	],
	"chain_hook": [
		{"id": "cd", "name": "Quick Hook", "max": 2, "skill": {"cooldown": -0.5}},
		{"id": "power", "name": "Barbed", "max": 3, "stats": {"more_damage": 20}},
	],
	"banner_last_king": [
		{"id": "wide", "name": "Tall Banner", "max": 2, "stats": {"inc_area": 20}},
		{"id": "long", "name": "Standing Banner", "max": 2, "skill": {"duration": 6.0}},
	],
	"sunder": [
		{"id": "power", "name": "Crushing", "max": 3, "stats": {"more_damage": 15}},
		{"id": "wide", "name": "Wide Sunder", "max": 2, "stats": {"inc_area": 20}},
	],
	"iron_will": [
		{"id": "heal", "name": "Second Wind", "max": 2, "skill": {"heal_pct": 7}},
		{"id": "long", "name": "Iron Resolve", "max": 2, "skill": {"duration": 2.0}},
	],
	"split_shot": [
		{"id": "more", "name": "Volley", "max": 2, "skill": {"extra_proj": 1}},
		{"id": "power", "name": "Broadheads", "max": 3, "stats": {"more_damage": 12}},
		{"id": "pierce", "name": "Piercing", "max": 1, "stats": {"pierce_add": 1}},
	],
	"vault_shot": [
		{"id": "more", "name": "Triple Vault", "max": 2, "skill": {"extra_proj": 1}},
		{"id": "cd", "name": "Acrobat", "max": 2, "skill": {"cooldown": -0.5}},
	],
	"rain_of_ash": [
		{"id": "more", "name": "Storm of Arrows", "max": 2, "skill": {"count": 3}},
		{"id": "wide", "name": "Wide Rain", "max": 2, "stats": {"inc_area": 20}},
		{"id": "power", "name": "Heavy Rain", "max": 3, "stats": {"more_damage": 12}},
	],
	"pinning_shot": [
		{"id": "power", "name": "Deadly Aim", "max": 3, "stats": {"more_damage": 15}},
		{"id": "pin", "name": "Long Pin", "max": 2, "skill": {"root": 0.5}},
	],
	"thornvine_arrow": [
		{"id": "venom", "name": "Venom Barbs", "max": 3, "stats": {"poison_chance": 10}},
		{"id": "power", "name": "Thick Thorns", "max": 3, "stats": {"more_damage": 12}},
	],
	"caltrops": [
		{"id": "wide", "name": "Wide Scatter", "max": 2, "stats": {"inc_area": 20}},
		{"id": "slow", "name": "Hobbling", "max": 2, "skill": {"slow": 0.1}},
		{"id": "power", "name": "Rusted Spikes", "max": 3, "stats": {"more_damage": 15, "poison_chance": 10}},
	],
	"spirit_hawk": [
		{"id": "power", "name": "Sharp Talons", "max": 3, "stats": {"inc_minion_damage": 25}},
		{"id": "mark", "name": "Hunter's Mark", "max": 2, "stats": {"hawk_mark": 5}},
	],
	"smoke_veil": [
		{"id": "wide", "name": "Thick Smoke", "max": 2, "stats": {"inc_area": 20}},
		{"id": "long", "name": "Lingering Smoke", "max": 2, "stats": {"inc_duration": 30}},
	],
	"explosive_bolt": [
		{"id": "wide", "name": "Bigger Blast", "max": 2, "skill": {"splash": 30}},
		{"id": "power", "name": "Black Powder", "max": 3, "stats": {"more_damage": 15}},
	],
	"windrunner": [
		{"id": "long", "name": "Long Wind", "max": 2, "skill": {"duration": 2.0}},
	],
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
