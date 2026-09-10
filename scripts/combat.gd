extends RefCounted
## Pure rules used by both player and hostile actors.
static func damage(power: float, armor: float, critical: bool) -> float:
	return maxf(1, power * (1.5 if critical else 1.0) * 100.0 / (100.0 + maxf(0, armor)))

static func validate(skill: Resource, alive: bool, busy: bool, cooldown: float, mana: float) -> String:
	if not alive: return "dead"
	if busy: return "busy"
	if cooldown > 0: return "cooldown"
	if mana < skill.cost: return "mana"
	return ""
