extends Node
## --slice-probe: the Whisperwood Clearing playtest (Godot side of the Unreal comparison).
var t := 0.0
var step := 0
var fails := 0
var checks := 0
var save_mtime := 0
var deer: AmbientAnimal
var deer_pos := Vector3.ZERO

func _ready() -> void:
	FX.enabled = false
	save_mtime = FileAccess.get_modified_time(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else -1

func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
	print("SLICE %s: %s" % ["ok" if c else "FAIL", what])

func _process(delta: float) -> void:
	var g := Game.instance
	if g == null or g.state != "play" or g.player == null:
		return
	t += delta
	var p := g.player
	p.invulnerable = true
	match step:
		0:
			if t > 1.0:
				ok(g.slice_mode and g.zone.is_slice, "playtest zone built from the shared layout")
				var n := 0
				for c in g.iso_view.level.get_children():
					if c is MultiMeshInstance3D:
						n += (c as MultiMeshInstance3D).multimesh.instance_count
				ok(n >= g.slice_layout.props.size(), "all %d props placed (%d instances incl. ground)" % [g.slice_layout.props.size(), n])
				var want := 0
				for pk in g.slice_layout.packs:
					want += int(pk.n)
				ok(g.enemies.size() == want, "skeleton packs spawned (%d)" % g.enemies.size())
				var animals := g.iso_view.level.find_children("*", "AmbientAnimal", true, false)
				ok(animals.size() == g.slice_layout.animals.deer.size() + g.slice_layout.animals.crow.size(), "deer and crows placed (%d)" % animals.size())
				for a in animals:
					if a.kind == "deer":
						deer = a
				# colliders: the oak and every tree/rock blocker are solid, the path is open
				var space := p.get_world_2d().direct_space_state
				var solid := 0
				for b in g.slice_layout.blockers:
					var q := PhysicsPointQueryParameters2D.new()
					q.position = Zone.slice_px(b[0], b[1])
					q.collision_mask = 1
					if not space.intersect_point(q).is_empty():
						solid += 1
				ok(solid == g.slice_layout.blockers.size(), "every tree / rock / oak collider is solid (%d/%d)" % [solid, g.slice_layout.blockers.size()])
				var qp := PhysicsPointQueryParameters2D.new()
				var pth: Array = g.slice_layout.path
				qp.position = Zone.slice_px(pth[2][0], pth[2][1])
				qp.collision_mask = 1
				ok(space.intersect_point(qp).is_empty(), "the path is walkable")
				t = 0.0
				step = 1
		1:
			if t > 0.2:
				# deer: stand next to it, it should bolt
				deer_pos = deer.position
				var dp := Vector2(deer.position.x, deer.position.z) * 32.0
				p.global_position = dp + Vector2(60, 0)
				t = 0.0
				step = 2
		2:
			if t > 1.0:
				ok(deer.position.distance_to(deer_pos) > 2.0, "deer bolts when the hero comes close (moved %.1f m)" % deer.position.distance_to(deer_pos))
				for e in g.enemies.duplicate():
					e.die(p)
				t = 0.0
				step = 3
		3:
			if t > float(g.slice_layout.get("respawn_s", 6.0)) + 1.0:
				ok(g.enemies.size() > 0, "a new wave rises after the clearing is emptied (%d)" % g.enemies.size())
				var m := FileAccess.get_modified_time(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else -1
				ok(m == save_mtime, "the playtest never writes the real save")
				print("SLICE probe: %d/%d checks passed" % [checks - fails, checks])
				get_tree().quit(1 if fails > 0 else 0)
