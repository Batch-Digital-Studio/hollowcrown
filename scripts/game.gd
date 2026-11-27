class_name Game
extends Node2D
## Orchestrates a session: zone, player, monsters, loot, saving, UI.

static var instance: Game

const SAVE_PATH := "user://hollowcrown_save.json"
const ZONE_NAMES := ["The Ashfall Road", "Rimeglass Hollow", "The Cinder Vaults", "Mirewood of Embers"]

var rng := RandomNumberGenerator.new()
var zone: Zone
var world_layer: Node2D
var fx_node: Node2D        # unlit effects layer (follows the camera)
var light_root: Node2D
var ambient: CanvasModulate
var player: Player
var enemies: Array = []
var allies: Array = []         # player-side minions and totems
var corpses: Array = []        # [{pos, level, life, node}]
var packs := {}          # enemy -> pack id
var pack_members := {}   # pack id -> Array
var camera: Camera2D
var hud: HUD
var inv_ui: InventoryUI
var depth := 1
var state := "title"     # title / play / dead
var boss: Enemy
var kills := 0
var minimap := Minimap.new()
var deaths := 0
var _save_t := 0.0

# testing hooks
var bot: Node = null
var shot_dir := ""
var _shot_times: Array = []
var _shot_i := 0
var _clock := 0.0
var quit_after := -1.0
var _inv_at := -1.0
var _tree_at := -1.0
var _class_at := -1.0
var _heart_at := -1.0
var peddler: Peddler = null
var _asc_arg := ""          # test: "<ascendancy>:<n1,n2,...>" sets trials + notables
var writ: Writ = null
var fog: EmberFog = null
var recent_kills: Array = []   # type ids killed in this zone (Blood Altars raise them)
var pad_cursor := Vector2(800, 450)   # virtual cursor for menus on a controller
var _rift_log := 0.0
var _near_boss_level := 0

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	PlayerInput.setup_input_map()
	if OS.get_cmdline_user_args().has("--fresh"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	world_layer = Node2D.new()
	world_layer.y_sort_enabled = true
	add_child(world_layer)
	light_root = Node2D.new()
	add_child(light_root)
	ambient = CanvasModulate.new()
	ambient.color = Color(0.42, 0.39, 0.46)
	add_child(ambient)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 1
	fx_layer.follow_viewport_enabled = true
	add_child(fx_layer)
	fx_node = Node2D.new()
	fx_layer.add_child(fx_node)
	var overlay := WorldOverlay.new()
	fx_layer.add_child(overlay)
	FX.world = fx_node
	FX.light_root = light_root
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.zoom = Vector2(1.0, 1.0)
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()
	FX.camera = camera
	hud = HUD.new()
	add_child(hud)
	inv_ui = hud.inventory
	_parse_args()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			bot = load("res://scripts/tests/bot.gd").new()
			add_child(bot)
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--shot-times="):
			for t in a.substr(13).split(","):
				_shot_times.append(float(t))
		elif a.begins_with("--quit-after="):
			quit_after = float(a.substr(13))
		elif a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
		elif a.begins_with("--inv-at="):
			_inv_at = float(a.substr(9))
		elif a.begins_with("--near-boss="):
			_near_boss_level = int(a.substr(12))
		elif a.begins_with("--tree-at="):
			_tree_at = float(a.substr(10))
		elif a == "--nav-probe":
			add_child(load("res://scripts/tests/nav_probe.gd").new())
		elif a == "--ttk":
			add_child(load("res://scripts/tests/ttk_bench.gd").new())
		elif a == "--asc-probe":
			add_child(load("res://scripts/tests/asc_probe.gd").new())
		elif a == "--totem-probe":
			add_child(load("res://scripts/tests/totem_probe.gd").new())
		elif a == "--pad-test":
			add_child(load("res://scripts/tests/pad_test.gd").new())
		elif a.begins_with("--class-at="):
			_class_at = float(a.substr(11))
		elif a.begins_with("--asc="):
			_asc_arg = a.substr(6)
		elif a.begins_with("--heart-at="):
			_heart_at = float(a.substr(11))
		elif a == "--fresh":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		elif a.begins_with("--depth="):
			depth = int(a.substr(8))
	if bot:
		hud.hide_overlays()
		var bot_class: String = OS.get_environment("HC_CLASS") if OS.get_environment("HC_CLASS") != "" else "classic"
		for a2 in OS.get_cmdline_user_args():
			if a2.begins_with("--class="):
				bot_class = a2.substr(8)
		var heroes: Array = ClassesDB.class_def(bot_class).heroes
		start_game(false, heroes[rng.randi() % heroes.size()], bot_class)
		if _near_boss_level > 0:
			player.level = _near_boss_level
			for i in 6:
				player.add_to_inventory(Loot.make_item(_near_boss_level, rng, "rare"))
			for i in Player.INV_SIZE:
				if player.inventory[i]:
					player.equip_from_bag(i)
			player.recalc_stats(true)
			for e in enemies.duplicate():
				if not e.is_boss():
					enemies.erase(e)
					e.queue_free()
			player.global_position = zone.cell_center(zone.boss_cell) + Vector2(-420, 0)
			if zone.is_wall_at(player.global_position):
				player.global_position = zone.cell_center(zone.boss_cell) + Vector2(0, 300)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func start_game(continue_save: bool, hero: String = "", class_id: String = "classic") -> void:
	if OS.get_environment("HC_DEBUG") != "": print("DBG start_game cont=", continue_save, " hero=", hero, " class=", class_id)
	player = Player.new()
	if hero != "":
		player.hero = hero
	player.set_class(class_id)
	if continue_save and has_save():
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			depth = int(d.get("depth", 1))
			player.from_save(d.get("player", {}))
	player.died.connect(_on_player_died)
	player.inventory_changed.connect(func(): inv_ui.refresh())
	state = "play"
	build_zone()
	hud.show_message(zone_title(), "Area Level %d" % area_level())

func zone_title() -> String:
	return "Depth %d · %s" % [depth, ZONE_NAMES[(depth - 1) % ZONE_NAMES.size()]]

func area_level() -> int:
	return 1 + (depth - 1) * 3

func build_zone() -> void:
	# Clear previous zone
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	allies.clear()
	corpses.clear()
	packs.clear()
	pack_members.clear()
	boss = null
	for c in world_layer.get_children():
		if c != player:
			c.queue_free()
	for c in fx_node.get_children():
		c.queue_free()
	for c in light_root.get_children():
		c.queue_free()
	if zone:
		zone.queue_free()
	zone = Zone.new()
	zone.z_index = -10
	add_child(zone)
	move_child(zone, 0)
	zone.generate(rng.randi(), depth)
	_build_nav()
	if player.get_parent() == null:
		world_layer.add_child(player)
	player.global_position = zone.cell_center(zone.start_cell)
	player.dead = false
	player.recalc_stats(true)
	player.flask_charges = player.flask_max
	player.ignite_time = 0.0
	player.chill_time = 0.0
	player.shock_time = 0.0
	camera.global_position = player.global_position
	camera.reset_smoothing()
	minimap.reset(zone)
	for b in zone.braziers:
		var l := FX.make_light(zone.theme_accent.lerp(Color(1, 0.8, 0.5), 0.4), rng.randf_range(300, 420), 1.25)
		l.position = b
		l.set_script(load("res://scripts/fx/flicker.gd"))
		light_root.add_child(l)
	# Ashen Peddler beside the start
	peddler = null
	var floor_set := {}
	for fc in zone.floor_cells:
		floor_set[fc] = true
	for off in [Vector2i(2, -1), Vector2i(-2, -1), Vector2i(2, 1), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		if floor_set.has(zone.start_cell + off):
			peddler = Peddler.new()
			peddler.position = zone.cell_center(zone.start_cell + off)
			fx_node.add_child(peddler)
			break
	# Hollow Rift seal in about a third of zones
	var has_rift := false
	var force_rift := OS.get_cmdline_user_args().has("--rift")
	if force_rift or rng.randf() < 0.35:
		for t in 200:
			var c2: Vector2i = zone.floor_cells[rng.randi() % zone.floor_cells.size()]
			var dmin := 6.0 if force_rift else 20.0
			if Vector2(c2 - zone.start_cell).length() > dmin and Vector2(c2 - zone.boss_cell).length() > 12.0:
				var seal := Rift.Seal.new()
				seal.position = zone.cell_center(c2)
				fx_node.add_child(seal)
				has_rift = true
				break
	for c in zone.chest_cells:
		var ch := Chest.new()
		ch.position = zone.cell_center(c)
		world_layer.add_child(ch)
	# Reliquaries (2-3) and a Bound Ember (about half of zones)
	var n_reliq := rng.randi_range(2, 3)
	var force_mech := OS.get_cmdline_user_args().has("--mechanics")
	for i in n_reliq:
		var rq := Reliquary.new()
		rq.roll(rng, depth)
		rq.position = _open_spot(8.0 if (force_mech and i == 0) else 14.0)
		world_layer.add_child(rq)
	var has_ember := force_mech or rng.randf() < 0.5
	if OS.get_cmdline_user_args().has("--trial"):
		var ts := Trial.Seal.new()
		ts.position = _open_spot(6.0)
		fx_node.add_child(ts)
	recent_kills.clear()
	fog = null
	if OS.get_cmdline_user_args().has("--altar") or rng.randf() < 0.3:
		var ba := BloodAltar.new()
		ba.position = _open_spot(7.0 if OS.get_cmdline_user_args().has("--altar") else 14.0)
		world_layer.add_child(ba)
	if OS.get_cmdline_user_args().has("--fog") or rng.randf() < 0.25:
		var fl := EmberFog.new()
		fl.position = _open_spot(5.0 if OS.get_cmdline_user_args().has("--fog") else 8.0)
		fx_node.add_child(fl)
	if has_ember:
		var be := BoundEmber.new()
		be.roll(rng, depth)
		be.position = _open_spot(10.0 if force_mech else 16.0)
		world_layer.add_child(be)
	_spawn_packs()
	_spawn_boss()
	writ = Writ.roll(rng, has_rift, n_reliq, has_ember, enemies.size())
	if OS.get_cmdline_user_args().has("--writ-rares"):
		writ = Writ.new()
		writ.kind = "rares"
		writ.goal = 3
	inv_ui.refresh()
	save_game()

## A floor point at least min_start cells from the start and away from the boss.
func _open_spot(min_start: float) -> Vector2:
	for t in 300:
		var c: Vector2i = zone.floor_cells[rng.randi() % zone.floor_cells.size()]
		if Vector2(c - zone.start_cell).length() > min_start and Vector2(c - zone.boss_cell).length() > 10.0:
			return zone.cell_center(c)
	return zone.cell_center(zone.floor_cells[rng.randi() % zone.floor_cells.size()])

## Ascension Trial seal after the Regent on depths 5/10/15/20 (if this character still owes that trial).
func _maybe_trial(pos: Vector2) -> void:
	if player == null or AscensionsDB.for_class(player.class_id).is_empty():
		return
	var idx := AscensionsDB.TRIAL_DEPTHS.find(depth)
	if idx < 0 or player.asc_trials > idx:
		return
	if is_wall(pos):
		pos = player.global_position
	var seal := Trial.Seal.new()
	seal.position = pos
	fx_node.add_child(seal)
	hud.show_message("AN ASCENSION TRIAL AWAITS", "Step onto the golden seal.")

func writ_event(ev: String) -> void:
	if writ == null or not writ.event(ev):
		return
	hud.show_message("WRIT FULFILLED", Writ.TEXT[writ.kind])
	FX.sound("levelup", null, -4.0, 0.0)
	var pos := player.global_position
	drop_currency("ember_shards", int(50 * (1.0 + depth * 0.3)), pos)
	for i in 2:
		drop_currency(CurrencyDB.CRAFTING[rng.randi() % CurrencyDB.CRAFTING.size()], 1, pos)
	if rng.randf() < (0.3 if writ.kind in ["boss_noflask", "rift", "clear"] else 0.15):
		drop_item(Loot.make_item(area_level() + 1, rng, "unique"), pos)
	else:
		drop_item(Loot.make_item(area_level() + 1, rng, "rare"), pos)

func _spawn_packs() -> void:
	var cells: Array = zone.floor_cells.duplicate()
	var chosen: Array = []
	var guard := 0
	var target := 26 + mini(depth * 2, 10)
	while chosen.size() < target and guard < 3000:
		guard += 1
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if Vector2(c - zone.start_cell).length() < 13.0 or Vector2(c - zone.boss_cell).length() < 11.0:
			continue
		var ok := true
		for o in chosen:
			if Vector2(c - o).length() < 6.0:
				ok = false
				break
		if ok:
			chosen.append(c)
	var pid := 0
	for c in chosen:
		pid += 1
		var center := zone.cell_center(c)
		var lvl := area_level() + (1 if c.x > Zone.W / 2 else 0)
		var comp: Array = []
		var r := rng.randf()
		if r < 0.26:
			for i in rng.randi_range(4, 7): comp.append("husk")
		elif r < 0.42:
			for i in rng.randi_range(5, 8): comp.append("rattler")
		elif r < 0.58:
			for i in rng.randi_range(2, 3): comp.append("cinderling")
			for i in rng.randi_range(2, 3): comp.append("husk")
		elif r < 0.70:
			for i in rng.randi_range(2, 3): comp.append("rimecaller")
			for i in rng.randi_range(2, 4): comp.append("rattler")
		elif r < 0.80:
			comp.append("gravecaller")
			for i in rng.randi_range(2, 3): comp.append("husk")
		elif r < 0.93:
			comp.append("brute")
			for i in rng.randi_range(3, 4): comp.append("husk")
		else:
			comp.append_array(["brute", "brute", "cinderling", "rimecaller"])
		var rare_ch := 0.16 + depth * 0.03
		var leader_rare := rng.randf() < rare_ch
		pack_members[pid] = []
		for i in comp.size():
			var rar := "normal"
			var mods: Array = []
			if i == 0 and leader_rare:
				rar = "rare"
				mods = _roll_mods(2 + (1 if depth >= 3 else 0))
			elif rng.randf() < 0.15:
				rar = "magic"
				mods = _roll_mods(1)
			var pos := center + Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
			if zone.is_wall_at(pos):
				pos = center
			var e := spawn_enemy(comp[i], lvl, rar, mods, pos)
			packs[e] = pid
			pack_members[pid].append(e)

func _roll_mods(n: int) -> Array:
	var keys: Array = EnemiesDB.MONSTER_MODS.keys()
	var out: Array = []
	while out.size() < n:
		var k: String = keys[rng.randi() % keys.size()]
		if not out.has(k):
			out.append(k)
	return out

func spawn_enemy(id: String, lvl: int, rar: String, mods: Array, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(id, lvl, rar, mods)
	e.global_position = pos
	e.died.connect(_on_enemy_died)
	world_layer.add_child(e)
	enemies.append(e)
	return e

func _spawn_boss() -> void:
	boss = spawn_enemy("regent", area_level() + 2, "boss", [], zone.cell_center(zone.boss_cell))
	# Scale boss with depth a little more.
	boss.max_life *= 1.0 + (depth - 1) * 0.35
	boss.life = boss.max_life

func spawn_adds(pos: Vector2, n: int, lvl: int) -> void:
	for i in n:
		var p := pos + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(90, 160)
		if zone.is_wall_at(p):
			p = pos
		var e := spawn_enemy("husk", lvl - 2, "normal", [], p)
		e.aggro = true
		FX.burst(p, Color(0.5, 0.45, 0.4), 16, 180.0, 8.0, 0.5)

func alert_pack(e: Enemy) -> void:
	var pid = packs.get(e)
	if pid == null:
		return
	for m in pack_members.get(pid, []):
		if is_instance_valid(m):
			m.aggro = true

func _on_enemy_died(a: Actor) -> void:
	var e := a as Enemy
	enemies.erase(e)
	kills += 1
	writ_event("kill")
	if not e.is_boss() and not e.has_meta("altar") and not e.has_meta("fog"):
		recent_kills.append(e.type_id)
		if recent_kills.size() > 40:
			recent_kills.pop_front()
	if e.has_meta("tribute"):
		player.add_currency("tribute", int(e.get_meta("tribute")))
	if e.has_meta("fog") and fog and is_instance_valid(fog):
		fog.on_kill(e)
	if e.rarity == "rare":
		writ_event("rare")
	if e.has_meta("essence"):
		drop_currency(e.get_meta("essence"), 1, e.global_position)
		if bot:
			print("TEST essence dropped ", e.get_meta("essence"))
		writ_event("ember")
	var mult := 1.0
	var drops := 0
	var rarity_bonus := 0.0
	match e.rarity:
		"normal":
			drops = 1 if rng.randf() < 0.16 else 0
			player.add_flask_charge(0.2)
		"magic":
			mult = 2.5
			drops = 1 if rng.randf() < 0.55 else 0
			rarity_bonus = 30.0
			player.add_flask_charge(0.5)
		"rare":
			mult = 6.0
			drops = rng.randi_range(2, 3)
			rarity_bonus = 120.0
			player.add_flask_charge(1.0)
		"boss":
			mult = 1.0
			drops = 5
			rarity_bonus = 250.0
			player.add_flask_charge(3.0)
	if e.has_meta("minion"):
		mult *= 0.25
	if e.has_meta("fog") and fog and is_instance_valid(fog):
		rarity_bonus += 60.0 + 120.0 * fog.depth01()
		if rng.randf() < 0.25 + 0.4 * fog.depth01():
			drops += 1
		drops = 0
	add_corpse(e)
	# Rifts: kills widen the rift and drop splinters
	if e.has_meta("rift") and is_instance_valid(e.get_meta("rift")):
		var rift: Rift = e.get_meta("rift")
		rift.notify_kill()
		drop_currency("rift_splinter", {"normal": rng.randi_range(1, 2), "magic": 4, "rare": 10, "boss": 60}.get(e.rarity, 1), e.global_position)
		if e.rarity == "normal":
			drops = 1 if rng.randf() < 0.08 else 0
	if e.def.get("rift", false) and e.is_boss():
		print("RIFT LORD killed at t=%.1f" % _clock)
		hud.show_message("THE HAND FALLS", "The rift spills its treasures.")
		var pool: Array = []
		for uid in ItemsDB.UNIQUES:
			if ItemsDB.UNIQUES[uid].get("rift", false):
				pool.append(uid)
		for k in 2:
			if rng.randf() < 0.6:
				drop_item(Loot.make_unique(pool[rng.randi() % pool.size()], e.level, rng), e.global_position)
		drop_currency("hollow_ember", 2, e.global_position)
		drop_currency("crown_fragment", 1, e.global_position)
	# Ember Shards from everything
	if rng.randf() < {"normal": 0.35, "magic": 0.8, "rare": 1.0, "boss": 1.0}.get(e.rarity, 0.3):
		drop_currency("ember_shards", int({"normal": 2, "magic": 5, "rare": 15, "boss": 60}.get(e.rarity, 2) * (1.0 + depth * 0.25)), e.global_position)
	if rng.randf() < {"normal": 0.03, "magic": 0.08, "rare": 0.35, "boss": 1.0}.get(e.rarity, 0.03):
		var cs: Array = CurrencyDB.CRAFTING
		drop_currency(cs[rng.randi() % cs.size()], 1, e.global_position)
	if player and not player.dead and player.max_spirit() > 0.0 and e.global_position.distance_to(player.global_position) < 800.0:
		var gain: float = {"normal": 2.0, "magic": 5.0, "rare": 12.0, "boss": 40.0}.get(e.rarity, 2.0)
		player.spirit = minf(player.max_spirit(), player.spirit + gain)
	var xp := int(round(e.def.xp * pow(1.12, e.level - 1) * mult))
	if player and not player.dead:
		player.gain_xp(xp)
	for i in drops:
		var it := Loot.make_item(e.level, rng, "", rarity_bonus)
		if e.rarity == "boss" and i == 0:
			it = Loot.make_item(e.level, rng, "rare" if rng.randf() > 0.35 else "unique")
		drop_item(it, e.global_position)
	if e.type_id == "regent":
		writ_event("boss")
		print("BOSS killed at t=%.1f" % _clock)
		hud.show_message("THE ASHEN REGENT FALLS", "A way down has opened.")
		var away := (player.global_position - e.global_position).normalized() if player else Vector2.LEFT
		_maybe_trial(player.global_position + away * 120.0 if player else e.global_position)
		var portal := Portal.new()
		set_meta("boss_pos", e.global_position)
		portal.global_position = _portal_spot(e.global_position)
		portal.entered.connect(_descend)
		fx_node.add_child(portal)
		var pl := FX.make_light(Color(0.7, 0.5, 1.0), 420.0, 1.4)
		pl.position = portal.global_position
		light_root.add_child(pl)
		save_game()

func drop_item(it: Item, pos: Vector2) -> void:
	var p := Pickup.new()
	p.setup(it, pos, Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(120, 260))
	fx_node.add_child(p)

func drop_currency(id: String, n: int, pos: Vector2) -> void:
	var c := CurrencyPickup.new()
	c.setup(id, n, pos, Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(80, 200))
	fx_node.add_child(c)

func on_rift_closed(_r: Rift) -> void:
	save_game()

func open_rift_heart() -> bool:
	if player == null or int(player.currency.get("rift_heart", 0)) <= 0:
		return false
	player.currency.rift_heart -= 1
	var r := Rift.new()
	r.lord_mode = true
	r.global_position = player.global_position
	fx_node.add_child(r)
	return true

func on_item_picked(_it: Item) -> void:
	inv_ui.refresh()

func _descend() -> void:
	depth += 1
	FX.flash(player.global_position, Color(0.7, 0.5, 1.0), 400.0, 0.5)
	build_zone()
	hud.show_message(zone_title(), "Area Level %d · monsters grow stronger" % area_level())

func _on_player_died(_a: Actor) -> void:
	state = "dead"
	FX.shake(14.0)
	FX.burst(player.global_position, Color(1.0, 0.3, 0.2), 60, 400.0, 9.0, 0.9)
	player.visible = false
	hud.show_death()

func respawn() -> void:
	player.visible = true
	state = "play"
	hud.hide_overlays()
	build_zone()
	hud.show_message(zone_title(), "The embers carry you back.")

func save_game() -> void:
	if player == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"depth": depth, "player": player.to_save()}))

# ---------- queries used by gameplay code ----------

func targets_in_circle(attacker_faction: String, pos: Vector2, r: float) -> Array:
	var out: Array = []
	if attacker_faction == "player":
		for e in enemies:
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) <= r + e.radius:
				out.append(e)
	else:
		if player and not player.dead and player.global_position.distance_to(pos) <= r + player.radius:
			out.append(player)
		for a in allies:
			if is_instance_valid(a) and not a.dead and a.global_position.distance_to(pos) <= r + a.radius:
				out.append(a)
	return out

# ---------- corpses ----------

func add_corpse(e: Enemy) -> void:
	if e.is_boss() or e.has_meta("minion"):
		return
	corpses.append({"pos": e.global_position, "level": e.level, "life": e.max_life, "node": e})
	while corpses.size() > 60:
		consume_corpse(corpses[0], false)

func corpses_near(pos: Vector2, r: float, n: int) -> Array:
	var list: Array = []
	for c in corpses:
		if c.pos.distance_to(pos) <= r:
			list.append(c)
	list.sort_custom(func(a, b): return a.pos.distance_to(pos) < b.pos.distance_to(pos))
	return list.slice(0, n)

func consume_corpse(c: Dictionary, fx: bool = true) -> void:
	corpses.erase(c)
	if is_instance_valid(c.node):
		c.node.queue_free()
	if fx:
		FX.burst(c.pos, Color(0.45, 0.4, 0.35), 12, 140.0, 7.0, 0.4)

func enemies_near(pos: Vector2, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for e in enemies:
		if e.global_position.distance_squared_to(pos) < r2:
			out.append(e)
	return out

# ---------- navigation (minions route around walls) ----------
var nav: AStarGrid2D

func _build_nav() -> void:
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, Zone.W, Zone.H)
	nav.cell_size = Vector2(Zone.CELL, Zone.CELL)
	nav.offset = Vector2(Zone.CELL * 0.5, Zone.CELL * 0.5)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for y in Zone.H:
		for x in Zone.W:
			if not zone.is_floor_cell(x, y):
				nav.set_point_solid(Vector2i(x, y), true)

## True if a body of radius r can walk straight from a to b.
func clear_walk(a: Vector2, b: Vector2, r: float) -> bool:
	var d := a.distance_to(b)
	if d < 1.0:
		return true
	var dir := (b - a) / d
	var side := dir.orthogonal() * r * 0.8
	var steps := int(d / 24.0) + 1
	for i in steps + 1:
		var p := a + dir * minf(d, i * 24.0)
		if is_wall(p) or is_wall(p + side) or is_wall(p - side):
			return false
	return true

## Grid path from a to b (cell centres), empty if none.
func nav_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	if nav == null:
		return PackedVector2Array()
	var ca := Vector2i(floor(a / Zone.CELL))
	var cb := Vector2i(floor(b / Zone.CELL))
	if not nav.region.has_point(ca) or not nav.region.has_point(cb) or nav.is_point_solid(ca) or nav.is_point_solid(cb):
		return PackedVector2Array()
	return nav.get_point_path(ca, cb)

## Portal spot: 4-5 cells from the boss's loot pile, toward the player if possible.
func _portal_spot(boss_pos: Vector2) -> Vector2:
	var away := Vector2.RIGHT
	if player:
		away = (player.global_position - boss_pos).normalized().rotated(1.2)
	for k in 16:
		var p := boss_pos + away.rotated(k * TAU / 16.0) * Zone.CELL * 4.5
		if not is_wall(p) and clear_walk(boss_pos, p, 20.0):
			return p
	return boss_pos + Vector2(0, -Zone.CELL * 3)

func is_wall(pos: Vector2) -> bool:
	return zone == null or zone.is_wall_at(pos)

func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / 24.0)
	for i in range(1, steps):
		if is_wall(a.lerp(b, float(i) / steps)):
			return false
	return true

# ---------- frame ----------

func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.04)
	var paused := get_tree().paused
	if state == "play" and player and not player.dead and not paused:
		var over_ui := (inv_ui.visible and inv_ui.mouse_over_panel()) or hud.passives.visible or hud.class_ui.visible
		if bot:
			bot.drive(player, self)
		else:
			player.input.poll_local(get_global_mouse_position(), over_ui or (PlayerInput.using_pad and inv_ui.visible), player)
		camera.global_position = player.global_position + (player.input.aim - player.global_position).limit_length(220.0) * 0.18
		minimap.update(player.global_position, delta)
		_save_t += delta
		if _save_t > 30.0:
			_save_t = 0.0
			save_game()
	if Input.is_action_just_pressed("passives") and state == "play" and (not paused or hud.passives.visible):
		hud.passives.toggle()
	if Input.is_action_just_pressed("class_screen") and state == "play" and (not paused or hud.class_ui.visible):
		hud.class_ui.toggle()
	if Input.is_action_just_pressed("inventory") and state == "play" and not paused:
		inv_ui.toggle()
	if Input.is_action_just_pressed("loadout") and state == "play" and not paused and not inv_ui.visible and player and not player.dead:
		player.swap_loadout()
	if Input.is_action_just_pressed("pause") and state == "play":
		if hud.passives.visible:
			hud.passives.toggle()
		elif hud.class_ui.visible:
			hud.class_ui.toggle()
		elif inv_ui.visible:
			inv_ui.toggle()
		else:
			hud.toggle_pause()
	_pad_menus(delta)
	if Input.is_action_just_pressed("respawn") and state == "dead":
		respawn()
	if bot and state == "dead":
		deaths += 1
		print("BOT died at t=%.0f depth=%d level=%d" % [_clock, depth, player.level])
		respawn()
	_testing_hooks()

func _input(event: InputEvent) -> void:
	PlayerInput.note_event(event)

## Controller in the inventory / passive tree: left stick drives a virtual cursor,
## A = click, X = right-click, B = close, right stick pans the tree, LB/RB zoom.
func _pad_menus(delta: float) -> void:
	var menu_open := inv_ui.visible or hud.passives.visible or hud.class_ui.visible
	if not menu_open:
		return
	if Input.is_action_just_pressed("pad_close"):
		if hud.class_ui.visible:
			hud.class_ui.toggle()
		elif hud.passives.visible:
			hud.passives.toggle()
		elif inv_ui.craft_sel != "":
			inv_ui.craft_sel = ""   # B first drops the held currency
		else:
			inv_ui.toggle()
		return
	if not PlayerInput.using_pad:
		return
	var vp := get_viewport()
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if stick.length() > 0.0:
		var speed := 1100.0 * (0.35 + 0.65 * stick.length())
		var m := pad_cursor + stick * speed * delta
		var vs := vp.get_visible_rect().size
		set_pad_cursor(Vector2(clampf(m.x, 0, vs.x), clampf(m.y, 0, vs.y)))
	if hud.passives.visible:
		var rs := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		hud.passives.offset -= rs * 700.0 * delta
		if Input.is_action_pressed("pad_zoom_in"):
			hud.passives.zoom = clampf(hud.passives.zoom * (1.0 + delta), 0.4, 1.6)
		if Input.is_action_pressed("pad_zoom_out"):
			hud.passives.zoom = clampf(hud.passives.zoom / (1.0 + delta), 0.4, 1.6)
	if Input.is_action_just_pressed("pad_click"):
		_click(MOUSE_BUTTON_LEFT)
	if Input.is_action_just_pressed("pad_alt_click"):
		_click(MOUSE_BUTTON_RIGHT)

func set_pad_cursor(p: Vector2) -> void:
	pad_cursor = p
	PlayerInput.ignore_mouse_until = Time.get_ticks_msec() + 150
	get_viewport().warp_mouse(p)

## Where menus should treat the pointer: the pad cursor on a controller, else the mouse.
static func pointer() -> Vector2:
	if PlayerInput.using_pad and instance:
		return instance.pad_cursor
	return instance.get_viewport().get_mouse_position() if instance else Vector2.ZERO

func _click(button: int) -> void:
	var pos := pad_cursor
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		e.device = PlayerInput.SYNTHETIC
		Input.parse_input_event(e)
	PlayerInput.using_pad = true   # the synthetic click shouldn't flip us back to mouse mode

func _testing_hooks() -> void:
	if OS.get_cmdline_user_args().has("--portal-test") and state == "play" and player:
		for c in fx_node.get_children():
			if c is Portal:
				if not has_meta("pt_logged"):
					set_meta("pt_logged", true)
					print("PORTAL spawned %.0f px from the boss loot pile" % c.global_position.distance_to(get_meta("boss_pos", c.global_position)))
				player.global_position = c.global_position
		if depth >= 2 and not has_meta("pt_done"):
			set_meta("pt_done", true)
			print("PORTAL descended to depth %d at t=%.1f" % [depth, _clock])
	if state == "play" and _clock > 1.0 and _clock < 1.1:
		var args := OS.get_cmdline_user_args()
		for c in world_layer.get_children():
			if c is BloodAltar and args.has("--altar-now"):
				player.global_position = c.global_position + Vector2(0, 40)
		for c in fx_node.get_children():
			if c is EmberFog and args.has("--fog-now") and not c.lit:
				c._light(self)
	if player and OS.get_cmdline_user_args().has("--god"):
		player.life = player.max_life
	if OS.get_cmdline_user_args().has("--kill-boss") and state == "play" and boss and is_instance_valid(boss) and not boss.dead and _clock > 2.0:
		boss.take_hit({"damage": {"physical": 1.0e9}, "crit": false, "ailments": {}}, player)
	if _asc_arg != "" and state == "play" and player:
		var parts := _asc_arg.split(":")
		_asc_arg = ""
		player.asc_trials = 4
		player.ascendancy = parts[0]
		player.asc_nodes = []
		if parts.size() > 1 and parts[1] != "":
			for n in parts[1].split(","):
				player.asc_nodes.append(int(n))
		player.recalc_stats(true)
		print("TEST ascendancy ", player.ascendancy, " nodes ", player.asc_nodes)
		hud.class_ui._class_tab = 99
	if _heart_at > 0.0 and _clock >= _heart_at and state == "play":
		_heart_at = -1.0
		player.add_currency("rift_splinter", 100)
		print("TEST rift heart opened: ", open_rift_heart())
	if bot and state == "play":
		_rift_log += get_process_delta_time()
		if _rift_log > 10.0:
			_rift_log = 0.0
			if writ:
				print("TEST ", writ.text())
			for c in fx_node.get_children():
				if c is Rift:
					print("TEST rift r=%.0f age=%.0f lord=%s enemies=%d splinters=%d" % [c.radius, c.age, c.lord_mode, enemies.size(), int(player.currency.get("rift_splinter", 0))])
	if _class_at > 0.0 and _clock >= _class_at and state == "play":
		_class_at = -1.0
		hud.class_ui.toggle()
		set_pad_cursor(Vector2(1000, 230))
	if _tree_at > 0.0 and _clock >= _tree_at and state == "play":
		_tree_at = -1.0
		hud.passives.toggle()
		hud.passives._summary_before = {}
	if _inv_at > 0.0 and _clock >= _inv_at and state == "play":
		_inv_at = -1.0
		if OS.get_cmdline_user_args().has("--rich"):
			for cid in ["kindling_shard", "coal_ascension", "ash_salt", "hollow_ember", "crown_fragment"]:
				player.add_currency(cid, 3)
			player.add_currency("ember_shards", 500)
			player.add_currency("ash_dust", 60)
			if peddler:
				player.global_position = peddler.global_position + Vector2(60, 30)
		inv_ui.toggle()
		set_pad_cursor(Vector2(1180, 470))
	if shot_dir != "" and _shot_i < _shot_times.size() and _clock >= _shot_times[_shot_i]:
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(shot_dir)
		img.save_png("%s/shot_%02d.png" % [shot_dir, _shot_i])
		print("SHOT ", _shot_i, " t=", _clock)
		_shot_i += 1
	if quit_after > 0.0 and _clock >= quit_after:
		print("PURSE ", player.currency)
		print("STATS deaths=%d depth=%d level=%d kills=%d life=%d/%d enemies=%d" % [deaths, depth, player.level if player else 0, kills, player.life if player else 0, player.max_life if player else 0, enemies.size()])
		get_tree().quit()
