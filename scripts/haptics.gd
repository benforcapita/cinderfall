extends RefCounted
## One short pulse at most every 150ms; no queued vibration backlog.
var next_pulse_ms = 0
const DURATIONS = {"attack":12, "damage":35, "loot":20}

func request(kind: String, enabled: bool, now_ms: int) -> int:
	if not enabled or now_ms < next_pulse_ms or not DURATIONS.has(kind): return 0
	next_pulse_ms = now_ms + 150
	return DURATIONS[kind]

func pulse(kind: String, enabled: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	if not OS.has_feature("web") and not OS.has_feature("mobile"): return
	var duration = request(kind, enabled, Time.get_ticks_msec())
	if duration > 0: Input.vibrate_handheld(duration)

func stop() -> void:
	if DisplayServer.get_name() != "headless" and (OS.has_feature("web") or OS.has_feature("mobile")):
		Input.vibrate_handheld(0)
