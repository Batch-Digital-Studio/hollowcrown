class_name ChapterNodes
extends RefCounted
## Things you use in the test chapter (simulation side): herbs, shortcut levers, the brewing kettle.
## All are "interactable" (see Interact): A / click / G, or automatic for herbs with Auto-gather.

## A herb patch: gather it for 1-2 herbs; it grows back after a few minutes.
class Herb extends Node2D:
	var id := ""
	var grown := true
	var _regrow := 0.0
	var _gathering := 0.0

	func _ready() -> void:
		add_to_group("interactable")

	func can_interact() -> bool:
		return grown and _gathering <= 0.0
	func interact_label() -> String:
		return "Gather " + String(BrewingDB.HERBS[id].name)
	func interact_kind() -> String:
		return "gather"
	func interact_range() -> float:
		return 100.0
	func auto_range() -> float:
		return 60.0
	func interact(p: Player) -> void:
		_gathering = BrewingDB.GATHER_TIME
		p.busy_time = maxf(p.busy_time, BrewingDB.GATHER_TIME)
		p.velocity = Vector2.ZERO
		p.act_serial += 1
		p.last_act_kind = "gather"
		FX.sound("pickup", null, -14.0, 0.0)

	func _physics_process(delta: float) -> void:
		var g := Game.instance
		if _gathering > 0.0:
			_gathering -= delta
			if _gathering <= 0.0 and g and g.player:
				var n := g.rng.randi_range(1, 2)
				g.player.add_currency(id, n)
				var h: Dictionary = BrewingDB.HERBS[id]
				FX.text(global_position, "+%d %s" % [n, h.name], h.color, 18)
				FX.burst(global_position, h.color, 12, 140.0, 6.0, 0.5)
				grown = false
				_regrow = float(h.regrow)
				FX.event3d("herb", global_position, "", 0.0, {"on": false})
				if g.chapter:
					g.chapter.hint("herb", "Herbs gathered", "%s · see it in your purse (I / View). Brew at the Herbalist's Kettle in the camp." % h.name)
		elif not grown:
			_regrow -= delta
			if _regrow <= 0.0:
				grown = true
				FX.event3d("herb", global_position, "", 0.0, {"on": true})

## A shortcut: blocked until its lever is pulled (or the dead tree is knocked down).
class ShortcutGate extends Node2D:
	var data: Dictionary
	var index := 0
	var opened := false
	var _body: StaticBody2D

	func setup(d: Dictionary, i: int) -> void:
		data = d
		index = i
		position = d.lever
		add_to_group("interactable")
		# a wall across the way at its middle
		_body = StaticBody2D.new()
		_body.collision_layer = 1
		_body.collision_mask = 0
		var dir: Vector2 = d.dir
		var side := dir.orthogonal()
		for k in 7:
			var cs := CollisionShape2D.new()
			var c := CircleShape2D.new()
			c.radius = 40.0
			cs.shape = c
			cs.position = d.mid + side * (k - 3) * 48.0
			_body.add_child(cs)

	func _ready() -> void:
		get_parent().add_child.call_deferred(_body)

	func can_interact() -> bool:
		return not opened
	func interact_label() -> String:
		match String(data.kind):
			"log":
				return "Knock down the dead tree"
			"gate":
				return "Pull the gate lever"
		return "Pull the lever"
	func interact_kind() -> String:
		return ""
	func interact_range() -> float:
		return 120.0
	func auto_range() -> float:
		return 0.0
	func interact(p: Player) -> void:
		opened = true
		if _body:
			_body.queue_free()
		p.act_serial += 1
		p.last_act_kind = "attack" if data.kind == "log" else "gather"
		FX.shake(5.0)
		FX.sound("boom", null, -6.0)
		FX.event3d("shortcut", data.mid, "", 0.0, {"index": index})
		var g := Game.instance
		if g and g.hud:
			g.hud.show_message("Shortcut opened", "%s · a quicker way back" % data.name)

## The Herbalist's Kettle in the camp: opens the brewing menu.
class Kettle extends Node2D:
	func _ready() -> void:
		add_to_group("interactable")
	func can_interact() -> bool:
		return true
	func interact_label() -> String:
		return "Brew at the Herbalist's Kettle"
	func interact_kind() -> String:
		return ""
	func interact_range() -> float:
		return 140.0
	func auto_range() -> float:
		return 0.0
	func interact(_p: Player) -> void:
		var g := Game.instance
		if g and g.hud:
			g.hud.brew_ui.open()
