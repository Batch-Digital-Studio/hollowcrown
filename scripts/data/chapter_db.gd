class_name ChapterDB
extends RefCounted
## Chapter 1, "The Hollow Crown": one large open map that flows forest -> swamp -> barrow hills.
## Pure data. ChapterGen turns this into a walkable grid, water, props, packs, rares and chests;
## Level3D draws it. Coordinates are map cells (1 cell = 64 px = 2 m). x east, y south.

const SEED := 4417
const W := 180               # cells (360 m)
const H := 180
const AREA_LEVEL := [2, 4, 6]   # per region

## The main route, start to boss. Smoothed into a curve; the walkable land grows around it.
const SPINE := [
	Vector2(152, 166), Vector2(146, 150), Vector2(128, 140), Vector2(110, 150), Vector2(90, 146),
	Vector2(80, 128), Vector2(84, 110), Vector2(104, 100), Vector2(124, 92), Vector2(138, 74),
	Vector2(128, 54), Vector2(104, 50), Vector2(80, 62), Vector2(58, 58), Vector2(46, 40),
	Vector2(56, 24),
]
## Where each region ends, as a fraction of the route.
const REGION_END := [0.36, 0.70, 1.0]

const REGIONS := [
	{
		"id": "whisperwood", "name": "The Whisperwood", "sub": "Old trees that remember the crown",
		"half_width": [6.0, 10.0], "ground": Color(0.34, 0.36, 0.2),
		"fog": Color(0.36, 0.3, 0.24), "sun": Color(1.0, 0.72, 0.46), "ambient": Color(0.38, 0.36, 0.36), "sun_energy": 1.6,
		"monsters": [["dusk_wolf", 5], ["briar_spider", 3], ["thornling", 2]],
		"wall": [["tree_dying_1", 4], ["tree_dying_2", 3], ["tree_dying_3", 2], ["tree_dead_1", 1]],
		"wall_low": [["bush_1", 3], ["bush_2", 3], ["tree_dead_1", 1], ["fern_1", 2]],
		"scatter": [["grass_1", 30], ["grass_2", 26], ["fern_1", 10], ["fern_2", 8], ["flowers_1", 7], ["mushroom_plain", 4], ["rock_3", 3], ["bush_1", 2]],
		"blockers": [["rock_1", 3, 0.7], ["rock_2", 2, 1.1], ["log_1", 2, 0.0], ["tree_dying_1", 2, 0.7], ["standing_stone", 1, 0.5]],
		"animals": ["deer", "crow"],
	},
	{
		"id": "mirefen", "name": "Mirefen", "sub": "Where the drowned still keep their vigil",
		"half_width": [8.0, 13.0], "ground": Color(0.26, 0.28, 0.18),
		"fog": Color(0.16, 0.2, 0.18), "sun": Color(0.62, 0.72, 0.6), "ambient": Color(0.24, 0.3, 0.3), "sun_energy": 0.85,
		"monsters": [["bog_toad", 4], ["drowned", 4], ["marsh_wisp", 2]],
		"wall": [["swamp_cypress", 5], ["swamp_snag", 2], ["tree_dead_1", 1]],
		"wall_low": [["reeds_1", 4], ["reeds_2", 3], ["bush_2", 1]],
		"scatter": [["reeds_1", 12], ["reeds_2", 10], ["grass_2", 18], ["fern_2", 6], ["mushroom_plain", 5], ["swamp_hummock", 3], ["rock_3", 2]],
		"blockers": [["swamp_snag", 3, 0.6], ["log_1", 3, 0.0], ["rock_1", 2, 0.7], ["swamp_cypress", 2, 0.8]],
		"animals": ["crow"],
	},
	{
		"id": "barrow", "name": "The Barrow Hills", "sub": "Graves of the first kings",
		"half_width": [6.0, 9.0], "ground": Color(0.3, 0.29, 0.24),
		"fog": Color(0.2, 0.2, 0.27), "sun": Color(0.62, 0.66, 0.9), "ambient": Color(0.28, 0.28, 0.36), "sun_energy": 1.05,
		"monsters": [["barrow_guard", 4], ["barrow_archer", 3], ["barrow_hexer", 2]],
		"wall": [["tree_dead_1", 3], ["dead_large", 3], ["rock_2", 2], ["tree_dying_1", 1]],
		"wall_low": [["dead_small", 3], ["rock_1", 2], ["grave_A_destroyed", 1]],
		"scatter": [["grass_1", 16], ["rock_3", 6], ["bone_A", 3], ["skull", 2], ["grave_A", 2], ["gravestone", 3], ["mushroom_plain", 2]],
		"blockers": [["gravestone", 4, 0.4], ["grave_A", 3, 0.5], ["pillar_ruin", 3, 0.55], ["rock_2", 2, 1.1], ["coffin", 1, 0.5]],
		"animals": ["crow"],
	},
]

## Open places along the route: index into SPINE, radius in cells, what is there.
const GLADES := [
	{"at": 0, "r": 11, "kind": "camp", "name": "Wayfarer's Camp"},
	{"at": 2, "r": 13, "kind": "oak", "name": "The Hollow Oak"},
	{"at": 4, "r": 10, "kind": "stones", "name": "Ring of Listening Stones"},
	{"at": 7, "r": 14, "kind": "shrine", "name": "Drowned Shrine"},
	{"at": 9, "r": 12, "kind": "lake", "name": "Stillwater"},
	{"at": 11, "r": 10, "kind": "ruins", "name": "Fallen Watchtower"},
	{"at": 13, "r": 11, "kind": "graves", "name": "Field of Cairns"},
	{"at": 15, "r": 10, "kind": "arena", "name": "Throne of the Hollow King"},
]
const WAYPOINTS := [0, 4, 9, 13]   # spine indices with a waypoint stone

## The river between the forest and the swamp: a curve in cells; crossed by a bridge on the route.
const RIVER := [Vector2(40, 150), Vector2(62, 136), Vector2(82, 120), Vector2(100, 122), Vector2(120, 116), Vector2(150, 120), Vector2(178, 112)]
const RIVER_HALF := 2.6

## Side trails: hidden caches off the main route. [spine t, side (+1 right / -1 left), length cells]
const BRANCHES := [
	[0.06, 1, 24], [0.15, -1, 26], [0.27, 1, 22], [0.33, -1, 28],
	[0.42, 1, 26], [0.5, -1, 24], [0.6, 1, 28], [0.66, -1, 22],
	[0.76, 1, 24], [0.84, -1, 26], [0.92, 1, 20],
]

const PACK_SPACING := 15.0       # cells along the route between packs
const RARE_EVERY := 4            # one pack in this many has a rare leader

## World shortcuts (cells). The way between a and b is carved but blocked in the middle until opened:
##   drawbridge: raised over the river; its lever is on the b side
##   gate:       a rusted gate; its lever is on the a side
##   log:        a dead tree standing at a; knock it down to cross the water to b
const SHORTCUTS := [
	{"kind": "drawbridge", "a": Vector2(130, 130), "b": Vector2(132, 104), "lever": "b", "name": "Old Drawbridge"},
	{"kind": "gate", "a": Vector2(104, 57), "b": Vector2(106, 77), "lever": "a", "name": "Barrow Gate"},
	{"kind": "log", "a": Vector2(117, 86), "b": Vector2(135, 82), "lever": "a", "name": "Leaning Deadwood"},
]
## The Herbalist's Kettle in the camp (cells from the camp centre).
const KETTLE_OFFSET := Vector2(-4, 2)

## Rare monster names: "<first>, the <title>" like the old ARPGs. Picked with Game.rng.
const RARE_FIRST := ["Grimfang", "Mourncaller", "Hollowmaw", "Skarrow", "Vexhide", "Ashgrin", "Duskreaver", "Bilegut",
	"Wretchwyrm", "Thornheart", "Gloomtalon", "Rotcrown", "Murkspawn", "Cinderjaw", "Wailmother", "Bonechant"]
const RARE_TITLE := ["Hungering", "Unbowed", "Gravewalker", "Whisperer", "Undying", "Ravenous", "Drowned Saint",
	"Last Warden", "Crown-Seeker", "Pale Hunter", "Hollow-Eyed", "Thousand Teeth", "Bog-Mother", "Unburied"]

## Rare abilities: each rare gets two. Active ones fire on a cooldown from RareBrain.
## aura: colour of the ground ring and light around the monster.
const RARE_ABILITIES := {
	"stormcaller": {"label": "Stormcaller", "aura": Color(0.6, 0.75, 1.0), "cd": 5.0, "desc": "calls lightning on you"},
	"frostbound": {"label": "Frostbound", "aura": Color(0.55, 0.85, 1.0), "cd": 6.5, "desc": "frost nova around itself", "stats": {"res_cold": 50}},
	"infernal": {"label": "Infernal", "aura": Color(1.0, 0.5, 0.15), "cd": 0.0, "desc": "burning aura", "stats": {"res_fire": 50}},
	"vile": {"label": "Vile", "aura": Color(0.5, 0.95, 0.3), "cd": 7.0, "desc": "leaves poison pools", "stats": {"res_chaos": 40}},
	"warcaller": {"label": "Warcaller", "aura": Color(1.0, 0.85, 0.4), "cd": 9.0, "desc": "rallies its pack"},
	"broodmother": {"label": "Broodmother", "aura": Color(0.7, 0.9, 0.55), "cd": 10.0, "desc": "calls more of its kind"},
	"blinker": {"label": "Phasing", "aura": Color(0.8, 0.55, 1.0), "cd": 5.5, "desc": "blinks next to you"},
	"volatile": {"label": "Volatile", "aura": Color(1.0, 0.65, 0.3), "cd": 0.0, "desc": "explodes on death"},
	"juggernaut": {"label": "Juggernaut", "aura": Color(0.85, 0.85, 0.8), "cd": 0.0, "desc": "cannot be slowed, huge life", "stats": {"more_life": 60, "armour": 400}},
	"soulwarded": {"label": "Soulwarded", "aura": Color(0.95, 0.95, 1.0), "cd": 12.0, "desc": "shields itself"},
}

## Region ambient sound + light colour for hidden caches.
const CACHE_LIGHT := Color(1.0, 0.82, 0.45)

static func region_of_t(t: float) -> int:
	for i in REGION_END.size():
		if t <= REGION_END[i]:
			return i
	return REGION_END.size() - 1
