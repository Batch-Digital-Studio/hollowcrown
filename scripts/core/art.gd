class_name Art
extends RefCounted
## Loads the 0x72 sprite sheet and hands out textures / SpriteFrames by name.
## Pixel art is drawn at a whole-number scale with nearest filtering.

const SHEET := "res://assets/0x72/dungeon_sheet.png"
const LIST := "res://assets/0x72/tiles_list.txt"
const PX := 4.0   # world pixels per art pixel (16px tile -> 64px cell)

static var _sheet: Texture2D
static var _rects := {}      # name -> [Rect2, frames]
static var _tex_cache := {}
static var _frames_cache := {}

static func _ensure() -> void:
	if _sheet != null:
		return
	_sheet = load(SHEET)
	var f := FileAccess.open(LIST, FileAccess.READ)
	while f and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var p := line.split(" ", false)
		if p.size() < 5:
			continue
		var frames := int(p[5]) if p.size() > 5 else 1
		_rects[p[0]] = [Rect2(int(p[1]), int(p[2]), int(p[3]), int(p[4])), frames]

static func has(name: String) -> bool:
	_ensure()
	return _rects.has(name)

static func size_of(name: String) -> Vector2:
	_ensure()
	return _rects[name][0].size

## Single frame (frame index for animated entries).
static func tex(name: String, frame: int = 0) -> Texture2D:
	_ensure()
	var key := "%s#%d" % [name, frame]
	if _tex_cache.has(key):
		return _tex_cache[key]
	if not _rects.has(name):
		push_warning("Art: missing sprite " + name)
		return null
	var r: Rect2 = _rects[name][0]
	var at := AtlasTexture.new()
	at.atlas = _sheet
	at.region = Rect2(r.position.x + r.size.x * frame, r.position.y, r.size.x, r.size.y)
	_tex_cache[key] = at
	return at

static func frame_count(name: String) -> int:
	_ensure()
	return int(_rects[name][1]) if _rects.has(name) else 0

## SpriteFrames for a character prefix, e.g. "knight_m" -> idle/run/hit animations.
static func frames_for(prefix: String) -> SpriteFrames:
	if _frames_cache.has(prefix):
		return _frames_cache[prefix]
	_ensure()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in ["idle", "run", "hit"]:
		var key := "%s_%s_anim" % [prefix, anim]
		if not _rects.has(key):
			continue
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 8.0 if anim == "idle" else 12.0)
		sf.set_animation_loop(anim, anim != "hit")
		for i in frame_count(key):
			sf.add_frame(anim, tex(key, i))
	_frames_cache[prefix] = sf
	return sf

## Animated prop (e.g. fountains, spikes) as SpriteFrames with one looping "default" anim.
static func prop_frames(name: String, fps: float = 6.0) -> SpriteFrames:
	if _frames_cache.has(name):
		return _frames_cache[name]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	for i in frame_count(name):
		sf.add_frame("default", tex(name, i))
	_frames_cache[name] = sf
	return sf

## A pixel-perfect Sprite2D for a static sprite.
static func sprite(name: String, scale: float = PX) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(name)
	s.scale = Vector2.ONE * scale
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s

const HEROES := ["knight_m", "knight_f", "wizzard_m", "wizzard_f", "elf_m", "elf_f", "lizard_m", "lizard_f"]
const HERO_NAMES := {"knight_m": "Knight", "knight_f": "Knight", "wizzard_m": "Wizard", "wizzard_f": "Wizard",
	"elf_m": "Elf", "elf_f": "Elf", "lizard_m": "Lizardfolk", "lizard_f": "Lizardfolk"}

## Weapon sprite for an item base / unique.
const WEAPON_SPRITES := {
	"rusted_blade": "weapon_rusty_sword", "tempered_blade": "weapon_knight_sword",
	"ember_wand": "weapon_red_magic_staff", "kindled_wand": "weapon_green_magic_staff",
	"war_maul": "weapon_hammer", "grave_maul": "weapon_big_hammer",
	"kindling_crown": "weapon_lavish_sword",
}
