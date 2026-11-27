class_name Cataclysm
extends Node2D
## Ember Magus Special: elemental meteors rain around the caster for a few seconds.

var skill: Dictionary
var user: Actor
var _t := 0.0
var _next := 0.0

func setup(s: Dictionary, u: Actor) -> void:
	skill = s
	user = u

func _process(delta: float) -> void:
	_t += delta
	if _t >= float(skill.duration) or not is_instance_valid(user) or user.dead:
		queue_free()
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = 0.18
	var g := Game.instance
	var r := float(skill.radius)
	var center := user.global_position
	# aim at an enemy half the time, anywhere nearby otherwise
	var pos := center + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf()) * r
	var near: Array = g.targets_in_circle(user.faction, center, r)
	if not near.is_empty() and randf() < 0.6:
		pos = near[randi() % near.size()].global_position
	var els := [["fire", Color(1.0, 0.5, 0.2)], ["cold", Color(0.55, 0.85, 1.0)], ["lightning", Color(1.0, 0.95, 0.5)]]
	var el: Array = els[randi() % 3]
	var s := skill.duplicate()
	s.base_damage = {el[0]: skill.base_damage.get("fire", [14, 22])}
	s.color = el[1]
	s.radius = 85.0
	s.windup = 0.35
	var e := Eruption.new()
	e.style = "meteor"
	e.setup(s, user, pos, user.cast_stats if user.cast_stats else user.stats)
	e.root = 0.0
	g.fx_node.add_child(e)
