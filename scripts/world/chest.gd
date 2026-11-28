class_name Chest
extends Node2D
## Treasure chest: walk up to it and it bursts open with loot.

var opened := false
var hidden_cache := false    # Chapter 1: off the path, better loot, drawn as a 3D chest
var _spr: AnimatedSprite2D
var _light: PointLight2D

func _ready() -> void:
	_spr = AnimatedSprite2D.new()
	var sf := Art.prop_frames("chest_full_open_anim", 10.0)
	sf.set_animation_loop("default", false)
	_spr.sprite_frames = sf
	_spr.scale = Vector2.ONE * Art.PX
	_spr.position = Vector2(0, -20)
	_spr.frame = 0
	add_child(_spr)

func _process(_delta: float) -> void:
	if opened:
		return
	var g := Game.instance
	if g and g.player and not g.player.dead and g.player.global_position.distance_to(global_position) < 70.0:
		open()

func open() -> void:
	opened = true
	_spr.play()
	var g := Game.instance
	FX.sound("drop_rare", null, -4.0, 0.0)
	FX.burst(global_position, Color(1.0, 0.85, 0.4), 30, 260.0, 7.0, 0.6)
	FX.flash(global_position, Color(1.0, 0.8, 0.4), 90.0, 0.35)
	FX.shake(4.0)
	var n := g.rng.randi_range(1, 3)
	var bonus := 90.0
	if hidden_cache:
		n = g.rng.randi_range(3, 4)
		bonus = 220.0
		if g.chapter:
			g.chapter.cache_opened(global_position)
	for i in n:
		var it := Loot.make_item(g.area_level() + 1, g.rng, "", bonus)
		g.drop_item(it, global_position + Vector2(0, 10))
	g.player.add_flask_charge(1.0)
