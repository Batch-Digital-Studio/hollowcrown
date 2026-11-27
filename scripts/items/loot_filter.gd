class_name LootFilter
extends RefCounted
## What drops you want to see. Hidden drops are invisible and never picked up
## (turn on "Show hidden" to see and grab them anyway). Currency is never filtered.

const RARITIES := ["normal", "magic", "rare", "unique"]
const RARITY_NAMES := {"normal": "Common", "magic": "Magic", "rare": "Rare", "unique": "Unique"}
const CATEGORIES := ["weapon", "armour", "jewellery"]
const CATEGORY_NAMES := {"weapon": "Weapons", "armour": "Armour", "jewellery": "Rings & amulets"}

static func defaults() -> Dictionary:
	return {"normal": false, "magic": true, "rare": true, "unique": true,
		"weapon": true, "armour": true, "jewellery": true, "show_hidden": false}

static func category(it: Item) -> String:
	var sg := it.slot_group()
	if sg == "weapon":
		return "weapon"
	if sg == "ring" or sg == "amulet":
		return "jewellery"
	return "armour"

static func allows(f: Dictionary, it: Item) -> bool:
	if it.rarity == "unique" and bool(f.get("unique", true)):
		return true   # uniques ignore the category toggles
	return bool(f.get(it.rarity, true)) and bool(f.get(category(it), true))
