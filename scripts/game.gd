class_name Game
extends Node2D
## Orchestrates a session: zone, player, monsters, loot, saving, UI.

static var instance: Game

const SAVE_PATH := "user://hollowcrown_save.json"
const ZONE_NAMES := ["The Ashfall Road", "Rimeglass Hollow", "The Cinder Vaults", "Mirewood of Embers"]

var rng := RandomNumberGenerator.new()
var zone: Zone
var world_layer: Node2D
var player: Player
var enemies: Array = []
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
var _near_boss_level := 0

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	PlayerInput.setup_input_map()
	world_layer = Node2D.new()
	world_layer.y_sort_enabled = true
	add_child(world_layer)
	FX.world = world_layer
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.zoom = Vector2(1.35, 1.35)
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
		elif a == "--fresh":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		elif a.begins_with("--depth="):
			depth = int(a.substr(8))
	if bot:
		hud.hide_overlays()
		start_game(false)
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

func start_game(continue_save: bool) -> void:
	player = Player.new()
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
	packs.clear()
	pack_members.clear()
	boss = null
	for c in world_layer.get_children():
		if c != player:
			c.queue_free()
	if zone:
		zone.queue_free()
	zone = Zone.new()
	zone.z_index = -10
	add_child(zone)
	move_child(zone, 0)
	zone.generate(rng.randi(), depth)
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
	_spawn_packs()
	_spawn_boss()
	inv_ui.refresh()
	save_game()

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
		if r < 0.42:
			for i in rng.randi_range(4, 7): comp.append("husk")
		elif r < 0.68:
			for i in rng.randi_range(2, 3): comp.append("cinderling")
			for i in rng.randi_range(2, 3): comp.append("husk")
		elif r < 0.9:
			comp.append("brute")
			for i in rng.randi_range(3, 4): comp.append("husk")
		else:
			comp.append_array(["brute", "brute", "cinderling", "cinderling"])
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
	var xp := int(round(e.def.xp * pow(1.12, e.level - 1) * mult))
	if player and not player.dead:
		player.gain_xp(xp)
	for i in drops:
		var it := Loot.make_item(e.level, rng, "", rarity_bonus)
		if e.rarity == "boss" and i == 0:
			it = Loot.make_item(e.level, rng, "rare" if rng.randf() > 0.35 else "unique")
		drop_item(it, e.global_position)
	if e.is_boss():
		print("BOSS killed at t=%.1f" % _clock)
		hud.show_message("THE ASHEN REGENT FALLS", "A way down has opened.")
		var portal := Portal.new()
		portal.global_position = e.global_position + Vector2(0, -40)
		portal.entered.connect(_descend)
		world_layer.add_child(portal)
		save_game()

func drop_item(it: Item, pos: Vector2) -> void:
	var p := Pickup.new()
	p.setup(it, pos, Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(120, 260))
	world_layer.add_child(p)

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
	return out

func enemies_near(pos: Vector2, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for e in enemies:
		if e.global_position.distance_squared_to(pos) < r2:
			out.append(e)
	return out

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
		var over_ui := (inv_ui.visible and inv_ui.mouse_over_panel()) or hud.passives.visible
		if bot:
			bot.drive(player, self)
		else:
			player.input.poll_local(get_global_mouse_position(), over_ui)
		camera.global_position = player.global_position + (player.input.aim - player.global_position).limit_length(220.0) * 0.18
		minimap.update(player.global_position, delta)
		_save_t += delta
		if _save_t > 30.0:
			_save_t = 0.0
			save_game()
	if Input.is_action_just_pressed("passives") and state == "play" and (not paused or hud.passives.visible):
		hud.passives.toggle()
	if Input.is_action_just_pressed("inventory") and state == "play" and not paused:
		inv_ui.toggle()
	if Input.is_action_just_pressed("pause") and state == "play":
		if hud.passives.visible:
			hud.passives.toggle()
		elif inv_ui.visible:
			inv_ui.toggle()
		else:
			hud.toggle_pause()
	if Input.is_action_just_pressed("respawn") and state == "dead":
		respawn()
	if bot and state == "dead":
		deaths += 1
		print("BOT died at t=%.0f depth=%d level=%d" % [_clock, depth, player.level])
		respawn()
	_testing_hooks()

func _testing_hooks() -> void:
	if _tree_at > 0.0 and _clock >= _tree_at and state == "play":
		_tree_at = -1.0
		hud.passives.toggle()
		hud.passives._summary_before = {}
	if _inv_at > 0.0 and _clock >= _inv_at and state == "play":
		_inv_at = -1.0
		inv_ui.toggle()
		Input.warp_mouse(Vector2(1180, 470))
	if shot_dir != "" and _shot_i < _shot_times.size() and _clock >= _shot_times[_shot_i]:
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(shot_dir)
		img.save_png("%s/shot_%02d.png" % [shot_dir, _shot_i])
		print("SHOT ", _shot_i, " t=", _clock)
		_shot_i += 1
	if quit_after > 0.0 and _clock >= quit_after:
		print("STATS deaths=%d depth=%d level=%d kills=%d life=%d/%d enemies=%d" % [deaths, depth, player.level if player else 0, kills, player.life if player else 0, player.max_life if player else 0, enemies.size()])
		get_tree().quit()
