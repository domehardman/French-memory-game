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
