class_name Crafting
extends RefCounted
## Currency-on-item crafting. Pure simulation: takes an RNG, returns "" on success or a reason string.

static func can_apply(cid: String, it: Item) -> String:
	if it == null:
		return "No item"
	if it.rarity == "unique" and cid != "crown_fragment":
		return "Uniques can only take Crown Fragments"
	var ess := CurrencyDB.parse_essence(cid)
	if not ess.is_empty():
		if it.rarity != "normal" and it.rarity != "magic":
			return "Essences need a normal or magic item"
		if not ItemsDB.AFFIXES[ess[0]].slots.has(it.slot_group()):
			return "That essence can't go on this slot"
		return ""
	match cid:
		"kindling_shard":
			if it.rarity != "magic":
				return "Needs a magic item"
		"coal_ascension":
			if it.rarity != "normal":
				return "Needs a normal item"
		"ash_salt":
			if it.affixes.is_empty():
				return "No affixes to remove"
		"hollow_ember":
			if it.rarity != "rare":
				return "Needs a rare item"
			if it.affixes.size() >= 6:
				return "Already has 6 affixes"
		"crown_fragment":
			if it.affixes.is_empty() and it.unique_id == "":
				return "Nothing to reroll"
		_:
			return "Not a crafting currency"
	return ""

static func apply(cid: String, it: Item, rng: RandomNumberGenerator) -> String:
	var why := can_apply(cid, it)
	if why != "":
		return why
	var ess := CurrencyDB.parse_essence(cid)
	if not ess.is_empty():
		var d: Dictionary = ItemsDB.AFFIXES[ess[0]]
		# essence tier 1..4 = Whispering..Searing -> index into the affix's tier list (lowest first)
		var idx := clampi(int(ess[1]) - 1, 0, d.tiers.size() - 1)
		while idx > 0 and d.tiers[idx][0] > it.ilvl + 10:
			idx -= 1
		var t: Array = d.tiers[idx]
		it.rarity = "rare"
		it.affixes = [{"id": ess[0], "tier": d.tiers.size() - idx, "value": rng.randi_range(int(t[1]), int(t[2]))}]
		Loot._add_affixes(it, rng.randi_range(4, 5), rng)
		Loot._name_item(it, rng)
		return ""
	match cid:
		"kindling_shard":
			it.affixes.clear()
			Loot._add_affixes(it, rng.randi_range(1, 2), rng)
			Loot._name_item(it, rng)
		"coal_ascension":
			it.rarity = "rare"
			it.affixes.clear()
			Loot._add_affixes(it, rng.randi_range(4, 5), rng)
			Loot._name_item(it, rng)
		"ash_salt":
			it.affixes.remove_at(rng.randi() % it.affixes.size())
			if it.rarity == "magic":
				Loot._name_item(it, rng)
		"hollow_ember":
			var n := it.affixes.size()
			Loot._add_affixes(it, n + 1, rng)
			if it.affixes.size() == n:
				return "No room for that kind of affix"
		"crown_fragment":
			for a in it.affixes:
				var d: Dictionary = ItemsDB.AFFIXES[a.id]
				var t: Array = d.tiers[clampi(d.tiers.size() - int(a.tier), 0, d.tiers.size() - 1)]
				a.value = rng.randi_range(int(t[1]), int(t[2]))
			if it.unique_id != "":
				var u: Dictionary = ItemsDB.UNIQUES[it.unique_id]
				for i in u.mods.size():
					var m: Array = u.mods[i]
					if m.size() >= 3:
						it.unique_rolls[i] = rng.randi_range(int(m[1]), int(m[2]))
	return ""
