class_name Loot
extends RefCounted
## Item generation. All randomness goes through the passed RNG (host-authoritative in co-op).

static func bases_for_level(ilvl: int) -> Array:
	var out: Array = []
	for id in ItemsDB.BASES:
		if ItemsDB.BASES[id].req <= ilvl:
			out.append(id)
	return out

## rarity_bonus: percent (rare monsters / bosses push rarity up).
static func roll_rarity(rng: RandomNumberGenerator, rarity_bonus: float) -> String:
	var r := rng.randf() * 100.0
	var unique_ch := 1.5 * (1.0 + rarity_bonus / 100.0)
	var rare_ch := 14.0 * (1.0 + rarity_bonus / 100.0)
	var magic_ch := 38.0
	if r < unique_ch:
		return "unique"
	if r < unique_ch + rare_ch:
		return "rare"
	if r < unique_ch + rare_ch + magic_ch:
		return "magic"
	return "normal"

static func make_item(ilvl: int, rng: RandomNumberGenerator, rarity: String = "", rarity_bonus: float = 0.0) -> Item:
	if rarity == "":
		rarity = roll_rarity(rng, rarity_bonus)
	if rarity == "unique":
		var pool: Array = []
		for uid in ItemsDB.UNIQUES:
			if ItemsDB.UNIQUES[uid].req <= ilvl + 2:
				pool.append(uid)
		if pool.is_empty():
			rarity = "rare"
		else:
			return make_unique(pool[rng.randi() % pool.size()], ilvl, rng)
	var it := Item.new()
	var pool := bases_for_level(ilvl)
	# Prefer bases close to the item level so better bases show up as you go deeper.
	var wsum := 0.0
	var ws: Array = []
	for id in pool:
		var w := 1.0 + 3.0 * float(ItemsDB.BASES[id].req) / float(ilvl)
		ws.append(w)
		wsum += w
	var roll := rng.randf() * wsum
	it.base_id = pool[pool.size() - 1]
	for i in pool.size():
		roll -= ws[i]
		if roll <= 0.0:
			it.base_id = pool[i]
			break
	it.ilvl = ilvl
	it.rarity = rarity
	var n_aff := 0
	match rarity:
		"magic": n_aff = rng.randi_range(1, 2)
		"rare": n_aff = rng.randi_range(3, 6) if ilvl >= 6 else rng.randi_range(3, 4)
	_add_affixes(it, n_aff, rng)
	_name_item(it, rng)
	return it

static func make_unique(uid: String, ilvl: int, rng: RandomNumberGenerator) -> Item:
	var u: Dictionary = ItemsDB.UNIQUES[uid]
	var it := Item.new()
	it.base_id = u.base
	it.ilvl = ilvl
	it.rarity = "unique"
	it.unique_id = uid
	it.name = u.name
	for m in u.mods:
		it.unique_rolls.append(rng.randi_range(int(m[1]), int(m[2])))
	return it

static func _add_affixes(it: Item, count: int, rng: RandomNumberGenerator) -> void:
	var group := it.slot_group()
	var max_p := 3 if it.rarity == "rare" else 1
	var max_s := 3 if it.rarity == "rare" else 1
	var used := {}
	var np := 0
	var ns := 0
	var tries := 0
	while it.affixes.size() < count and tries < 60:
		tries += 1
		var candidates: Array = []
		for id in ItemsDB.AFFIXES:
			var d: Dictionary = ItemsDB.AFFIXES[id]
			if used.has(id) or not d.slots.has(group):
				continue
			if d.type == "prefix" and np >= max_p:
				continue
			if d.type == "suffix" and ns >= max_s:
				continue
			if d.tiers[0][0] > it.ilvl:
				continue
			candidates.append(id)
		if candidates.is_empty():
			break
		var id: String = candidates[rng.randi() % candidates.size()]
		var d: Dictionary = ItemsDB.AFFIXES[id]
		var allowed: Array = []
		for t in d.tiers:
			if t[0] <= it.ilvl:
				allowed.append(t)
		# Weighted towards lower tiers: each tier up is 0.6x as likely.
		var weights: Array = []
		var wsum := 0.0
		for i in allowed.size():
			var w := pow(0.6, i)
			weights.append(w)
			wsum += w
		var roll := rng.randf() * wsum
		var pick := 0
		for i in allowed.size():
			roll -= weights[i]
			if roll <= 0.0:
				pick = i
				break
		var tier: Array = allowed[pick]
		var tier_num: int = d.tiers.size() - pick  # T1 = best overall tier
		it.affixes.append({"id": id, "tier": tier_num, "value": rng.randi_range(int(tier[1]), int(tier[2]))})
		used[id] = true
		if d.type == "prefix":
			np += 1
		else:
			ns += 1

static func _name_item(it: Item, rng: RandomNumberGenerator) -> void:
	var bname: String = it.base().name
	match it.rarity:
		"normal":
			it.name = bname
		"magic":
			var pre := ""
			var suf := ""
			for a in it.affixes:
				var d: Dictionary = ItemsDB.AFFIXES[a.id]
				if d.type == "prefix":
					pre = d.label + " "
				else:
					suf = " " + d.label
			it.name = pre + bname + suf
		"rare":
			var b: Array = ItemsDB.RARE_B[it.slot_group()]
			it.name = ItemsDB.RARE_A[rng.randi() % ItemsDB.RARE_A.size()] + " " + b[rng.randi() % b.size()]

static func starter_weapon(base_id: String = "rusted_blade") -> Item:
	var it := Item.new()
	it.base_id = base_id
	it.rarity = "normal"
	it.ilvl = 1
	it.name = ItemsDB.BASES[base_id].name
	return it
