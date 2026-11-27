extends Node
## Run as scene: crafting rules. Checks rarity transitions and affix limits.

var fails := 0

func check(c: bool, msg: String) -> void:
	print(("  PASS " if c else "  FAIL ") + msg)
	if not c:
		fails += 1

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for n in 40:
		var it := Loot.make_item(30, rng, "normal")
		check(Crafting.apply("kindling_shard", it, rng) != "", "kindling refused on normal") if n == 0 else null
		var r := Crafting.apply("coal_ascension", it, rng)
		if n == 0:
			check(r == "" and it.rarity == "rare" and it.affixes.size() >= 4, "coal makes rare with 4+ affixes (%d)" % it.affixes.size())
		for k in 4:
			Crafting.apply("hollow_ember", it, rng)
		var np := 0
		var ns := 0
		var ids := {}
		for a in it.affixes:
			if ItemsDB.AFFIXES[a.id].type == "prefix":
				np += 1
			else:
				ns += 1
			ids[a.id] = true
		if np > 3 or ns > 3 or ids.size() != it.affixes.size():
			check(false, "affix limits broken: p%d s%d dup=%s" % [np, ns, ids.size() != it.affixes.size()])
		var before := it.affixes.size()
		Crafting.apply("ash_salt", it, rng)
		if it.affixes.size() != before - 1:
			check(false, "ash salt removes one")
		Crafting.apply("crown_fragment", it, rng)
		for a in it.affixes:
			var d: Dictionary = ItemsDB.AFFIXES[a.id]
			var t: Array = d.tiers[d.tiers.size() - int(a.tier)]
			if a.value < t[1] or a.value > t[2]:
				check(false, "crown roll out of tier range")
		var dd := Item.from_dict(it.to_dict())
		if dd.affixes.size() != it.affixes.size():
			check(false, "round-trip after crafting")
	check(true, "40 items crafted through coal/ember/salt/crown")
	var m := Loot.make_item(20, rng, "magic")
	check(Crafting.apply("kindling_shard", m, rng) == "" and m.rarity == "magic" and m.affixes.size() >= 1, "kindling rerolls magic")
	var u := Loot.make_unique(ItemsDB.UNIQUES.keys()[0], 20, rng)
	check(Crafting.apply("hollow_ember", u, rng) != "", "uniques refuse hollow ember")
	for k in CurrencyDB.ESSENCES:
		for tier in [1, 4]:
			var ok := 0
			for n in 20:
				var it := Loot.make_item(25, rng, "magic")
				var eid := CurrencyDB.essence_id(k, tier)
				var why := Crafting.apply(eid, it, rng)
				if why == "":
					var has := false
					for a in it.affixes:
						if a.id == k:
							has = true
					if it.rarity == "rare" and has:
						ok += 1
					else:
						check(false, "%s left item without its affix" % eid)
				elif not ItemsDB.AFFIXES[k].slots.has(it.slot_group()):
					ok += 1  # correctly refused
			check(ok == 20, "%s: 20/20 correct (%d)" % [CurrencyDB.info(CurrencyDB.essence_id(k, tier)).name, ok])
	print("CRAFT FAILURES: %d" % fails)
	get_tree().quit(fails)
