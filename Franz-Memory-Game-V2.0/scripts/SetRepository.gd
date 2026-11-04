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
func save_set(name: String, entries: Array[Dictionary], category: String = "") -> Dictionary:
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
	var resource_path := save_dir.path_join(identifier + ".tres")
	var json_path := save_dir.path_join(identifier + ".json")
	var resource = VocabularySetResource.new()
	resource.set_name = clean_name
	resource.category = clean_category
	resource.entries = entries.duplicate(true)
	var resource_error := ResourceSaver.save(resource, resource_path)
	if resource_error != OK:
		return {"error": "Die Godot-Resource konnte nicht gespeichert werden."}
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
		return {"error": "Die JSON-Datei konnte nicht gespeichert werden."}
	file.store_string(JSON.stringify({"name": clean_name, "category": clean_category, "entries": entries}, "  "))
	file.flush()
	file.close()
	return {"name": clean_name, "path": json_path, "resource_path": resource_path, "count": entries.size(), "custom": true, "topic": clean_category if not clean_category.is_empty() else CUSTOM_TOPIC}

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

