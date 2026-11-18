extends Node

const VocabularySetResource = preload("res://scripts/VocabularySet.gd")
const SAVE_DIR := "user://vocab_sets"
var save_dir := SAVE_DIR
const EXAMPLE_PATH := "res://data/vocabulary.json"
const CUSTOM_TOPIC := "Eigene Sets"

# Jedes Set: name, path, count, custom (selbst erstellt?) und topic (Themenbereich).
func list_sets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var catalog := FileAccess.open("res://data/sets.json", FileAccess.READ)
	if catalog != null:
		var items = JSON.parse_string(catalog.get_as_text())
		var hidden := hidden_sets()
		if items is Array:
			for item in items:
				if item is Dictionary and item.has("name") and item.has("path") and not hidden.has(str(item["path"])):
					var count := _read_entries(str(item["path"])).size()
					if count > 0:
						result.append({"name": str(item["name"]), "path": str(item["path"]), "count": count, "custom": false, "topic": str(item.get("topic", "Allgemein"))})
	var directory := DirAccess.open(save_dir)
	if directory == null:
		return result
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.ends_with(".json"):
			var path := save_dir.path_join(filename)
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var data = JSON.parse_string(file.get_as_text())
				if data is Dictionary and data.has("name") and data.has("entries") and _valid_entries(data["entries"]):
					var category := str(data.get("category", "")).strip_edges()
					result.append({"name": str(data["name"]), "path": path, "count": data["entries"].size(), "custom": true, "topic": category if not category.is_empty() else CUSTOM_TOPIC})
		filename = directory.get_next()
	directory.list_dir_end()
	return result

# category ist freiwillig; leer bedeutet "Eigene Sets".
# existing_path: Pfad eines eigenen Sets, das überschrieben wird (Bearbeiten).
# image_side: auf welcher Karte das Bild eines Wortpaars erscheint: "de", "fr" oder "both".
# Ein Eintrag kann ein Bild haben: "image" = gespeicherter Pfad, oder "image_data" = neues
# Image (wird beim Speichern als PNG in user://vocab_sets/images/<Set>/ abgelegt).
func save_set(name: String, entries: Array[Dictionary], category: String = "", existing_path: String = "", image_side: String = "de") -> Dictionary:
	var clean_name := name.strip_edges()
	var clean_category := category.strip_edges()
	if clean_name.is_empty():
		return {"error": "Bitte gib einen Namen ein."}
	if not _valid_entries(entries):
		return {"error": "Bitte fülle Deutsch und Französisch für jedes Wortpaar aus."}
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	if directory_error != OK:
		return {"error": "Der Speicherordner konnte nicht erstellt werden."}
	var identifier := "%d_%d" % [Time.get_unix_time_from_system(), randi_range(100000, 999999)]
	if not existing_path.is_empty() and existing_path.begins_with(save_dir) and existing_path.ends_with(".json"):
		identifier = existing_path.get_file().get_basename()
	var resource_path := save_dir.path_join(identifier + ".tres")
	var json_path := save_dir.path_join(identifier + ".json")
	var clean_entries := _store_images(identifier, entries)
	if clean_entries.is_empty():
		return {"error": "Ein Bild konnte nicht gespeichert werden."}
	var resource = VocabularySetResource.new()
	resource.set_name = clean_name
	resource.category = clean_category
	resource.entries = clean_entries.duplicate(true)
	var resource_error := ResourceSaver.save(resource, resource_path)
	if resource_error != OK:
		return {"error": "Die Godot-Resource konnte nicht gespeichert werden."}
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
		return {"error": "Die JSON-Datei konnte nicht gespeichert werden."}
	file.store_string(JSON.stringify({"name": clean_name, "category": clean_category, "image_side": image_side, "entries": clean_entries}, "  "))
	file.flush()
	file.close()
	return {"name": clean_name, "path": json_path, "resource_path": resource_path, "count": clean_entries.size(), "custom": true, "topic": clean_category if not clean_category.is_empty() else CUSTOM_TOPIC}

# Ein eigenes Set zum Bearbeiten lesen: name, category, image_side, entries
func read_set(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.has("entries"):
		return {}
	return {
		"name": str(data.get("name", "")),
		"category": str(data.get("category", "")),
		"image_side": str(data.get("image_side", "de")),
		"entries": data["entries"] if data["entries"] is Array else [],
	}

# --- Bilder in eigenen Sets ------------------------------------------------------

const IMAGE_MAX_SIZE := 512   # längste Seite in Pixeln (scharf genug für die Karten)

func image_dir(identifier: String) -> String:
	return save_dir.path_join("images").path_join(identifier)

# Neues Bild aus einer Datei laden und auf IMAGE_MAX_SIZE verkleinern.
static func load_picture(file_path: String) -> Image:
	var image := Image.load_from_file(file_path)
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var longest := maxi(image.get_width(), image.get_height())
	if longest > IMAGE_MAX_SIZE:
		var factor := float(IMAGE_MAX_SIZE) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	return image

# Bild eines gespeicherten Eintrags laden (oder null)
static func entry_picture(path: String) -> Image:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return image if image != null and not image.is_empty() else null

# Neue Bilder als PNG ablegen, nicht mehr benutzte Bilder des Sets löschen.
# Gibt die Einträge ohne "image_data" zurück (leer = Fehler).
func _store_images(identifier: String, entries: Array[Dictionary]) -> Array[Dictionary]:
	var folder := image_dir(identifier)
	var result: Array[Dictionary] = []
	var used: Array[String] = []
	for entry in entries:
		var clean := {"de": str(entry["de"]).strip_edges(), "fr": str(entry["fr"]).strip_edges()}
		var picture = entry.get("image_data")
		if picture is Image:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			var image_path := folder.path_join("%d_%d.png" % [Time.get_ticks_usec(), randi_range(1000, 9999)])
			if picture.save_png(ProjectSettings.globalize_path(image_path)) != OK:
				return []
			clean["image"] = image_path
		elif not str(entry.get("image", "")).is_empty():
			clean["image"] = str(entry["image"])
		if clean.has("image"):
			used.append(str(clean["image"]).get_file())
		result.append(clean)
	_remove_unused_images(folder, used)
	return result

func _remove_unused_images(folder: String, keep: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	for file_name in directory.get_files():
		if not keep.has(file_name):
			directory.remove(file_name)
	if keep.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

# --- Löschen -----------------------------------------------------------------
# Eigene Sets werden wirklich gelöscht (.json und .tres).
# Das Beispielset liegt im Spiel selbst und wird deshalb nur ausgeblendet
# (Liste in user://hidden_sets.json, in den Einstellungen wiederherstellbar).

const HIDDEN_PATH := "user://hidden_sets.json"
var hidden_path := HIDDEN_PATH

func can_delete(path: String) -> bool:
	return path == EXAMPLE_PATH or path.begins_with(save_dir)

func delete_set(path: String) -> Dictionary:
	if path == EXAMPLE_PATH:
		var hidden := hidden_sets()
		if not hidden.has(path):
			hidden.append(path)
		_write_hidden(hidden)
		return {"deleted": path}
	if not path.begins_with(save_dir) or not path.ends_with(".json"):
		return {"error": "Dieses Set kann nicht gelöscht werden."}
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return {"error": "Das Set konnte nicht gelöscht werden."}
	var resource_path := path.get_basename() + ".tres"
	if FileAccess.file_exists(resource_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	# Bilder des Sets mitlöschen
	_remove_unused_images(image_dir(path.get_file().get_basename()), [])
	return {"deleted": path}

func hidden_sets() -> Array:
	var file := FileAccess.open(hidden_path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []

func has_hidden_sets() -> bool:
	return not hidden_sets().is_empty()

func restore_hidden_sets() -> void:
	_write_hidden([])

func _write_hidden(list: Array) -> void:
	var file := FileAccess.open(hidden_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(list))

# Sucht ein Set über den Pfad (z. B. für Name und Thema im Spiel).
func find_set(path: String) -> Dictionary:
	for item in list_sets():
		if item["path"] == path:
			return item
	return {}

func _read_entries(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("entries"):
		parsed = parsed["entries"]
	if _valid_entries(parsed):
		return parsed
	return []

func _valid_entries(entries: Variant) -> bool:
	if not entries is Array or entries.is_empty():
		return false
	for entry in entries:
		if not entry is Dictionary or not entry.has("de") or not entry.has("fr"):
			return false
		if str(entry["de"]).strip_edges().is_empty() or str(entry["fr"]).strip_edges().is_empty():
			return false
	return true


# --- Eigene Kategorien ---------------------------------------------------------
# Kategorien können auch leer sein (z. B. gleich nach dem Erstellen). Sie stehen in
# user://categories.json. Eine Kategorie mit Sets entsteht ausserdem von selbst,
# sobald ein Set sie als "category" hat.

const CATEGORIES_PATH := "user://categories.json"
var categories_path := CATEGORIES_PATH

func saved_categories() -> Array:
	var file := FileAccess.open(categories_path, FileAccess.READ)
	if file == null:
		return []
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Array else []

func _write_categories(list: Array) -> void:
	var file := FileAccess.open(categories_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(list, "  "))

# Alle eigenen Kategorien (gespeicherte und solche, die Sets benutzen), ohne "Eigene Sets".
func all_categories() -> Array:
	var result: Array = []
	for name in saved_categories():
		if not result.has(str(name)):
			result.append(str(name))
	for item in list_sets():
		var topic := str(item.get("topic", ""))
		if bool(item.get("custom", false)) and topic != CUSTOM_TOPIC and not result.has(topic):
			result.append(topic)
	result.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	return result

func add_category(name: String) -> Dictionary:
	var clean := name.strip_edges()
	if clean.is_empty():
		return {"error": "Bitte gib einen Namen für die Kategorie ein."}
	if clean == CUSTOM_TOPIC or all_categories().has(clean):
		return {"error": "Diese Kategorie gibt es schon."}
	var list := saved_categories()
	list.append(clean)
	_write_categories(list)
	return {"category": clean}

# Kategorie entfernen. Ihre Sets kommen zurück zu "Eigene Sets".
func remove_category(name: String) -> void:
	var list := saved_categories()
	list.erase(name)
	_write_categories(list)
	for item in list_sets():
		if bool(item.get("custom", false)) and str(item.get("topic", "")) == name:
			set_category(str(item["path"]), "")

# Ein eigenes Set in eine andere Kategorie verschieben ("" = Eigene Sets).
func set_category(path: String, category: String) -> Dictionary:
	if not path.begins_with(save_dir) or not path.ends_with(".json"):
		return {"error": "Nur eigene Sets können verschoben werden."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Das Set wurde nicht gefunden."}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return {"error": "Das Set konnte nicht gelesen werden."}
	var clean := category.strip_edges()
	if clean == CUSTOM_TOPIC:
		clean = ""
	data["category"] = clean
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "Das Set konnte nicht gespeichert werden."}
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	var resource_path := path.get_basename() + ".tres"
	if ResourceLoader.exists(resource_path):
		var resource = load(resource_path)
		if resource != null and "category" in resource:
			resource.category = clean
			ResourceSaver.save(resource, resource_path)
	if not clean.is_empty() and not saved_categories().has(clean):
		var list := saved_categories()
		list.append(clean)
		_write_categories(list)
	return {"category": clean}

# --- Sets aus Dateien importieren (CSV oder JSON) --------------------------------------
# Erlaubt sind nur Dateien, die vollständig stimmen. Sonst wird die ganze Datei abgelehnt
# und parse_import_file gibt in "errors" genau an, was nicht passt.

const IMPORT_MAX_BYTES := 512000
const IMPORT_MIN_PAIRS := 2
const IMPORT_MAX_PAIRS := 500
const IMPORT_MAX_TEXT := 60
const HEADER_DE := ["de", "deutsch", "german", "allemand"]
const HEADER_FR := ["fr", "franzosisch", "französisch", "franzoesisch", "francais", "français", "french"]

func _import_fail(file_name: String, errors: Array) -> Dictionary:
	return {"ok": false, "file": file_name, "errors": errors}

# Datei lesen und prüfen. Ergebnis: ok, file, name, category, entries, notes oder errors
func parse_import_file(path: String) -> Dictionary:
	var file_name := path.get_file()
	var extension := path.get_extension().to_lower()
	if extension != "csv" and extension != "json":
		return _import_fail(file_name, ["Falsches Dateiformat. Erlaubt sind nur .csv und .json."])
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _import_fail(file_name, ["Die Datei konnte nicht geöffnet werden."])
	var size := file.get_length()
	if size == 0:
		return _import_fail(file_name, ["Die Datei ist leer."])
	if size > IMPORT_MAX_BYTES:
		return _import_fail(file_name, ["Die Datei ist zu gross (höchstens 500 KB)."])
	var bytes := file.get_buffer(size)
	file.close()
	if bytes.size() >= 2 and ((bytes[0] == 0xFF and bytes[1] == 0xFE) or (bytes[0] == 0xFE and bytes[1] == 0xFF)):
		return _import_fail(file_name, ["Die Datei ist nicht in UTF-8 gespeichert. Speichere sie als „CSV UTF-8“ oder „UTF-8“."])
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		bytes = bytes.slice(3)
	if bytes.has(0):
		return _import_fail(file_name, ["Das ist keine Textdatei."])
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _import_fail(file_name, ["Die Datei ist nicht in UTF-8 gespeichert, Umlaute und Akzente wären kaputt. Speichere sie als „CSV UTF-8“ oder „UTF-8“."])
	var parsed := _parse_csv_set(text) if extension == "csv" else _parse_json_set(text)
	if parsed.has("errors"):
		return _import_fail(file_name, parsed["errors"])
	var name := str(parsed.get("name", "")).strip_edges()
	if name.is_empty():
		name = path.get_file().get_basename().replace("_", " ").strip_edges()
	return _check_pairs(file_name, name.left(40), str(parsed.get("category", "")).strip_edges().left(40), parsed["pairs"], parsed.get("notes", []))

# Gemeinsame Prüfung. pairs: Liste aus {where, de, fr}
func _check_pairs(file_name: String, name: String, category: String, pairs: Array, notes: Array) -> Dictionary:
	var errors: Array = []
	var seen := {}
	var entries: Array[Dictionary] = []
	var duplicates := 0
	for pair in pairs:
		var where := str(pair["where"])
		var de := str(pair["de"]).strip_edges()
		var fr := str(pair["fr"]).strip_edges()
		if de.is_empty() and fr.is_empty():
			errors.append(where + ": Deutsch und Französisch fehlen.")
		elif de.is_empty():
			errors.append(where + ": Deutsch fehlt.")
		elif fr.is_empty():
			errors.append(where + ": Französisch fehlt.")
		elif de.length() > IMPORT_MAX_TEXT or fr.length() > IMPORT_MAX_TEXT:
			errors.append(where + ": Text ist zu lang (höchstens %d Zeichen)." % IMPORT_MAX_TEXT)
		else:
			var key := de.to_lower() + "\n" + fr.to_lower()
			if seen.has(key):
				duplicates += 1
			else:
				seen[key] = true
				entries.append({"de": de, "fr": fr})
	if not errors.is_empty():
		return _import_fail(file_name, errors)
	if entries.size() < IMPORT_MIN_PAIRS:
		return _import_fail(file_name, ["Zu wenige Wortpaare: Es braucht mindestens %d, gefunden: %d." % [IMPORT_MIN_PAIRS, entries.size()]])
	if entries.size() > IMPORT_MAX_PAIRS:
		return _import_fail(file_name, ["Zu viele Wortpaare: höchstens %d, gefunden: %d." % [IMPORT_MAX_PAIRS, entries.size()]])
	var all_notes := notes.duplicate()
	if duplicates > 0:
		all_notes.append("1 doppeltes Wortpaar wurde übersprungen." if duplicates == 1 else "%d doppelte Wortpaare wurden übersprungen." % duplicates)
	return {"ok": true, "file": file_name, "name": name, "category": category, "entries": entries, "notes": all_notes}

func _parse_json_set(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"errors": ["Kein gültiges JSON (Zeile %d): %s" % [json.get_error_line(), json.get_error_message()]]}
	var data = json.data
	var name := ""
	var category := ""
	if data is Dictionary:
		if not data.has("entries"):
			return {"errors": ["Im JSON fehlt die Liste „entries“ mit den Wortpaaren."]}
		name = str(data.get("name", ""))
		category = str(data.get("category", ""))
		data = data["entries"]
	if not data is Array:
		return {"errors": ["„entries“ muss eine Liste von Wortpaaren sein."]}
	var pairs: Array = []
	var errors: Array = []
	var notes: Array = []
	for i in range(data.size()):
		var entry = data[i]
		var where := "Eintrag %d" % [i + 1]
		if not entry is Dictionary:
			errors.append(where + ": muss so aussehen: {\"de\": \"…\", \"fr\": \"…\"}.")
		elif not entry.has("de") or not entry.has("fr"):
			errors.append(where + ": „de“ oder „fr“ fehlt.")
		elif not entry["de"] is String or not entry["fr"] is String:
			errors.append(where + ": „de“ und „fr“ müssen Text sein.")
		else:
			pairs.append({"where": where, "de": entry["de"], "fr": entry["fr"]})
			if entry.has("image") and notes.is_empty():
				notes.append("Bilder aus der Datei werden nicht übernommen.")
	if not errors.is_empty():
		return {"errors": errors}
	return {"name": name, "category": category, "pairs": pairs, "notes": notes}

# CSV in Zeilen zerlegen: Anführungszeichen schützen Trennzeichen, "" ist ein echtes "
func _csv_rows(text: String, delimiter: String) -> Dictionary:
	var rows: Array = []
	var cells: Array = []
	var cell := ""
	var quoted := false
	var line := 1
	var row_line := 1
	var i := 0
	while i < text.length():
		var c := text[i]
		if quoted:
			if c == "\"":
				if i + 1 < text.length() and text[i + 1] == "\"":
					cell += "\""
					i += 1
				else:
					quoted = false
			else:
				if c == "\n":
					line += 1
				cell += c
		elif c == "\"" and cell.strip_edges().is_empty():
			cell = ""
			quoted = true
		elif c == delimiter:
			cells.append(cell)
			cell = ""
		elif c == "\n" or c == "\r":
			if c == "\r" and i + 1 < text.length() and text[i + 1] == "\n":
				i += 1
			cells.append(cell)
			rows.append({"line": row_line, "cells": cells})
			cells = []
			cell = ""
			line += 1
			row_line = line
		else:
			cell += c
		i += 1
	if quoted:
		return {"error": "Zeile %d: Ein Anführungszeichen wird nicht geschlossen." % row_line}
	if not cell.is_empty() or not cells.is_empty():
		cells.append(cell)
		rows.append({"line": row_line, "cells": cells})
	return {"rows": rows}

func _csv_delimiter(text: String) -> String:
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		if line.to_lower().begins_with("sep=") and line.length() >= 5:
			return line[4]
		var best := ";"
		var most := 0
		for d in [";", ",", "\t"]:
			var count := line.count(d)
			if count > most:
				most = count
				best = d
		return best
	return ";"

func _parse_csv_set(text: String) -> Dictionary:
	var delimiter := _csv_delimiter(text)
	var split := _csv_rows(text, delimiter)
	if split.has("error"):
		return {"errors": [split["error"]]}
	var rows: Array = []
	for row in split["rows"]:
		var joined := "".join(PackedStringArray(row["cells"])).strip_edges()
		if joined.is_empty() or str(row["cells"][0]).strip_edges().to_lower().begins_with("sep="):
			continue
		rows.append(row)
	if rows.is_empty():
		return {"errors": ["In der Datei stehen keine Wortpaare."]}
	var de_column := 0
	var fr_column := 1
	var first: Array = rows[0]["cells"]
	if first.size() == 2:
		var a := str(first[0]).strip_edges().to_lower()
		var b := str(first[1]).strip_edges().to_lower()
		if HEADER_DE.has(a) and HEADER_FR.has(b):
			rows.remove_at(0)
		elif HEADER_FR.has(a) and HEADER_DE.has(b):
			de_column = 1
			fr_column = 0
			rows.remove_at(0)
	var pairs: Array = []
	var errors: Array = []
	for row in rows:
		var where := "Zeile %d" % int(row["line"])
		var cells: Array = row["cells"]
		if cells.size() != 2:
			errors.append(where + ": %d %s statt 2. Enthält ein Wort das Trennzeichen, setze es in Anführungszeichen." % [cells.size(), "Spalte" if cells.size() == 1 else "Spalten"])
		else:
			pairs.append({"where": where, "de": cells[de_column], "fr": cells[fr_column]})
	if not errors.is_empty():
		return {"errors": errors}
	return {"pairs": pairs}

func _unique_set_name(name: String) -> String:
	var used := {}
	for item in list_sets():
		used[str(item["name"]).to_lower()] = true
	if not used.has(name.to_lower()):
		return name
	var number := 2
	while used.has(("%s (%d)" % [name, number]).to_lower()):
		number += 1
	return "%s (%d)" % [name, number]

# Datei prüfen und als eigenes Set speichern. category: leer = die aus der Datei
func import_file(path: String, category: String = "") -> Dictionary:
	var parsed := parse_import_file(path)
	if not parsed["ok"]:
		return parsed
	var name := _unique_set_name(str(parsed["name"]))
	var entries: Array[Dictionary] = parsed["entries"]
	var target := category.strip_edges() if not category.strip_edges().is_empty() else str(parsed["category"])
	var saved := save_set(name, entries, target)
	if saved.has("error"):
		return _import_fail(str(parsed["file"]), [str(saved["error"])])
	return {"ok": true, "file": parsed["file"], "name": name, "path": saved["path"], "count": entries.size(), "notes": parsed["notes"]}
