# Diablo-Style Mobile Game — Low-Level Design

## Scope

Godot 4.7 offline single-player vertical slice for iOS, Android, and browser: 3D isometric presentation, twin-stick controls, randomized chains of authored rooms, persistent character progression, equipment/loot, three standard enemy types, one elite modifier, and a two-phase boss. Use GDScript for the web-compatible implementation; Godot 4 C#/.NET is not a web-export option.

## Architecture

- Persistent `AppRoot` scene owns composition, save management, settings, audio, and scene transitions.
- Additive `DungeonRun` scene owns the active run, room assembly, encounter progression, player, HUD, and teardown.
- Resources/custom `Resource` classes hold immutable content definitions; plain GDScript services/models hold mutable gameplay state; Nodes adapt input, physics, animation, VFX, audio, and scene objects.
- Dependencies are injected from composition roots. No service locator or global event bus.
- Direct calls handle movement/combat hot paths; typed events handle coarse notifications such as death, loot, room clear, and save requests.
- Abstract time, randomness, persistence, and asset loading for deterministic tests.

## Core Interfaces

```gdscript
class_name ActorId
var value: String

class_name ActorCommandSink
func set_movement(intent: Vector2, magnitude: float) -> void: pass
func try_cast(request: Dictionary) -> Dictionary: return {}

class_name CombatResolver
func resolve(request: Dictionary, rng: RandomNumberGenerator) -> Dictionary: return {}

class_name RunGenerator
func generate(seed: int, catalog: Resource) -> Resource: return null

class_name SaveRepository
func load_profile() -> Dictionary: return {}
func save_profile(snapshot: Dictionary) -> void: pass

class_name ContentCatalog
func get_skill(id: String) -> Resource: return null
func get_item(id: String) -> Resource: return null
func get_enemy(id: String) -> Resource: return null
```

Runtime models include `ActorRuntime`, `SkillRuntime`, `ItemInstance`, `ProfileSnapshot`, `RunContext`, `RunLayout`, `DamageRequest`, and `DamageResult`. Serialize stable content IDs, never engine object references. These names describe intended boundaries; the prototype below uses smaller GDScript services and runtime dictionaries.

## Gameplay Flow

### Input and Movement

`InputRouter` converts the left virtual stick and right-side basic/skill buttons into `MoveIntent` and `CastRequest`. `ActorMotor` applies acceleration, rotation, collision, and navigation constraints. Players and enemies feed the same command sink.

### Skills and Combat

Cast lifecycle: `Requested → Validated → WindUp → Committed → Resolving → Recovery → Ready`.

- Validate life state, action locks, cooldown, resource, range, line of sight, and target.
- Reserve resource/cooldown during wind-up; refund only if interrupted before commit.
- Support self, aimed-direction, ground-point, and auto-target modes.
- Compose skills from damage, healing, timed stat modifier, knockback, and projectile effects.
- `CombatResolver` applies attacker snapshot/coefficient, defense mitigation, critical roll, and clamping.
- Death is idempotent: `Alive → Dying → Dead`; rewards occur only on the first transition.

### Enemy AI

State machine: `Dormant → Acquire → Chase → Attack → Recover`, with `Stagger` and `Dead` transitions. Perception/decisions tick at 5–10 Hz; motors and animation update normally. Boss phase two activates once at its health threshold.

## Dungeon, Loot, and Progression

- Run sequence: `Start → Combat ×3 → Elite → Boss`.
- Eight authored PackedScenes expose typed sockets, bounds, navigation data, spawn markers, and stable resource paths.
- Seeded generation selects compatible rooms, avoids immediate repeats, and falls back to a validated fixed chain on failure.
- `EncounterDirector` locks exits, spawns waves, tracks living encounter enemies, and unlocks exits once.
- Equipment slots: weapon, armor, accessory. Inventory capacity: 20.
- Item instances contain unique ID, definition ID, level, rarity, and zero to two numeric affixes.
- Persist level/XP, currency, inventory, equipped IDs, unlocked/equipped skills, settings, and content version. Save on room clear, equipment/settings change, backgrounding, and return to menu.
- Abandon active runs on relaunch; retain progression committed at room boundaries. No selling, crafting, stash, cloud save, multiplayer, or monetization in this slice.

## Persistence and Failure Handling

- Versioned JSON in the platform persistent-data directory.
- Atomic temp-file write, flush, backup rotation, and promotion.
- Load validates checksum/schema, migrates versions, resolves content IDs, removes unknown optional content, repairs dangling references, then falls back to backup. If both copies fail, create a new profile and show a recoverable warning.
- Missing required gameplay content blocks run start with retry/menu options. Missing optional VFX/audio uses no-op fallbacks and structured warnings.
- User pause freezes simulation. Backgrounding freezes input/simulation and flushes a safe snapshot.

## Mobile Budget

- Landscape, 60 FPS target on 2023+ mid-range iOS/Android; 30 FPS fallback tier.
- Maximum 20 active enemies and 40 simultaneous projectiles.
- Pool enemies, projectiles, loot visuals, floating text, and common VFX; prewarm before the run.
- Fixed timestep for movement/physics; staggered AI ticks; non-allocating physics queries with overflow diagnostics.
- Avoid steady-state allocations in movement, AI, targeting, combat, and projectile updates.

## Verification

- Edit-mode tests: stats, cast commit/refund rules, damage boundaries, status expiry, death idempotency, seeded loot/rooms, inventory invariants, save round-trip/migration/corruption repair.
- Godot integration tests: input wiring, targeting, projectile impacts, pool reset, room assembly, encounter completion, scene teardown, pause/background behavior.
- Device acceptance: complete a six-room run on one iOS and one Android reference device; relaunch with valid progression; test full inventory, interrupted casts, boss transition, suspension, and abandoned-run recovery.
- Acceptance requires no duplicate rewards, uncaught exceptions, visible pool exhaustion, or sustained frame time above 16.7 ms in normal encounters.

## Assumptions

Godot 4.7, GDScript, Resources, NavigationServer/NavigationRegion3D, PackedScenes, and standard Nodes are used. Content balance remains data-driven. Web export is a supported target, but requires HTTPS hosting and browser-compatible asset/memory budgets. Future cloud saves, live operations, multiplayer, and mid-run restoration require separate designs.

## Implementation review — 2026-09-10

Mobile-first is the user's overriding priority. Native iOS/Android and mobile-browser targets use landscape play, independent movement/aim fingers, attack hold, aim assistance, large touch controls, safe margins, background pause, and 30/60 FPS settings. Keyboard/mouse are secondary test inputs.

Implemented: 3D isometric gameplay, six-room seeded runs using eight PackedScene variants, two-wave encounters, three enemy types, elite health/damage modifier, two-phase boss, four editable skill Resources with composable damage/heal/projectile/knockback/modifier effects, cooldown/commit rules, defense/critical damage, XP/leveling, rarity/affixes, 20-slot inventory, three equipment slots, checkpoints, save integrity/backup recovery, pooled actors/projectiles/loot/rings/text, native navigation, sound/settings/pause, and single-threaded Web/PWA export.

Concrete implementation choices and differences:

- `game.gd` currently combines composition, run/encounter control and menu presentation. It does not yet implement every aggregate/interface name in the sketch above or fully separate encounter/AI services.
- All rooms share a connected rectangular navigation polygon and boundary geometry, with deterministic tile/rune variations. They load sequentially instead of simultaneously stitching a spatial room chain. Sockets mark entrance/exit; there is no incompatible-socket generation failure because these eight variants share one socket contract.
- Enemy attacks use explicit windup/recovery states and the same damage resolver, but do not pass through the player's skill-cast command pipeline.
- Equipment is restricted to cleared rooms/sanctuary to preserve room-boundary checkpoints and prevent partial room rewards leaking through equipment saves. Profile schema v1 is repaired/validated; future-version migrations are not implemented because no older released schema exists.
- Four skills start unlocked and equipped. There is no additional skill-unlock tree or skill loadout editor in this one-class slice.
- Primitive geometry and procedural bob/hit squash replace final art/animation. Sound is a small synthesized cue. Pooled effects have bounded capacities; strict zero-allocation hot paths are not achieved (HUD strings and small collections allocate).
- A native Godot render/playtest and desktop Chrome web startup/encounter were exercised. Automated tests cover rules and encounter completion; they do not prove balance or performance on phones.

Unfinished acceptance requirements: physical iPhone/Android touch, safe-area and suspend/relaunch testing; thermal/memory/performance measurements; native SDK/export/signing configuration; production art/content polish; stricter architecture/allocation requirements described above. The current deliverable is a playable prototype, not a claim that all production acceptance criteria have passed.
