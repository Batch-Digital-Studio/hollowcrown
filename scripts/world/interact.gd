class_name Interact
extends RefCounted
## Clicking / pressing to interact with things in the world: items and currency on the ground, chests,
## herbs, levers, the brewing kettle. Settings "Auto-loot" and "Auto-gather" (pause menu) make loot and
## herbs collect themselves when you walk close, as before.
##
## Anything in the "interactable" group can take part. It provides:
##   interact_label() -> String     what the prompt says ("Open Chest", "Gather Emberhood")
##   can_interact() -> bool         false once used up
##   interact(p: Player) -> void    do it
##   interact_kind() -> String      "loot", "gather" or "" (never automatic)
##   interact_range() -> float      px you must be within (pad focus and click use this)
##   auto_range() -> float          px for the automatic version
##
## Controller: the nearest one in range is highlighted with a prompt; A uses it (A only casts again
## when nothing is in range). Mouse: click it (the hero walks to it). Keyboard: G uses the nearest.

const PAD_FOCUS_R := 150.0
const HOVER_R := 52.0

static func candidates(g: Game) -> Array:
	var out: Array = []
	for n in g.get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(n) and n.is_visible_in_tree() and n.can_interact():
			out.append(n)
	return out

## Nearest usable thing to the hero within reach (what A / G would use).
static func nearest(g: Game, list: Array) -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for n in list:
		var d: float = (n as Node2D).global_position.distance_to(g.player.global_position)
		if d < maxf(PAD_FOCUS_R, float(n.interact_range())) and d < bd:
			bd = d
			best = n
	return best

## What the mouse is over (keyboard + mouse players).
static func hovered(g: Game, list: Array, world_mouse: Vector2) -> Node2D:
	var best: Node2D = null
	var bd := HOVER_R
	for n in list:
		var d: float = (n as Node2D).global_position.distance_to(world_mouse)
		if n.has_method("hover_offset"):
			d = minf(d, ((n as Node2D).global_position + n.hover_offset()).distance_to(world_mouse))
		if d < bd:
			bd = d
			best = n
	return best

static func use(g: Game, n: Node2D) -> void:
	if n == null or not is_instance_valid(n) or not n.can_interact():
		return
	n.interact(g.player)
	g.interact_goal = null
