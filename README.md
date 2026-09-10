# Cinderfall — mobile-first Godot dungeon prototype

Open `project.godot` in **standard Godot 4.7** and press F6/F5 on `scenes/app_root.tscn`. The old `main.tscn` is the original static proof screen and is no longer the entry point.

## Play

- Phone: landscape. Touch and drag in the lower-left movement area: the joystick appears under your thumb and follows when you drag beyond its radius. Release to stop. Hold SLASH to attack the closest enemy, or drag outward from it to aim manually. Use another finger to cast while moving/aiming. Ability buttons remain fixed.
- EMBER fires a bolt. NOVA damages, knocks back, and stuns nearby enemies (aiming places its center ahead). MEND restores health and grants four seconds of armor.
- Tap ENTER THE GATE or walk into the cyan gate. Two waves fill each combat/elite room; the last room contains a two-phase boss.
- Walk over gold-colored gear to collect it. After combat, BAG lets you equip weapon, armor, and accessory. Full inventory leaves drops on the ground.
- Desktop fallback: WASD, Space, 1/2/3 for skills, E to advance, I inventory, Esc pause.

Public web build: **https://benforcapita.github.io/cinderfall/**. Open on a phone in landscape; the first load downloads approximately 39 MB. Progress is saved in this browser, not shared between devices.

Source: https://github.com/benforcapita/cinderfall. GitHub Pages serves the exported static files from the `gh-pages` branch; `main` contains the editable Godot project. No backend or paid hosting is required for this prototype.

## Haptics

Settings includes a saved HAPTICS on/off switch. Supported devices receive short attack, damage, and loot pulses, rate-limited to avoid continuous buzzing. Opening menus or backgrounding stops vibration. Web support depends on browser and device settings; Safari does not support Godot's standard vibration API. Unsupported devices retain visual/audio feedback. Actual vibration strength and feel require testing on a physical supported phone.

## Save behavior

Character progress is committed at room clear and when equipping or collecting gear in a cleared room. Dying, abandoning, or relaunching loses only the current uncleared room's rewards. Backgrounding pauses gameplay, releases all fingers, and flushes the last committed profile. Settings persist independently. Save data lives in Godot's `user://profile.json`; the browser uses IndexedDB and has its own separate profile. Private browsing or cleared site storage can remove browser progress. Save writes use a temporary file, SHA-256 integrity check, and a previous-copy backup.

## Validation and builds

```sh
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/visual_tests.gd
godot --headless --path . --script res://tests/touch_tests.gd
godot --headless --path . --fixed-fps 60 --script res://tests/playthrough.gd -- 719
mkdir -p builds/web
godot --headless --path . --export-release Web
python3 -m http.server 8060 --bind 127.0.0.1 --directory builds/web
```

Run these from the repository root with Godot 4.7 and matching Web export templates installed. On macOS, replace `godot` with `/Applications/Godot.app/Contents/MacOS/Godot` if it is not on PATH. The local preview is http://127.0.0.1:8060 (only accessible on that computer).

### Publish an updated build

After testing and exporting, copy the contents of `builds/web/` (excluding `*.import`) into a separate checkout of `gh-pages`, retain its `.nojekyll`, then commit and push that branch. GitHub Pages automatically deploys branch updates. Commit the corresponding source changes to `main` as well. Never copy the Godot cache, local saves, credentials, or editor settings into the published branch.

Tests use separate temporary test profiles. The 107 unit/integration checks cover combat rules, casting interruption, seeded room chains, multitouch, projectile pools/hits, every encounter, boss phase transition, victory/death persistence, corruption fallback, equipment references, inventory capacity, and background pause. The separate accelerated playthrough drives actual movement, casts, damage, healing, equipment and victory with a fresh character; it grants no extra stats and does not kill enemies directly. Neither replaces a human phone playtest.

Web uses Compatibility rendering and single-threaded WebAssembly. Export templates for Web, Android, and iOS were installed from the official Godot 4.7 template archive. Android SDK/JDK and full Xcode/signing are not configured here. No native mobile build or physical-device acceptance test has been completed.

## Code map

- `scripts/game.gd`: app composition, encounter/run lifecycle, cast/effect dispatch, UI screens, checkpoint orchestration.
- `scripts/actor.gd`: pooled CharacterBody3D actor, visual presentation, navigation agent, movement and death state.
- `scripts/mobile_hud.gd`: independent finger tracking, aim stick, action controls, HUD and native safe margins.
- `scripts/profile_store.gd`, `combat.gd`, `status_effects.gd`: persistence and isolated game rules.
- `content/skills/*.tres`: editable immutable skill Resources; `scripts/content.gd`: balance catalog, loot rolls and seeded sequence.
- `scenes/rooms/*.tscn`, `scripts/room.gd`: eight room variants, sockets, boundary collision and walkable navigation polygon.
- `scripts/projectile_pool.gd`: bounded projectiles and swept hit detection.
- `scripts/icons.gd`: cached block-pixel icons for all four abilities and three equipment types, plus ability/rarity colors.
- `scripts/block_effect.gd`: preallocated cube effects for sword arcs, Ember sparks, Nova fragments, and rising healing runes. Actor animations are presentation-only; damage and cast timings still use the original combat rules.

## Blocky visual pass

The HUD keeps its original touch hitboxes and adds colored ability icons above the labels and mana/cooldown readouts. Inventory items have matching equipment icons and rarity borders; ground drops show miniature swords, chest armor, or square signets. Characters animate their legs, anticipate attacks, swing or cast, recoil on impact, and fall/shrink on death. Death removes an actor from combat immediately; its remaining animation is visual only. Projectile cores and trails use cubes, and spell bursts share a fixed pool of 16 effects with 12 blocks each. Icons are generated once and reused, with no external art downloads.

The visual test suite checks icon coverage/caching, animation reset and death lifecycle, real cast integration, bounded effects, and inventory icons. Physical-phone performance still needs testing.

MCP is a development aid. Its three runtime IPC handlers are locally patched to do nothing in release builds. The external Node MCP server is not included or needed by the exported game. The bundled addon is from [mkdevkit/godot-mcp](https://github.com/mkdevkit/godot-mcp), under its [MIT license](addons/godot_mcp/LICENSE).

## Remaining acceptance work

This is a playable prototype using primitive geometry, procedural motion and synthesized audio. The LLD's production art/animation, genuinely distinct authored room layouts, full device performance matrix, native platform exports, and strict allocation/performance gates remain unverified or unfinished. See the implementation review appended to `LLD.md` for the concrete differences from the original plan.
