extends Node
## Automated Xbox-controller test (--pad-test). Injects real joypad events and checks
## that menus, movement, skills, dodge, inventory, passive tree and pause all respond.

var t := 0.0
var step := 0
var fails := 0
var x0 := 0.0
var mana0 := 0.0
var mem_id := ""
var mem := {}
var g: Game

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	FX.enabled = false   # no hit-stop: keeps the test's clock in step with the game

func btn(b: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = pressed
	e.device = 0
	Input.parse_input_event(e)

func tap(b: int) -> void:
	btn(b, true)
	await get_tree().process_frame
	await get_tree().process_frame
	btn(b, false)

func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = 0
	Input.parse_input_event(e)

func _rect_of(kind: String, key: String, val) -> Rect2:
	for r in g.hud.class_ui._rects:
		if r.kind == kind and r.get(key) == val:
			return r.rect
	return Rect2()

func check(name: String, ok: bool) -> void:
	print(("  PASS " if ok else "  FAIL ") + name)
	if not ok:
		fails += 1

func _process(delta: float) -> void:
	t += delta / maxf(Engine.time_scale, 0.04)
	g = Game.instance
	match step:
		0:
			if t > 0.50:
				tap(JOY_BUTTON_A)   # "Begin" on the title screen
				step = 1
		1:
			if t > 1.00:
				tap(JOY_BUTTON_A)   # first class: Bog Shaman
				step = 2
		2:
			if t > 1.50:
				tap(JOY_BUTTON_A)   # first look
				step = 3
		3:
			if t > 2.20:
				check("title -> class -> look with A starts a Bog Shaman", g.state == "play" and g.player != null and g.player.class_id == "shaman")
				check("controller mode detected", PlayerInput.using_pad)
				x0 = g.player.global_position.x
				axis(JOY_AXIS_LEFT_X, 1.0)
				step = 4
		4:
			if t > 3.00:
				axis(JOY_AXIS_LEFT_X, 0.0)
				check("left stick moves the player (%.0f px)" % (g.player.global_position.x - x0), absf(g.player.global_position.x - x0) > 60.0)
				g.player.mana = g.player.max_mana
				mana0 = g.player.mana
				tap(JOY_BUTTON_A)   # slot 2 = Bone Spear
				step = 5
		5:
			if t > 3.50:
				check("A casts Bone Spear (mana %.0f -> %.0f)" % [mana0, g.player.mana], g.player.mana < mana0 - 1.0)
				g.player.mana = g.player.max_mana
				g.player.spirit = 100.0
				mana0 = g.player.mana
				axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)   # slot 1 = Raise Husk (no corpses: spends 20 Spirit)
				step = 6
		6:
			if t > 4.05:
				axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
				step = 60
		60:
			if t > 4.35:
				check("RT casts Raise Husk (%d husk)" % g.allies.size(), g.allies.size() >= 1)
				g.player.spirit = 100.0
				var n := g.allies.size()
				x0 = float(n)
				btn(JOY_BUTTON_LEFT_SHOULDER, true)
				btn(JOY_BUTTON_RIGHT_SHOULDER, true)
				step = 7
		7:
			if t > 4.80:
				btn(JOY_BUTTON_LEFT_SHOULDER, false)
				btn(JOY_BUTTON_RIGHT_SHOULDER, false)
				step = 70
		70:
			if t > 5.20:
				check("LB+RB chord fires Grand Rite (Spirit spent, horde raised: %d allies)" % g.allies.size(), g.player.spirit < 10.0 and g.allies.size() >= 3)
				mana0 = g.player.flask_charges
				g.player.life = g.player.max_life * 0.4
				tap(JOY_BUTTON_LEFT_SHOULDER)
				step = 8
		8:
			if t > 5.80:
				check("LB alone drinks the flask", g.player.flask_charges < mana0)
				g.player.life = g.player.max_life
				axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				step = 9
		9:
			if t > 5.95:
				check("LT dodges (dead=%s)" % g.player.dead, g.player.invulnerable or g.player._dodge_cd > 0.0)
				axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
				step = 10
		10:
			if t > 6.10:
				tap(JOY_BUTTON_BACK)
				step = 11
		11:
			if t > 6.50:
				check("View opens inventory", g.inv_ui.visible)
				tap(JOY_BUTTON_B)
				step = 12
		12:
			if t > 6.90:
				check("B closes inventory", not g.inv_ui.visible)
				tap(JOY_BUTTON_DPAD_UP)
				step = 13
		13:
			if t > 7.30:
				check("D-pad up opens passive tree (paused)", g.hud.passives.visible and get_tree().paused)
				tap(JOY_BUTTON_B)
				step = 14
		14:
			if t > 7.70:
				check("B closes passive tree", not g.hud.passives.visible and not get_tree().paused)
				tap(JOY_BUTTON_DPAD_DOWN)
				step = 15
		15:
			if t > 8.10:
				check("D-pad down opens class screen (paused)", g.hud.class_ui.visible and get_tree().paused)
				tap(JOY_BUTTON_B)
				step = 16
		16:
			if t > 8.50:
				check("B closes class screen", not g.hud.class_ui.visible and not get_tree().paused)
				tap(JOY_BUTTON_START)
				step = 17
		17:
			if t > 8.90:
				check("Menu opens pause", get_tree().paused)
				tap(JOY_BUTTON_START)
				step = 18
		18:
			if t > 9.30:
				check("Menu closes pause", not get_tree().paused)
				# set up: go to town, stand by the Peddler with a magic item and currency
				g.go_to_town()
				g.player.add_currency("kindling_shard", 2)
				g.player.add_currency("ember_shards", 999)
				g.player.add_currency("ash_dust", 40)
				g.player.inventory[0] = Loot.make_item(10, g.rng, "magic")
				g.player.global_position = g.peddler.global_position + Vector2(40, 20)
				tap(JOY_BUTTON_BACK)
				step = 19
		19:
			if t > 9.70:
				check("inventory beside the Peddler shows the shop", g.inv_ui.visible and g.inv_ui.shop_open())
				g.set_pad_cursor(g.inv_ui._purse_rects["kindling_shard"].get_center())
				step = 20
		20:
			if t > 9.90:
				tap(JOY_BUTTON_A)
				step = 21
		21:
			if t > 10.20:
				check("A on Kindling Shard picks it up", g.inv_ui.craft_sel == "kindling_shard")
				tap(JOY_BUTTON_B)
				step = 22
		22:
			if t > 10.50:
				check("B drops the held currency but keeps the inventory open", g.inv_ui.craft_sel == "" and g.inv_ui.visible)
				g.set_pad_cursor(g.inv_ui._purse_rects["kindling_shard"].get_center())
				step = 23
		23:
			if t > 10.70:
				tap(JOY_BUTTON_A)
				step = 24
		24:
			if t > 11.00:
				g.set_pad_cursor(g.inv_ui._bag_rect(0).get_center())
				step = 25
		25:
			if t > 11.20:
				mana0 = g.player.currency.kindling_shard
				tap(JOY_BUTTON_A)
				step = 26
		26:
			if t > 11.50:
				check("A on a magic item applies Kindling (%d -> %d)" % [int(mana0), int(g.player.currency.kindling_shard)], int(g.player.currency.kindling_shard) == int(mana0) - 1 and g.player.inventory[0] != null and g.player.inventory[0].rarity == "magic")
				check("currency stays held for repeat crafting", g.inv_ui.craft_sel == "kindling_shard")
				tap(JOY_BUTTON_B)
				g.set_pad_cursor(g.inv_ui._shop_item_rect(0).get_center())
				step = 27
		27:
			if t > 11.70:
				mana0 = g.player.currency.ember_shards
				tap(JOY_BUTTON_A)
				step = 28
		28:
			if t > 12.00:
				check("A on a shop item buys it (shards %d -> %d)" % [int(mana0), int(g.player.currency.ember_shards)], int(g.player.currency.ember_shards) < int(mana0) and g.peddler.stock[0] == null)
				tap(JOY_BUTTON_B)
				step = 29
		29:
			if t > 12.30:
				check("B closes the shop", not g.inv_ui.visible)
				g.player.asc_trials = 1
				tap(JOY_BUTTON_DPAD_DOWN)
				step = 30
		30:
			if t > 12.70:
				check("D-pad down opens class screen for ascension", g.hud.class_ui.visible)
				var r := _rect_of("tab", "idx", 1)
				if r.size.x > 0.0:
					g.set_pad_cursor(r.get_center())
				step = 31
		31:
			if t > 12.90:
				tap(JOY_BUTTON_A)
				step = 32
		32:
			if t > 13.20:
				var r2 := _rect_of("asc_choose", "asc", "gravebinder")
				check("A on the Ascension tab shows the three choices", r2.size.x > 0.0)
				if r2.size.x > 0.0:
					g.set_pad_cursor(r2.get_center())
				step = 33
		33:
			if t > 13.40:
				tap(JOY_BUTTON_A)
				step = 34
		34:
			if t > 13.70:
				check("A chooses Gravebinder", g.player.ascendancy == "gravebinder")
				var r3 := _rect_of("asc_node", "i", 0)
				if r3.size.x > 0.0:
					g.set_pad_cursor(r3.get_center())
				step = 35
		35:
			if t > 13.90:
				tap(JOY_BUTTON_A)
				step = 36
		36:
			if t > 14.20:
				check("A takes the Legion notable", g.player.asc_nodes.has(0))
				tap(JOY_BUTTON_X)
				step = 37
		37:
			if t > 14.50:
				check("X refunds it (free respec below 20)", not g.player.asc_nodes.has(0))
				tap(JOY_BUTTON_B)
				step = 38
		38:
			if t > 14.80:
				check("B closes the class screen", not g.hud.class_ui.visible)
				g.player.level = 6
				g.player.recalc_stats()
				tap(JOY_BUTTON_DPAD_UP)
				step = 39
		39:
			if t > 15.20:
				var pu: PassiveUI = g.hud.passives
				check("Shaman starts at the Shaman Star", g.player.passives.has("star_shaman") and not g.player.passives.has("start"))
				mem_id = PassivesDB.nodes()["star_shaman"].links[0]
				g.set_pad_cursor(pu._to_screen(PassivesDB.nodes()[mem_id].pos))
				mana0 = g.player.passive_points()
				step = 40
		40:
			if t > 15.40:
				tap(JOY_BUTTON_A)
				step = 41
		41:
			if t > 15.70:
				check("A allocates a node next to the star (%s, points %d -> %d)" % [mem_id, int(mana0), g.player.passive_points()], g.player.passives.has(mem_id) and g.player.passive_points() == int(mana0) - 1)
				# walk to the Grave mastery directly for the cycle check
				g.player.passives["grave_mastery"] = true
				g.player.recalc_stats()
				g.set_pad_cursor(g.hud.passives._to_screen(PassivesDB.nodes()["grave_mastery"].pos))
				step = 42
		42:
			if t > 15.90:
				tap(JOY_BUTTON_A)
				step = 43
		43:
			if t > 16.20:
				check("A on an allocated Mastery switches its effect", int(g.player.masteries.get("grave_mastery", 0)) == 1)
				tap(JOY_BUTTON_B)
				step = 44
		44:
			if t > 16.50:
				check("B closes the Constellation", not g.hud.passives.visible)
				mem_id = g.player.bar[0]
				tap(JOY_BUTTON_DPAD_LEFT)
				step = 45
		45:
			if t > 16.80:
				check("D-pad Left swaps to loadout 2 (no weapon there yet)", g.player.loadout == 1 and g.player.equipment.get("weapon") == null)
				tap(JOY_BUTTON_DPAD_RIGHT)
				step = 46
		46:
			if t > 17.10:
				check("D-pad Right swaps back (weapon and bar restored)", g.player.loadout == 0 and g.player.equipment.get("weapon") != null and g.player.bar[0] == mem_id)
				g.go_to_town()
				step = 147
		147:
			if t > 17.40:
				check("travel to town", g.in_town and g.town_npcs.size() == 3)
				# stand at the Vault, open the inventory, store a bag item
				for n in g.town_npcs:
					if n.kind == "stash":
						g.player.global_position = n.global_position + Vector2(60, 40)
				g.player.inventory[0] = Loot.make_item(5, g.rng, "rare")
				tap(JOY_BUTTON_BACK)
				step = 148
		148:
			if t > 17.70:
				check("inventory beside the Vault shows the stash", g.inv_ui.visible and g.inv_ui.npc_mode() == "stash")
				g.set_pad_cursor(g.inv_ui._bag_rect(0).get_center())
				step = 149
		149:
			if t > 17.90:
				tap(JOY_BUTTON_A)
				step = 150
		150:
			if t > 18.20:
				check("A moves a bag item into the stash", g.player.inventory[0] == null and g.stash[0] != null)
				g.set_pad_cursor(g.inv_ui._stash_rect(0).get_center())
				step = 151
		151:
			if t > 18.40:
				tap(JOY_BUTTON_A)
				step = 152
		152:
			if t > 18.70:
				check("A takes it back out", g.stash[0] == null and g.player.inventory.find(null) != 0)
				g.set_pad_cursor(g.inv_ui._filter_btn().get_center())
				step = 153
		153:
			if t > 18.90:
				tap(JOY_BUTTON_A)
				step = 154
		154:
			if t > 19.20:
				check("A on Loot Filter opens the filter panel", g.inv_ui.npc_mode() == "filter")
				for e in g.inv_ui._npc_rects:
					if e[1] == "filter" and e[2] == "normal":
						g.set_pad_cursor(e[0].get_center())
				mem["normal"] = bool(g.loot_filter.normal)
				step = 155
		155:
			if t > 19.40:
				tap(JOY_BUTTON_A)
				step = 156
		156:
			if t > 19.70:
				check("A toggles a filter rule", bool(g.loot_filter.normal) != bool(mem.normal))
				g.inv_ui.filter_open = false
				for n in g.town_npcs:
					if n.kind == "salvager":
						g.player.global_position = n.global_position + Vector2(60, 40)
				for i in 3:
					g.player.inventory[i] = Loot.make_item(5, g.rng, "magic")
				step = 157
		157:
			if t > 19.95:
				check("inventory beside the Smelter shows salvage", g.inv_ui.npc_mode() == "salvage")
				for e in g.inv_ui._npc_rects:
					if e[1] == "salvage" and e[2] == "magic":
						g.set_pad_cursor(e[0].get_center())
				step = 158
		158:
			if t > 20.15:
				tap(JOY_BUTTON_A)
				step = 159
		159:
			if t > 20.40:
				tap(JOY_BUTTON_A)
				step = 160
		160:
			if t > 20.70:
				var left := 0
				for it in g.player.inventory:
					if it and it.rarity == "magic":
						left += 1
				check("A twice melts all magic-and-below items (%d left)" % left, left == 0)
				tap(JOY_BUTTON_B)
				step = 161
		161:
			if t > 21.00:
				for n in g.town_npcs:
					if n.kind == "waypoint":
						g.player.global_position = n.global_position
				step = 162
		162:
			if t > 21.40:
				check("stepping on the Waystone opens the world map", g.hud.world_map.visible)
				var cont: Dictionary = g.hud.world_map._rects[g.hud.world_map._rects.size() - 1]
				g.set_pad_cursor(cont.rect.get_center())
				step = 163
		163:
			if t > 21.60:
				tap(JOY_BUTTON_A)
				step = 164
		164:
			if t > 22.10:
				check("A on Continue travels back to the dungeon", not g.in_town and not g.hud.world_map.visible)
				print("PAD FAILURES: ", fails)
				get_tree().quit(1 if fails > 0 else 0)
