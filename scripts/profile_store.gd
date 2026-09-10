extends RefCounted
const Content = preload("res://scripts/content.gd")
var path: String
var warning = ""

func _init(save_path: String = "user://profile.json") -> void:
	path = save_path

func fresh() -> Dictionary:
	return {"version":1, "content_version":1, "level":1, "xp":0, "gold":0, "inventory":[], "equipment":{}, "skills":["slash", "ember", "nova", "mend"], "settings":{"fps":60, "sound":true}, "wins":0}

func load_profile() -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var envelope = parser.data
		if not envelope is Dictionary or not envelope.get("payload") is String:
			continue
		if envelope.get("sha256", "") != envelope.payload.sha256_text():
			continue
		if parser.parse(envelope.payload) != OK:
			continue
		var data = parser.data
		if not data is Dictionary or int(data.get("version", 0)) != 1:
			continue
		if candidate.ends_with(".bak"):
			warning = "Recovered your character from the backup save."
		return repair(data)
	if FileAccess.file_exists(path):
		warning = "Save could not be read. A new character was created."
	return fresh()

func repair(data: Dictionary) -> Dictionary:
	var clean = fresh()
	for key in ["level", "xp", "gold", "wins"]:
		if data.get(key) is float or data.get(key) is int:
			clean[key] = maxi(0, int(data[key]))
	clean.level = clampi(clean.level, 1, 100)
	var ids: Dictionary = {}
	if data.get("inventory") is Array:
		for item in data.inventory:
			if not item is Dictionary or not item.get("slot", "") in Content.ITEMS:
				continue
			var id = str(item.get("id", ""))
			if id.is_empty() or ids.has(id) or clean.inventory.size() >= 20:
				continue
			ids[id] = true
			var affixes: Dictionary = {}
			if item.get("affixes") is Dictionary:
				for key in ["health", "power"]:
					affixes[key] = clampf(float(item.affixes.get(key, 0)), 0, 500)
			clean.inventory.append({"id":id, "slot":item.slot, "name":Content.ITEMS[item.slot], "level":clampi(int(item.get("level", 1)), 1, 100), "rarity":clampi(int(item.get("rarity", 0)), 0, 2), "value":clampf(float(item.get("value", 2)), 0, 500), "affixes":affixes})
	if data.get("equipment") is Dictionary:
		for item in clean.inventory:
			if data.equipment.get(item.slot, "") == item.id:
				clean.equipment[item.slot] = item.id
	if data.get("settings") is Dictionary:
		clean.settings.fps = 30 if data.settings.get("fps") == 30 else 60
		clean.settings.sound = data.settings.get("sound", true) == true
	return clean

func save_profile(data: Dictionary) -> Error:
	var payload = JSON.stringify(data)
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"payload":payload, "sha256":payload.sha256_text()}))
	f.flush()
	f.close()
	if FileAccess.file_exists(path):
		var err = DirAccess.copy_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(path + ".tmp", path)

static func stats(data: Dictionary) -> Dictionary:
	var result = {"health":110.0 + (data.level - 1) * 12, "power":18.0 + (data.level - 1) * 3, "defense":4.0, "mana":100.0}
	for item in data.inventory:
		if data.equipment.get(item.slot, "") != item.id:
			continue
		var key = {"weapon":"power", "armor":"defense", "accessory":"health"}[item.slot]
		result[key] += item.value
		for affix in item.affixes:
			if result.has(affix):
				result[affix] += item.affixes[affix]
	return result
