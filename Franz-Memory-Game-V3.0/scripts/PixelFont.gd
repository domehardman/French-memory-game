extends RefCounted
## Pixel-Schrift im Stil der Button-Bilder (PLAY, ERFOLGE, SET-AUSWAHL …):
## Grossbuchstaben, 5 Pixel hoch, 1 Pixel Abstand. Kleinbuchstaben werden als
## Grossbuchstaben gezeigt. Akzente (é, è, ê, ë, à, ç …) und Umlaute sitzen in
## zwei Zeilen über dem Buchstaben, Cedille und Komma in einer Zeile darunter.
##
## Benutzen:  label.add_theme_font_override("font", PixelFont.font())
##            label.add_theme_font_size_override("font_size", PixelFont.size(Faktor))
## Mit Faktor 2 ist jedes Pixel 2×2 gross (Schriftgrösse 18), mit 3 dann 3×3 (27) usw.

const CELL := 9      # 2 Zeilen Akzent + 1 Lücke + 5 Zeilen Buchstabe + 1 Zeile darunter
const ASCENT := 8

# Jede Zeile: "#" = Pixel. 5 Zeilen = Buchstabe, 6. Zeile (optional) = unter der Linie.
const GLYPHS := {
	"A": [".##.", "#..#", "####", "#..#", "#..#"],
	"B": ["###.", "#..#", "###.", "#..#", "###."],
	"C": [".##.", "#..#", "#...", "#..#", ".##."],
	"D": ["###.", "#..#", "#..#", "#..#", "###."],
	"E": ["####", "#...", "###.", "#...", "####"],
	"F": ["####", "#...", "###.", "#...", "#..."],
	"G": [".##.", "#...", "#.##", "#..#", ".##."],
	"H": ["#..#", "#..#", "####", "#..#", "#..#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"],
	"J": ["..##", "...#", "...#", "#..#", ".##."],
	"K": ["#..#", "#.#.", "##..", "#.#.", "#..#"],
	"L": ["#...", "#...", "#...", "#...", "####"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
	"N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
	"O": [".##.", "#..#", "#..#", "#..#", ".##."],
	"P": ["###.", "#..#", "###.", "#...", "#..."],
	"Q": [".##.", "#..#", "#..#", "#.#.", ".#.#"],
	"R": ["###.", "#..#", "###.", "#.#.", "#..#"],
	"S": [".###", "#...", ".##.", "...#", "###."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#..#", "#..#", "#..#", "#..#", ".##."],
	"V": ["#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"Y": ["#...#", "#...#", ".###.", "..#..", "..#.."],
	"Z": ["####", "...#", "..#.", ".#..", "####"],
	"Œ": [".####", "#.#..", "#.###", "#.#..", ".####"],
	"Æ": [".####", "#.#..", "####.", "#.#..", "#.###"],
	"0": [".##.", "#.##", "##.#", "#..#", ".##."],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###.", "...#", ".##.", "#...", "####"],
	"3": ["###.", "...#", ".##.", "...#", "###."],
	"4": ["#..#", "#..#", "####", "...#", "...#"],
	"5": ["####", "#...", "###.", "...#", "###."],
	"6": [".##.", "#...", "###.", "#..#", ".##."],
	"7": ["####", "...#", "..#.", ".#..", ".#.."],
	"8": [".##.", "#..#", ".##.", "#..#", ".##."],
	"9": [".##.", "#..#", ".###", "...#", ".##."],
	".": [".", ".", ".", ".", "#"],
	",": [".", ".", ".", ".", "#", "#"],
	":": [".", "#", ".", "#", "."],
	";": [".", "#", ".", "#", "#"],
	"!": ["#", "#", "#", ".", "#"],
	"?": ["###.", "...#", ".##.", "....", ".#.."],
	"'": ["#", "#", ".", ".", "."],
	"\"": ["#.#", "#.#", "...", "...", "..."],
	"-": ["...", "...", "###", "...", "..."],
	"–": ["....", "....", "####", "....", "...."],
	"_": ["....", "....", "....", "....", "####"],
	"+": ["...", ".#.", "###", ".#.", "..."],
	"=": ["...", "###", "...", "###", "..."],
	"/": ["...#", "...#", "..#.", ".#..", "#..."],
	"(": [".#", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", "#."],
	"&": [".#..", "#.#.", ".#.#", "#.#.", ".#.#"],
	"…": [".....", ".....", ".....", ".....", "#.#.#"],
	"·": [".", ".", "#", ".", "."],
	"%": ["#..#", "..#.", ".#..", "#...", "#..#"],
	"#": [".#.#.", "#####", ".#.#.", "#####", ".#.#."],
	"<": ["..#", ".#.", "#..", ".#.", "..#"],
	">": ["#..", ".#.", "..#", ".#.", "#.."],
	"[": ["##", "#.", "#.", "#.", "##"],
	"]": ["##", ".#", ".#", ".#", "##"],
	"←": ["..#..", ".#...", "#####", ".#...", "..#.."],
	"→": ["..#..", "...#.", "#####", "...#.", "..#.."],
	"↻": [".##.#", "#..##", "#...#", "#...#", ".###."],
	"★": ["..#..", "#####", ".###.", ".#.#.", "#...#"],
	"☆": ["..#..", "##.##", "#...#", ".#.#.", "#.#.#"],
	"×": ["...", "#.#", ".#.", "#.#", "..."],
	"○": ["....", ".##.", "#..#", "#..#", ".##."],
	"●": ["....", ".##.", "####", "####", ".##."],
	"✓": ["....#", "...#.", "#.#..", ".#...", "....."],
	"▸": ["#..", "##.", "###", "##.", "#.."],
	"▾": [".....", "#####", ".###.", "..#..", "....."],
}

# Akzente: Zeichen -> [Grundbuchstabe, Akzent]
const ACCENTED := {
	"À": ["A", "grave"], "Â": ["A", "circ"], "Ä": ["A", "uml"], "Á": ["A", "acute"],
	"Ç": ["C", "cedil"],
	"É": ["E", "acute"], "È": ["E", "grave"], "Ê": ["E", "circ"], "Ë": ["E", "uml"],
	"Î": ["I", "circ"], "Ï": ["I", "uml"], "Í": ["I", "acute"],
	"Ô": ["O", "circ"], "Ö": ["O", "uml"], "Ó": ["O", "acute"],
	"Ù": ["U", "grave"], "Û": ["U", "circ"], "Ü": ["U", "uml"], "Ú": ["U", "acute"],
	"Ÿ": ["Y", "uml"], "Ñ": ["N", "tilde"],
}

static var _font: FontFile

static func size(factor: int) -> int:
	return CELL * factor

static func font() -> FontFile:
	if _font == null:
		_font = _build()
	return _font

# Text so umformen, wie er gezeigt wird (alles gross, ß -> SS).
static func prepare(text: String) -> String:
	return text.replace("ß", "SS").replace("…", "...").replace("’", "'").replace("—", "–").to_upper()

static func _accent_rows(kind: String, width: int) -> Array:
	var mid := width / 2
	var top := ".".repeat(width)
	var low := ".".repeat(width)
	match kind:
		"acute":
			top = _put(top, mini(mid + 1, width - 1))
			low = _put(low, mid)
		"grave":
			top = _put(top, maxi(mid - 1, 0))
			low = _put(low, mid)
		"circ":
			top = _put(top, mid) if width % 2 == 1 else _put(_put(top, mid - 1), mid)
			low = _put(_put(low, 0), width - 1)
		"uml":
			low = _put(_put(low, 0), width - 1)
		"tilde":
			top = _put(_put(top, 1), width - 1)
			low = _put(_put(low, 0), mini(2, width - 1))
	return [top, low]

static func _put(row: String, index: int) -> String:
	return row.substr(0, index) + "#" + row.substr(index + 1)

static func _cell(ch: String) -> Array:
	# 9 Zeilen für ein Zeichen
	var rows: Array = []
	var base: Array
	var accent := ""
	if ACCENTED.has(ch):
		base = GLYPHS[ACCENTED[ch][0]]
		accent = ACCENTED[ch][1]
	else:
		base = GLYPHS[ch]
	var width: int = str(base[0]).length()
	if accent != "" and accent != "cedil":
		rows.append_array(_accent_rows(accent, width))
	else:
		rows.append_array([".".repeat(width), ".".repeat(width)])
	rows.append(".".repeat(width))
	for i in range(5):
		rows.append(str(base[i]))
	if base.size() > 5:
		rows.append(str(base[5]))
	elif accent == "cedil":
		rows.append(_put(".".repeat(width), width / 2))
	else:
		rows.append(".".repeat(width))
	return rows

static func _build() -> FontFile:
	var chars: Array = GLYPHS.keys() + ACCENTED.keys()
	var cells: Array = []
	var atlas_width := 1
	for ch in chars:
		var cell := _cell(ch)
		cells.append(cell)
		atlas_width += str(cell[0]).length() + 1
	var image := Image.create(atlas_width, CELL, false, Image.FORMAT_LA8)
	var f := FontFile.new()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	f.fixed_size = CELL
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.allow_system_fallback = false
	var size := Vector2i(CELL, 0)
	f.set_cache_ascent(0, CELL, ASCENT)
	f.set_cache_descent(0, CELL, CELL - ASCENT)
	var x := 1
	for i in range(chars.size()):
		var cell: Array = cells[i]
		var w: int = str(cell[0]).length()
		for y in range(CELL):
			var row := str(cell[y])
			for cx in range(w):
				if row[cx] == "#":
					image.set_pixel(x + cx, y, Color(1, 1, 1, 1))
		var cp: int = str(chars[i]).unicode_at(0)
		f.set_glyph_advance(0, CELL, cp, Vector2(w + 1, 0))
		f.set_glyph_offset(0, size, cp, Vector2(0, -ASCENT))
		f.set_glyph_size(0, size, cp, Vector2(w, CELL))
		f.set_glyph_uv_rect(0, size, cp, Rect2(x, 0, w, CELL))
		f.set_glyph_texture_idx(0, size, cp, 0)
		# Kleinbuchstaben zeigen denselben Buchstaben
		var lower := str(chars[i]).to_lower()
		if lower != str(chars[i]) and lower.length() == 1:
			var lcp := lower.unicode_at(0)
			f.set_glyph_advance(0, CELL, lcp, Vector2(w + 1, 0))
			f.set_glyph_offset(0, size, lcp, Vector2(0, -ASCENT))
			f.set_glyph_size(0, size, lcp, Vector2(w, CELL))
			f.set_glyph_uv_rect(0, size, lcp, Rect2(x, 0, w, CELL))
			f.set_glyph_texture_idx(0, size, lcp, 0)
		x += w + 1
	# Leerzeichen
	f.set_glyph_advance(0, CELL, 32, Vector2(3, 0))
	f.set_glyph_size(0, size, 32, Vector2(0, 0))
	f.set_texture_image(0, size, 0, image)
	return f
