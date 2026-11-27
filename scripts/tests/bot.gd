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
	for i in 6:
		inp.skill_held[i] = false
	var spid: String = ClassesDB.class_def(p.class_id).get("special", "")
	inp.special = false
	if spid != "":
		var ss: Dictionary = SkillsDB.SKILLS[spid]
		inp.special = p.can_pay(ss.get("res_cost", {"spirit": ss.get("spirit_cost", 100)})) and p.cooldowns.get(spid, 0.0) <= 0.0
	_spend_class_points(p)
	_dbg_t += dt
	if _dbg_t > 30.0 and p.class_id != "classic":
		_dbg_t = 0.0
		var husks := 0
		var totems := 0
		for a in g.allies:
			if a is Minion: husks += 1
			elif a is Totem: totems += 1
		print("BOT %s t=%.0f lvl=%d allies=%d/%d res=%s life=%.0f/%.0f ward=%.0f" % [p.class_id, _t, p.level, husks, totems, str(p.res), p.life, p.max_life, p.ward_pool])
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
	for c in g.fx_node.get_children():
		if c is Trial.Seal:
			target = c
			best = 0.0
		if c is Rift.Seal and c.global_position.distance_to(p.global_position) * 1.3 < best:
			target = c
			best = c.global_position.distance_to(p.global_position) * 1.3
	for c in g.world_layer.get_children():
		if (c is Reliquary and not c.opened and c._fuse <= 0.0) or c is BoundEmber:
			var dd: float = c.global_position.distance_to(p.global_position) * 1.2
			if dd < best:
				target = c
				best = dd
	if target is Reliquary and target.global_position.distance_to(p.global_position) < 60.0:
		inp.move = Vector2.ZERO   # stand still to open it
		return
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
		var melee := p.class_id == "oath" or (p.class2_id == "oath" and p.class_id == "classic")
		if melee:
			inp.move = to.normalized() if dist > 70.0 else to.normalized().orthogonal() * 0.3
		else:
			inp.move = to.normalized().orthogonal() * (1.0 if int(_t / 2.0) % 2 == 0 else -1.0)
			if dist > 260.0:
				inp.move += to.normalized() * 0.6
			elif dist < 150.0:
				inp.move -= to.normalized() * 0.6
		var phase := int(_t * 2.0) % 6
		var main := 0
		for i in p.bar.size():
			if p.bar[i] != "" and SkillsDB.SKILLS[p.bar[i]].behavior in (["melee_arc"] if p.class_id == "oath" else ["projectile", "beam"]):
				main = i
				break
		inp.skill_held[main] = true
		inp.skill_held[phase] = true
		if dist < 150.0 and p.class_id == "classic":
			inp.skill_held[1] = true
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
	# ascension: pick the first ascendancy of the class, then notables in order
	if p.asc_points() > 0:
		if p.ascendancy == "":
			var opts := AscensionsDB.for_class(p.class_id)
			if not opts.is_empty():
				p.choose_ascendancy(opts[0])
		for i in 6:
			if p.asc_points() > 0 and not p.asc_nodes.has(i):
				p.take_asc(i)
	# spend passive points (prefers the Pyre branch, then whatever is available)
	if p.passive_points() > 0:
		var tree := PassivesDB.nodes()
		var pick := ""
		for id in tree:
			if p.can_allocate(id) and tree[id].type != "keystone":
				if pick == "" or (tree[id].type == "notable" and tree[pick].type != "notable"):
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


var _node_rot := 0
var _dbg_t := 0.0

func _spend_class_points(p: Player) -> void:
	if p.level >= Player.DUAL_CLASS_LEVEL and p.class2_id == "" and p.class_id != "classic":
		for c in ["magus", "shaman", "ranger", "oath"]:
			if c != p.class_id and p.choose_second_class(c):
				print("BOT dual-class ", p.class_id, " + ", c)
				break
	var cid: String = p.classes()[_node_rot % p.classes().size()]
	var cdef := ClassesDB.class_def(cid)
	var branches: Array = cdef.get("branches", [])
	if p.class_points() > 0 and not branches.is_empty():
		for k in branches.size():
			var bi := (_node_rot + k) % branches.size()
			for ni in branches[bi].nodes.size():
				if p.can_take_node(cid, bi, ni):
					p.take_node(cid, bi, ni)
					print("BOT class node ", branches[bi].nodes[ni].name)
					_node_rot += 1
					break
			if p.class_points() <= 0:
				break
	# put every unlocked Rite on the bar
	for r in p.unlocked_rites():
		if not p.bar.has(r):
			var e := p.bar.find("")
			if e >= 0:
				p.bar[e] = r
				print("BOT bar ", r)
	if p.rite_points() > 0:
		for r in p.bar:
			if r == "":
				continue
			for sp in ClassesDB.SPECS.get(r, []):
				if p.add_spec(r, sp.id):
					print("BOT spec ", r, "/", sp.id)
					return
