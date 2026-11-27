extends Node
## Generates many items and exercises every item code path.
func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var counts := {}
	var fails := 0
	var p := Player.new()
	p.level = 20
	p.equipment["weapon"] = Loot.starter_weapon()
	var base := p.summary(p.equipment)
	for i in 1500:
		var ilvl := rng.randi_range(1, 25)
		var it := Loot.make_item(ilvl, rng, "", rng.randf() * 200.0)
		counts[it.rarity] = counts.get(it.rarity, 0) + 1
		var mods := it.to_mods()
		var lines := it.tooltip_lines()
		if lines.is_empty() or it.name == "":
			fails += 1
			print("FAIL empty ", it.to_dict())
		for m in mods:
			if typeof(m[1]) != TYPE_FLOAT and typeof(m[1]) != TYPE_INT:
				fails += 1
				print("FAIL mod type ", m)
		# round-trip
		var back := Item.from_dict(JSON.parse_string(JSON.stringify(it.to_dict())))
		if back.tooltip_lines().size() != lines.size():
			fails += 1
			print("FAIL roundtrip ", it.name)
		if it.rarity == "magic" and it.affixes.size() > 2:
			fails += 1
		if i % 100 == 0:
			var eq: Dictionary = p.equipment.duplicate()
			eq[p.target_slot_for(it)] = it
			var s := p.summary(eq)
			if s.size() != base.size():
				fails += 1
	for uid in ItemsDB.UNIQUES:
		var u := Loot.make_unique(uid, 20, rng)
		for l in u.tooltip_lines():
			pass
		print("  unique ok: ", u.name, "  mods=", u.to_mods())
	print("rarity counts: ", counts)
	print("sample rare:")
	for i in 3:
		var r := Loot.make_item(18, rng, "rare")
		for l in r.tooltip_lines():
			print("    ", l[0])
	print("ITEM FAILURES: ", fails)
	p.free()
	get_tree().quit(1 if fails > 0 else 0)
