extends RefCounted
## Pixel-Schrift im Stil der Button-Bilder (PLAY, ERFOLGE, SET-AUSWAHL …):
## Grossbuchstaben 5 Pixel hoch, Kleinbuchstaben 4 Pixel (mit Ober- und Unterlängen),
## 1 Pixel Abstand. Akzente (é, è, ê, ë, à, ç …) und Umlaute sitzen über dem
## Buchstaben, Cedille, Komma und Unterlängen (g, p, q, y, j) in einer Zeile darunter.
##
## Benutzen:  label.add_theme_font_override("font", PixelFont.font())
##            label.add_theme_font_size_override("font_size", PixelFont.size(Faktor))
## Mit Faktor 2 ist jedes Pixel 2×2 gross (Schriftgrösse 18), mit 3 dann 3×3 (27) usw.
##
## Umrandung: Die Schrift hat eine eingebaute Pixel-Umrandung (1 Schrift-Pixel breit).
## Sie erscheint, sobald ein Label "outline_size" > 0 hat, in der Farbe
## "font_outline_color" (im Spiel weiss, siehe MenuUI.outlined()).
##
## Neue Zeichen: einfach in GLYPHS dazuschreiben ("#" = Pixel, "." = leer).

const CELL := 9      # 2 Zeilen Akzent + 1 Lücke + 5 Zeilen Buchstabe + 1 Zeile darunter
const ASCENT := 8

# Jede Zeile: "#" = Pixel. 5 Zeilen = Buchstabe, 6. Zeile (optional) = unter der Linie.
# Kleinbuchstaben: Zeile 1 = Oberlänge (b, d, f, h, k, l, t), Zeilen 2–5 = Mittelhöhe.
const GLYPHS := {
	# --- Grossbuchstaben ---
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
	"Ø": [".###.", "#..##", "#.#.#", "##..#", ".###."],
	# --- Kleinbuchstaben ---
	"a": ["....", ".###", "#..#", "#..#", ".###"],
	"b": ["#...", "###.", "#..#", "#..#", "###."],
	"c": ["...", ".##", "#..", "#..", ".##"],
	"d": ["...#", ".###", "#..#", "#..#", ".###"],
	"e": ["....", ".##.", "####", "#...", ".###"],
	"f": [".##", "#..", "##.", "#..", "#.."],
	"g": ["....", ".###", "#..#", ".###", "...#", "###."],
	"h": ["#...", "###.", "#..#", "#..#", "#..#"],
	"i": ["#", ".", "#", "#", "#"],
	"ı": [".", ".", "#", "#", "#"],
	"j": [".#", "..", ".#", ".#", ".#", "#."],
	"k": ["#..", "#.#", "##.", "#.#", "#.#"],
	"l": ["#.", "#.", "#.", "#.", ".#"],
	"m": [".....", "####.", "#.#.#", "#.#.#", "#.#.#"],
	"n": ["....", "###.", "#..#", "#..#", "#..#"],
	"o": ["....", ".##.", "#..#", "#..#", ".##."],
	"p": ["....", "###.", "#..#", "###.", "#...", "#..."],
	"q": ["....", ".###", "#..#", ".###", "...#", "...#"],
	"r": ["...", "#.#", "##.", "#..", "#.."],
	"s": ["....", ".###", "##..", "..##", "###."],
	"t": [".#.", "###", ".#.", ".#.", "..#"],
	"u": ["....", "#..#", "#..#", "#..#", ".###"],
	"v": ["...", "#.#", "#.#", "#.#", ".#."],
	"w": [".....", "#...#", "#.#.#", "#.#.#", ".#.#."],
	"x": ["....", "#..#", ".##.", ".##.", "#..#"],
	"y": ["....", "#..#", "#..#", ".###", "...#", ".##."],
	"z": ["....", "####", "..#.", ".#..", "####"],
	"ß": [".##.", "#..#", "#.#.", "#..#", "#.#."],
	"œ": [".....", ".####", "#.##.", "#.#..", ".####"],
	"æ": [".....", "####.", "..###", "###..", "#####"],
	"ø": ["....", ".###", "#.##", "##.#", "###."],
	# --- Ziffern ---
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
	"²": ["##.", "..#", ".#.", "###", "..."],
	"³": ["##.", ".##", "..#", "##.", "..."],
	# --- Satzzeichen ---
	".": [".", ".", ".", ".", "#"],
	",": [".", ".", ".", ".", "#", "#"],
	":": [".", "#", ".", "#", "."],
	";": [".", "#", ".", "#", "#"],
	"!": ["#", "#", "#", ".", "#"],
	"¡": ["#", ".", "#", "#", "#"],
	"?": ["###.", "...#", ".##.", "....", ".#.."],
	"¿": ["..#.", "....", ".##.", "#...", ".###"],
	"'": ["#", "#", ".", ".", "."],
	"’": ["#", "#", ".", ".", "."],
	"‘": ["#", "#", ".", ".", "."],
	"‚": [".", ".", ".", ".", "#", "#"],
	"`": ["#.", ".#", "..", "..", ".."],
	"\"": ["#.#", "#.#", "...", "...", "..."],
	"“": ["#.#", "#.#", "...", "...", "..."],
	"”": ["#.#", "#.#", "...", "...", "..."],
	"„": ["...", "...", "...", "...", "#.#", "#.#"],
	"«": ["....", ".#.#", "#.#.", ".#.#", "...."],
	"»": ["....", "#.#.", ".#.#", "#.#.", "...."],
	"‹": ["..", ".#", "#.", ".#", ".."],
	"›": ["..", "#.", ".#", "#.", ".."],
	"-": ["...", "...", "###", "...", "..."],
	"–": ["....", "....", "####", "....", "...."],
	"—": [".....", ".....", "#####", ".....", "....."],
	"_": ["....", "....", "....", "....", "####"],
	"+": ["...", ".#.", "###", ".#.", "..."],
	"=": ["...", "###", "...", "###", "..."],
	"*": ["#.#", ".#.", "#.#", "...", "..."],
	"/": ["...#", "...#", "..#.", ".#..", "#..."],
	"\\": ["#...", "#...", ".#..", "..#.", "...#"],
	"|": ["#", "#", "#", "#", "#"],
	"(": [".#", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", "#."],
	"[": ["##", "#.", "#.", "#.", "##"],
	"]": ["##", ".#", ".#", ".#", "##"],
	"{": [".##", ".#.", "#..", ".#.", ".##"],
	"}": ["##.", ".#.", "..#", ".#.", "##."],
	"<": ["..#", ".#.", "#..", ".#.", "..#"],
	">": ["#..", ".#.", "..#", ".#.", "#.."],
	"&": [".#..", "#.#.", ".#.#", "#.#.", ".#.#"],
	"@": [".###.", "#...#", "#.###", "#.##.", ".##.."],
	"#": [".#.#.", "#####", ".#.#.", "#####", ".#.#."],
	"%": ["#..#", "..#.", ".#..", "#...", "#..#"],
	"$": [".###.", "#.#..", ".###.", "..#.#", ".###."],
	"€": [".###", "#...", "###.", "#...", ".###"],
	"£": [".##.", "#...", "###.", "#...", "####"],
	"~": ["....", ".#.#", "#.#.", "....", "...."],
	"^": [".#.", "#.#", "...", "...", "..."],
	"°": [".#.", "#.#", ".#.", "...", "..."],
	"§": [".##", "#..", ".#.", "..#", "##."],
	"…": [".....", ".....", ".....", ".....", "#.#.#"],
	"·": [".", ".", "#", ".", "."],
	# --- Symbole im Spiel ---
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
	"Ã": ["A", "tilde"], "Å": ["A", "ring"],
	"Ç": ["C", "cedil"],
	"É": ["E", "acute"], "È": ["E", "grave"], "Ê": ["E", "circ"], "Ë": ["E", "uml"],
	"Î": ["I", "circ"], "Ï": ["I", "uml"], "Í": ["I", "acute"], "Ì": ["I", "grave"],
	"Ô": ["O", "circ"], "Ö": ["O", "uml"], "Ó": ["O", "acute"], "Ò": ["O", "grave"], "Õ": ["O", "tilde"],
	"Ù": ["U", "grave"], "Û": ["U", "circ"], "Ü": ["U", "uml"], "Ú": ["U", "acute"],
	"Ÿ": ["Y", "uml"], "Ñ": ["N", "tilde"],
	"à": ["a", "grave"], "â": ["a", "circ"], "ä": ["a", "uml"], "á": ["a", "acute"],
	"ã": ["a", "tilde"], "å": ["a", "ring"],
	"ç": ["c", "cedil"],
	"é": ["e", "acute"], "è": ["e", "grave"], "ê": ["e", "circ"], "ë": ["e", "uml"],
	"î": ["ı", "circ"], "ï": ["ı", "uml"], "í": ["ı", "acute"], "ì": ["ı", "grave"],
	"ô": ["o", "circ"], "ö": ["o", "uml"], "ó": ["o", "acute"], "ò": ["o", "grave"], "õ": ["o", "tilde"],
	"ù": ["u", "grave"], "û": ["u", "circ"], "ü": ["u", "uml"], "ú": ["u", "acute"],
	"ÿ": ["y", "uml"], "ñ": ["n", "tilde"],
}

static var _font: FontFile

static func size(factor: int) -> int:
	return CELL * factor

static func font() -> FontFile:
	if _font == null:
		_font = _build()
	return _font

# Text für die Bild-Buttons umformen (alles gross wie auf PLAY, SETS …, ß -> SS).
# Normale Texte brauchen das nicht mehr: die Schrift kennt jetzt auch Kleinbuchstaben.
static func prepare(text: String) -> String:
	return text.replace("ß", "SS").replace("…", "...").to_upper()

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
		"ring":
			top = _put(_put(top, mid - 1), mid) if width % 2 == 0 else _put(top, mid)
			low = top
	return [top, low]

static func _put(row: String, index: int) -> String:
	return row.substr(0, index) + "#" + row.substr(index + 1)

static func _is_lower(base: String) -> bool:
	return base == "ı" or base != base.to_upper()

static func _cell(ch: String) -> Array:
	# 9 Zeilen für ein Zeichen
	var rows: Array = []
	var base: Array
	var base_char := ch
	var accent := ""
	if ACCENTED.has(ch):
		base_char = ACCENTED[ch][0]
		base = GLYPHS[base_char]
		accent = ACCENTED[ch][1]
	else:
		base = GLYPHS[ch]
	var width: int = str(base[0]).length()
	var empty := ".".repeat(width)
	if accent != "" and accent != "cedil":
		var marks := _accent_rows(accent, width)
		if _is_lower(base_char):
			# Kleinbuchstaben sind niedriger: Akzent eine Zeile tiefer
			rows.append_array([empty, marks[0], marks[1]])
		else:
			rows.append_array([marks[0], marks[1], empty])
	else:
		rows.append_array([empty, empty, empty])
	for i in range(5):
		rows.append(str(base[i]))
	if base.size() > 5:
		rows.append(str(base[5]))
	elif accent == "cedil":
		rows.append(_put(empty, width / 2))
	else:
		rows.append(empty)
	return rows

static func _build() -> FontFile:
	var chars: Array = GLYPHS.keys() + ACCENTED.keys()
	var cells: Array = []
	var atlas_width := 1
	var outline_width := 1
	for ch in chars:
		var cell := _cell(ch)
		cells.append(cell)
		atlas_width += str(cell[0]).length() + 1
		outline_width += str(cell[0]).length() + 3
	var image := Image.create(atlas_width, CELL, false, Image.FORMAT_LA8)
	# Zweites Bild: dieselben Zeichen, rundum 1 Pixel dicker (= Umrandung)
	var outline := Image.create(outline_width, CELL + 2, false, Image.FORMAT_LA8)
	var f := FontFile.new()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	f.fixed_size = CELL
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.allow_system_fallback = false
	var size := Vector2i(CELL, 0)
	var outline_size := Vector2i(CELL, 1)   # Bitmap-Schriften haben genau eine Umrandungsstufe
	f.set_cache_ascent(0, CELL, ASCENT)
	f.set_cache_descent(0, CELL, CELL - ASCENT)
	var white := Color(1, 1, 1, 1)
	var x := 1
	var ox := 1
	for i in range(chars.size()):
		var cell: Array = cells[i]
		var w: int = str(cell[0]).length()
		for y in range(CELL):
			var row := str(cell[y])
			for cx in range(w):
				if row[cx] == "#":
					image.set_pixel(x + cx, y, white)
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							outline.set_pixel(ox + 1 + cx + dx, 1 + y + dy, white)
		var cp: int = str(chars[i]).unicode_at(0)
		f.set_glyph_advance(0, CELL, cp, Vector2(w + 1, 0))
		f.set_glyph_offset(0, size, cp, Vector2(0, -ASCENT))
		f.set_glyph_size(0, size, cp, Vector2(w, CELL))
		f.set_glyph_uv_rect(0, size, cp, Rect2(x, 0, w, CELL))
		f.set_glyph_texture_idx(0, size, cp, 0)
		f.set_glyph_offset(0, outline_size, cp, Vector2(-1, -ASCENT - 1))
		f.set_glyph_size(0, outline_size, cp, Vector2(w + 2, CELL + 2))
		f.set_glyph_uv_rect(0, outline_size, cp, Rect2(ox, 0, w + 2, CELL + 2))
		f.set_glyph_texture_idx(0, outline_size, cp, 0)
		x += w + 1
		ox += w + 3
	# Leerzeichen (normal und geschützt)
	for space in [32, 160]:
		f.set_glyph_advance(0, CELL, space, Vector2(3, 0))
		f.set_glyph_size(0, size, space, Vector2(0, 0))
		f.set_glyph_size(0, outline_size, space, Vector2(0, 0))
	f.set_texture_image(0, size, 0, image)
	f.set_texture_image(0, outline_size, 0, outline)
	return f
