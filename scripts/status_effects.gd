extends RefCounted
## Equal IDs refresh; different sources add. Expiration restores base stats.
var active: Dictionary = {}
func apply(id: String, stat: String, value: float, duration: float) -> void:
	active[id] = {"stat":stat, "value":value, "remaining":duration}
func tick(delta: float) -> void:
	for id in active.keys():
		active[id].remaining -= delta
		if active[id].remaining <= 0: active.erase(id)
func bonus(stat: String) -> float:
	var total = 0.0
	for effect in active.values():
		if effect.stat == stat: total += effect.value
	return total
