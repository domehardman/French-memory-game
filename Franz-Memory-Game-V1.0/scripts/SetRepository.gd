extends Node

const VocabularySetResource = preload("res://scripts/VocabularySet.gd")
const SAVE_DIR := "user://vocab_sets"
var save_dir := SAVE_DIR
const EXAMPLE_PATH := "res://data/vocabulary.json"

func list_sets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var catalog := FileAccess.open("res://data/sets.json", FileAccess.READ)
	if catalog != null:
		var items = JSON.parse_string(catalog.get_as_text())
		if items is Array:
			for item in items:
				if item is Dictionary and item.has("name") and item.has("path"):
					var count := _read_entries(str(item["path"])).size()
					if count > 0:
						result.append({"name": str(item["name"]), "path": str(item["path"]), "count": count, "custom": str(item["path"]) != EXAMPLE_PATH})
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
					result.append({"name": str(data["name"]), "path": path, "count": data["entries"].size(), "custom": true})
		filename = directory.get_next()
	directory.list_dir_end()
	return result

func save_set(name: String, entries: Array[Dictionary]) -> Dictionary:
	var clean_name := name.strip_edges()
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
	resource.entries = entries.duplicate(true)
	var resource_error := ResourceSaver.save(resource, resource_path)
	if resource_error != OK:
		return {"error": "Die Godot-Resource konnte nicht gespeichert werden."}
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
		return {"error": "Die JSON-Datei konnte nicht gespeichert werden."}
	file.store_string(JSON.stringify({"name": clean_name, "entries": entries}, "  "))
	file.flush()
	file.close()
	return {"name": clean_name, "path": json_path, "resource_path": resource_path, "count": entries.size(), "custom": true}

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

