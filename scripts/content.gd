extends RefCounted
## Immutable prototype balance catalog. IDs are stable save keys.
const SKILLS = [
	preload("res://content/skills/slash.tres"),
	preload("res://content/skills/ember.tres"),
	preload("res://content/skills/nova.tres"),
	preload("res://content/skills/mend.tres")
]
const ENEMIES = {
	"melee":{"title":"ASHBOUND", "hp":42.0, "speed":2.5, "damage":8.0, "range":1.6, "cooldown":1.5, "color":Color("ae554e")},
	"ranged":{"title":"CINDER WISP", "hp":30.0, "speed":1.8, "damage":7.0, "range":9.0, "cooldown":2.2, "color":Color("b98aec")},
	"brute":{"title":"HOLLOW GUARD", "hp":85.0, "speed":1.4, "damage":15.0, "range":2.0, "cooldown":2.6, "color":Color("b18b5d")},
	"boss":{"title":"THE CINDER WARDEN", "hp":420.0, "speed":1.9, "damage":16.0, "range":2.8, "cooldown":2.0, "color":Color("ee8058")}
}
const ROOMS = ["THE THRESHOLD", "ASHEN CLOISTER", "HALL OF EMBERS", "SILENT VAULT", "BROKEN SANCTUM", "CINDER GALLERY", "WARDEN'S COURT", "THE LAST PYRE"]
const ITEMS = {"weapon":"Ashsteel blade", "armor":"Warden's mail", "accessory":"Ember signet"}

static func layout(seed_value: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array = [0]
	for i in range(3):
		var choice = rng.randi_range(1, 5)
		while choice == result.back():
			choice = rng.randi_range(1, 5)
		result.append(choice)
	result.append_array([6, 7])
	return result

static func roll_item(rng: RandomNumberGenerator, level: int) -> Dictionary:
	var slot = ["weapon", "armor", "accessory"][rng.randi_range(0, 2)]
	var rarity = rng.randi_range(0, 2)
	var affixes: Dictionary = {}
	if rarity >= 1:
		affixes["health"] = rng.randi_range(3, 8) + level
	if rarity >= 2:
		affixes["power"] = rng.randi_range(1, 3) + level
	return {"id":str(Time.get_unix_time_from_system()) + "-" + str(rng.randi()), "slot":slot, "name":ITEMS[slot], "level":level, "rarity":rarity, "value":level * 2 + rarity * 3 + 2, "affixes":affixes}
