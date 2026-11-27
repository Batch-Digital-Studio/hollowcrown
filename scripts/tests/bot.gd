extends Node
## Test bot: plays the game for automated smoke tests and screenshots (--autoplay).

var astar: AStarGrid2D
var _zone: Zone
var _path: PackedVector2Array
var _repath := 0.0
var _t := 0.0
var _equip_t := 0.0

func _build(z: Zone) -> void:
	_zone = z
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, Zone.W, Zone.H)
	astar.cell_size = Vector2(Zone.CELL, Zone.CELL)
	astar.offset = Vector2(Zone.CELL / 2.0, Zone.CELL / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in Zone.H:
		for x in Zone.W:
			astar.set_point_solid(Vector2i(x, y), not z.is_floor_cell(x, y))

func drive(p: Player, g: Game) -> void:
	var dt := get_process_delta_time()
	_t += dt
	_repath -= dt
	_equip_t += dt
	if g.zone != _zone:
		_build(g.zone)
		_path = PackedVector2Array()
	var inp := p.input
	for i in 5:
		inp.skill_held[i] = false
	inp.dodge = false
	inp.flask = p.life < p.max_life * 0.5
	# target
	var target: Node2D = null
	var best := INF
	for e in g.enemies:
		var d: float = e.global_position.distance_to(p.global_position) * (0.5 if e.aggro else 1.0)
		if d < best:
			best = d
			target = e
	if target == null:
		for c in g.fx_node.get_children():
			if c is Portal:
				target = c
	if target == null:
		inp.move = Vector2.ZERO
		return
	var to := target.global_position - p.global_position
	var dist := to.length()
	inp.aim = target.global_position
	var los := g.has_line_of_sight(p.global_position, target.global_position)
	if target is Enemy and dist < 520.0 and los:
		# fight
		inp.move = to.normalized().orthogonal() * (1.0 if int(_t / 2.0) % 2 == 0 else -1.0)
		if dist > 260.0:
			inp.move += to.normalized() * 0.6
		elif dist < 150.0:
			inp.move -= to.normalized() * 0.6
		var phase := int(_t * 2.0) % 5
		inp.skill_held[0] = true
		if dist < 150.0:
			inp.skill_held[1] = true
			inp.skill_held[2] = true
		if phase == 2:
			inp.skill_held[3] = true
		if phase == 4:
			inp.skill_held[4] = true
		if p.life < p.max_life * 0.35 and randf() < 0.05:
			inp.dodge = true
	else:
		if _repath <= 0.0 or _path.is_empty():
			_repath = 0.5
			var a := Vector2i(p.global_position / Zone.CELL)
			var b := Vector2i(target.global_position / Zone.CELL)
			_path = astar.get_point_path(a, b)
		while _path.size() > 1 and _path[0].distance_to(p.global_position) < 40.0:
			_path.remove_at(0)
		if _path.size() > 0:
			inp.move = (_path[0] - p.global_position).normalized()
			inp.aim = p.global_position + inp.move * 200.0
		else:
			inp.move = to.normalized()
	# spend passive points (prefers the Pyre branch, then whatever is available)
	if p.passive_points() > 0:
		var tree := PassivesDB.nodes()
		var pick := ""
		for id in tree:
			if p.can_allocate(id):
				if pick == "" or id.begins_with("b0"):
					pick = id
		if pick != "":
			p.allocate(pick)
			print("BOT allocated ", tree[pick].name)
	# exercise equip code
	if _equip_t > 15.0:
		_equip_t = 0.0
		for i in Player.INV_SIZE:
			var it: Item = p.inventory[i]
			if it and it.req_level() <= p.level and it.rarity in ["rare", "unique", "magic"]:
				p.equip_from_bag(i)
				print("BOT equipped ", it.name, " (", it.rarity, ")")
				break
