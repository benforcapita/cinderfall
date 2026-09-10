extends RefCounted
## Small, cached pixel silhouettes. No per-frame image creation or external assets.
static var cache: Dictionary = {}
const COLORS = {"s":Color("243942"), "d":Color("546779"), "m":Color("91b6c4"), "h":Color("e9f4e9"), "g":Color("e8bd79"), "b":Color("906440"), "r":Color("bd503c"), "o":Color("ff9957"), "y":Color("ffe2a0"), "p":Color("9876da"), "v":Color("d5b6ff"), "t":Color("50b997"), "e":Color("a3f2c4")}
const GLYPHS = {
	"slash":["............hh..", "...........hmh..", "..........hmh...", ".........hmh....", "........hmh.....", ".......hmh......", "......hmh.......", "..g..hmh........", "..gggmh.........", "...ggg..........", "...bggg.........", "..bb..g.........", ".bb.............", ".g.............."],
	"ember":[".......o........", ".......yo.......", "......oyoo......", ".....oyyoo......", ".....oyhoo..r...", "..r.oyyhhoo.ro...", "..rooyyhhoooro..", "..rooyhhhyooro..", "..rooyhhhhyoro..", "...rooyhyyor....", "....rooyoor.....", ".....rrrrr......"],
	"nova":[".......v........", "......vhp.......", "..v...vhp...v...", "...p..vhp..v....", "......vpp.......", ".vvv..pp..vvvp..", "..ppp....ppp....", "......pp........", ".....pvvp.......", "...p.pvhp.p.....", "..v..pvhp..v....", ".....pvp........", "......p........."],
	"mend":["......ee........", ".....ehht.......", ".....ehht.......", ".....ehht.......", "..eeeehhtttt....", ".ehhhhhhhhhtt...", ".etttthhttttt...", "..ttttehtt......", ".....ehht.......", ".....ehht.......", "......tt........", "..e........e....", "...t......t....."],
	"weapon":["......hh........", "......hm........", "......hm........", "......hm........", "......hm........", "......hm........", "......hm........", "......hm........", "...ggghmggg.....", "...bggggggb.....", "......gb........", "......gb........", "......gb........", ".....gggb......."],
	"armor":["...mm....mm.....", "..mhhd..mhmd....", ".mhhhhddhhmmd...", ".mhmmhhhhmmmd...", ".mmdmhghmdmmd...", "....mhghmd......", "....mhghmd......", "....mhghmd......", "....mhghmd......", "....mhhhmd......", "...mmmmmmdd.....", "...ggggggbb.....", "....dddddd......"],
	"accessory":["......vv........", ".....vhvp.......", "....vhhvpp......", ".....vvpp.......", "....ggggbb......", "...gy....gb.....", "..gy......gb....", "..gy......gb....", "..gy......gb....", "...gy....gb.....", "....ggggbb......", ".....bbbb......."]
}

static func texture(id: String) -> Texture2D:
	if cache.has(id): return cache[id]
	var pixels = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	var rows: Array = GLYPHS.get(id, GLYPHS.accessory)
	for y in range(rows.size()):
		for x in range(mini(rows[y].length(), 16)):
			var key = rows[y][x]
			if COLORS.has(key): pixels.fill_rect(Rect2i(x * 4, y * 4 + 4, 4, 4), COLORS[key])
	cache[id] = ImageTexture.create_from_image(pixels)
	return cache[id]

static func rarity_color(rarity: int) -> Color:
	return [Color("a8bec8"), Color("72baff"), Color("c69bff")][clampi(rarity, 0, 2)]

static func ability_color(id: String) -> Color:
	return {"slash":Color("f2cf8e"), "ember":Color("ff9957"), "nova":Color("b999fa"), "mend":Color("8be8b3")}.get(id, Color("f2cf8e"))
