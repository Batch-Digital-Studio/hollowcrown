class_name Writ
extends RefCounted
## Writ of the Hollow King: one objective per zone with a payout. Pure simulation state.

var kind := ""
var goal := 1
var progress := 0
var done := false
var failed := false
var start_pop := 0

const TEXT := {
	"rares": "Slay rare monsters",
	"clear": "Clear 80% of the zone",
	"boss_noflask": "Slay the Regent without drinking a flask",
	"reliquary": "Open every Reliquary",
	"ember": "Free and slay the Bound Ember",
	"rift": "Hold a Hollow Rift open for 45 seconds",
}

static func roll(rng: RandomNumberGenerator, has_rift: bool, n_reliq: int, has_ember: bool, pop: int) -> Writ:
	var opts: Array = ["rares", "clear", "boss_noflask"]
	if n_reliq > 0:
		opts.append("reliquary")
	if has_ember:
		opts.append("ember")
	if has_rift:
		opts.append("rift")
	var w := Writ.new()
	w.kind = opts[rng.randi() % opts.size()]
	w.start_pop = pop
	match w.kind:
		"rares": w.goal = 3
		"clear": w.goal = int(ceil(pop * 0.8))
		"reliquary": w.goal = n_reliq
		_: w.goal = 1
	return w

func text() -> String:
	var s: String = "Writ: " + TEXT[kind]
	if goal > 1:
		s += "  %d / %d" % [mini(progress, goal), goal]
	if done:
		s += "  - fulfilled"
	elif failed:
		s += "  - broken"
	return s

## Returns true the moment the writ completes.
func event(ev: String) -> bool:
	if done or failed:
		return false
	match ev:
		"rare":
			if kind == "rares": progress += 1
		"kill":
			if kind == "clear": progress += 1
		"reliquary":
			if kind == "reliquary": progress += 1
		"ember":
			if kind == "ember": progress += 1
		"rift45":
			if kind == "rift": progress += 1
		"boss":
			if kind == "boss_noflask": progress += 1
		"flask":
			if kind == "boss_noflask":
				failed = true
	if progress >= goal:
		done = true
		return true
	return false
