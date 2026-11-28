class_name ModelsDB
extends RefCounted
## Which 3D model (KayKit, CC0) stands in for each class, monster and minion in the isometric view.
## Presentation only: nothing here changes the simulation.
##   model:  file in res://assets/kaykit/chars/ (without .glb)
##   show:   mesh parts to keep visible (weapons and shields are hidden unless listed)
##   weapon: optional skeleton weapon (res://assets/kaykit/weapons/Skeleton_<x>.gltf) put in the right hand
##   shield: optional skeleton shield for the left hand
##   scale:  multiplies the size picked from the monster's radius
##   tint:   colour multiplied over the model

const CHAR_DIR := "res://assets/kaykit/chars/"
const WEAPON_DIR := "res://assets/kaykit/weapons/"

const CLASSES := {
	"magus":   {"model": "Mage", "show": ["2H_Staff", "Mage_Hat", "Mage_Cape"]},
	"oath":    {"model": "Knight", "show": ["1H_Sword", "Round_Shield", "Knight_Helmet", "Knight_Cape"]},
	"ranger":  {"model": "Rogue_Hooded", "show": ["2H_Crossbow", "Rogue_Cape"]},
	"shaman":  {"model": "Barbarian", "show": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"]},
	"classic": {"model": "Knight", "show": ["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"]},
}

## Monsters by enemy id. Anything missing falls back to "default".
const ENEMIES := {
	"default":     {"model": "Skeleton_Minion"},
	"husk":        {"model": "Skeleton_Minion", "weapon": "Blade"},
	"rattler":     {"model": "Skeleton_Rogue", "weapon": "Blade", "scale": 0.9},
	"cinderling":  {"model": "Skeleton_Rogue", "tint": Color(1.0, 0.62, 0.4), "scale": 0.85},
	"brute":       {"model": "Skeleton_Warrior", "weapon": "Axe", "shield": "Shield_Small_A", "scale": 0.85},
	"rimecaller":  {"model": "Skeleton_Mage", "weapon": "Staff", "tint": Color(0.7, 0.88, 1.15)},
	"gravecaller": {"model": "Skeleton_Mage", "weapon": "Staff", "tint": Color(0.85, 0.75, 1.05)},
	"rift_fiend":  {"model": "Skeleton_Rogue", "weapon": "Blade", "tint": Color(0.85, 0.6, 1.25)},
	"rift_maw":    {"model": "Skeleton_Minion", "tint": Color(0.85, 0.6, 1.25)},
	"rift_brute":  {"model": "Skeleton_Warrior", "weapon": "Axe", "tint": Color(0.85, 0.6, 1.25), "scale": 0.85},
	"rift_lord":   {"model": "Skeleton_Warrior", "weapon": "Axe", "shield": "Shield_Small_A", "tint": Color(0.85, 0.6, 1.3)},
	"regent":      {"model": "Skeleton_Warrior", "weapon": "Axe", "shield": "Shield_Small_A", "tint": Color(1.15, 0.8, 0.6)},
	"rot_mother":  {"model": "Skeleton_Minion", "tint": Color(0.7, 1.05, 0.55)},
	"frostwarden": {"model": "Skeleton_Warrior", "weapon": "Blade", "shield": "Shield_Small_A", "tint": Color(0.65, 0.85, 1.2)},
	"pyre_brute":  {"model": "Skeleton_Warrior", "weapon": "Axe", "tint": Color(1.2, 0.7, 0.45)},
	"grave_king":  {"model": "Skeleton_Mage", "weapon": "Staff", "tint": Color(0.85, 0.7, 1.15)},
	# Chapter 1 (creatures are original Blender models in assets/chapter1; they face -Z, hence yaw)
	"dusk_wolf":     {"path": "res://assets/chapter1/wolf.glb", "yaw": PI, "scale": 1.15},
	"briar_spider":  {"path": "res://assets/chapter1/spider.glb", "yaw": PI, "scale": 0.95},
	"thornling":     {"path": "res://assets/chapter1/thornling.glb", "yaw": PI, "scale": 0.8},
	"bog_toad":      {"path": "res://assets/chapter1/toad.glb", "yaw": PI, "scale": 0.95},
	"drowned":       {"model": "Skeleton_Minion", "weapon": "Blade", "tint": Color(0.55, 0.85, 0.8)},
	"marsh_wisp":    {"wisp": true, "color": Color(0.6, 0.9, 1.0)},
	"barrow_guard":  {"model": "Skeleton_Warrior", "weapon": "Blade", "shield": "Shield_Small_A", "tint": Color(0.85, 0.9, 1.05)},
	"barrow_archer": {"model": "Skeleton_Rogue", "weapon": "Crossbow", "tint": Color(0.9, 0.92, 1.0)},
	"barrow_hexer":  {"model": "Skeleton_Mage", "weapon": "Staff", "tint": Color(0.8, 0.7, 1.1)},
	"hollow_king":   {"model": "Skeleton_Warrior", "weapon": "Axe", "tint": Color(0.7, 0.82, 1.1), "fx": "soulfire", "crown": true},
}

## Player minions by Minion.kind ("hawk" is drawn as a glowing wisp, not a model).
const MINIONS := {
	"husk":   {"model": "Skeleton_Minion", "weapon": "Blade", "tint": Color(0.75, 1.0, 0.75)},
	"squire": {"model": "Knight", "show": ["1H_Sword", "Round_Shield", "Knight_Helmet"], "tint": Color(0.8, 0.95, 1.1)},
	"beast":  {"model": "Barbarian", "show": ["1H_Axe"], "tint": Color(0.95, 0.8, 0.65)},
}

static func for_enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, ENEMIES.default)

static func for_class(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES.classic)

static func for_minion(kind: String) -> Dictionary:
	return MINIONS.get(kind, MINIONS.husk)
