extends Node
## Spielfortschritt: Punkte (XP), Level, Belohnungen, Kampagne, Bestzeiten.
## Alles wird in user://progress.json gespeichert und beim Start wieder geladen.
## Regeln, Belohnungen und Kampagnen-Level stehen in data/*.json.

const SAVE_PATH := "user://progress.json"
const RULES_PATH := "res://data/progression.json"
const REWARDS_PATH := "res://data/rewards.json"
const CAMPAIGN_PATH := "res://data/campaign.json"

var save_path := SAVE_PATH
var data: Dictionary = {}
var rules: Dictionary = {}
var rewards: Array = []
var campaign: Array = []

func _ready() -> void:
	rules = _read_json(RULES_PATH, {})
	rewards = _read_json(REWARDS_PATH, [])
	campaign = _read_json(CAMPAIGN_PATH, [])
	load_progress()

func _read_json(path: String, fallback: Variant) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == typeof(fallback):
		return parsed
	return fallback

func _default_data() -> Dictionary:
	return {
		"version": 1,
		"xp": 0,
		"games_played": 0,
		"total_pairs": 0,
		"total_time": 0.0,
		"best_streak": 0,
		"rewards": [],
		"topics_played": [],
		"campaign": {},
		"sets": {}
	}

# --- Speichern / Laden -------------------------------------------------------

func load_progress() -> void:
	data = _default_data()
	var loaded: Dictionary = _read_json(save_path, {})
	for key in loaded:
		data[key] = loaded[key]

func save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Fortschritt konnte nicht gespeichert werden: " + save_path)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true

func reset_progress() -> void:
	data = _default_data()
	save_progress()

func stat(key: String) -> int:
	return int(data.get(key, 0))

func rule(key: String, fallback: float) -> float:
	return float(rules.get(key, fallback))

# --- Level --------------------------------------------------------------------

func xp() -> int:
	return stat("xp")

func level_for_xp(points: int) -> int:
	var table: Array = rules.get("level_xp", [0, 100])
	var last := int(table[-1])
	if points >= last:
		return table.size() + floori(float(points - last) / rule("level_xp_after", 1000))
	var result := 1
	for i in range(1, table.size()):
		if points >= int(table[i]):
			result = i + 1
	return result

func xp_for_level(target_level: int) -> int:
	var table: Array = rules.get("level_xp", [0, 100])
	if target_level <= table.size():
		return int(table[maxi(target_level - 1, 0)])
	return int(table[-1]) + (target_level - table.size()) * int(rule("level_xp_after", 1000))

func level() -> int:
	return level_for_xp(xp())

# Für Fortschrittsbalken: wie viele Punkte im aktuellen Level schon gesammelt sind.
func level_info() -> Dictionary:
	var current_level := level()
	var start := xp_for_level(current_level)
	var next := xp_for_level(current_level + 1)
	return {"level": current_level, "xp": xp(), "current": xp() - start, "needed": next - start}

# --- Sterne und Punkte --------------------------------------------------------

func stars_for(won: bool, attempts: int, pairs: int) -> int:
	if not won or pairs <= 0:
		return 0
	var per_pair := float(attempts) / float(pairs)
	if per_pair <= rule("three_star_attempts_per_pair", 1.75):
		return 3
	if per_pair <= rule("two_star_attempts_per_pair", 2.5):
		return 2
	return 1

func points_for_match(streak: int) -> int:
	return int(rule("points_per_pair", 10)) + int(rule("streak_bonus", 5)) * maxi(streak - 1, 0)

func time_bonus(pairs: int, seconds: float) -> int:
	return maxi(0, int(pairs * rule("par_seconds_per_pair", 8) - seconds))

# --- Kampagne -----------------------------------------------------------------

func campaign_level(index: int) -> Dictionary:
	if index < 0 or index >= campaign.size():
		return {}
	return campaign[index]

func campaign_record(index: int) -> Dictionary:
	var level_data := campaign_level(index)
	if level_data.is_empty():
		return {}
	return data["campaign"].get(str(level_data.get("id", index)), {})

func campaign_stars(index: int) -> int:
	return int(campaign_record(index).get("stars", 0))

func campaign_unlocked(index: int) -> bool:
	return index == 0 or campaign_stars(index - 1) > 0

func campaign_completed_count() -> int:
	var count := 0
	for i in range(campaign.size()):
		if campaign_stars(i) > 0:
			count += 1
	return count

# --- Bestzeiten pro Set (freies Spiel) ----------------------------------------

func set_record(path: String) -> Dictionary:
	return data["sets"].get(path, {})

# --- Ein Spiel auswerten ------------------------------------------------------
# result: set_path, topic, custom, mode ("free"/"campaign"), campaign_index,
#         won, pairs_found, total_pairs, attempts, time, best_streak, points, stars
# Rückgabe: was sich geändert hat (für den Endbildschirm).
func record_game(result: Dictionary) -> Dictionary:
	var level_before := level()
	var won := bool(result.get("won", false))
	var seconds := float(result.get("time", 0.0))
	var attempts := int(result.get("attempts", 0))
	var summary := {
		"points": int(result.get("points", 0)),
		"level_before": level_before,
		"new_best_time": false,
		"unlocked_next": false,
		"new_rewards": []
	}
	data["xp"] = xp() + int(result.get("points", 0))
	data["games_played"] = stat("games_played") + 1
	data["total_pairs"] = stat("total_pairs") + int(result.get("pairs_found", 0))
	data["total_time"] = float(data.get("total_time", 0.0)) + seconds
	data["best_streak"] = maxi(stat("best_streak"), int(result.get("best_streak", 0)))

	var topic := str(result.get("topic", ""))
	if won and not bool(result.get("custom", false)) and not topic.is_empty() and not data["topics_played"].has(topic):
		data["topics_played"].append(topic)

	if str(result.get("mode", "free")) == "campaign":
		var index := int(result.get("campaign_index", -1))
		var level_data := campaign_level(index)
		if not level_data.is_empty():
			var was_unlocked := campaign_unlocked(index + 1)
			var record := campaign_record(index).duplicate()
			if won:
				record["stars"] = maxi(int(record.get("stars", 0)), int(result.get("stars", 0)))
				if record.has("best_time") and seconds < float(record["best_time"]):
					summary["new_best_time"] = true
				if not record.has("best_time") or seconds < float(record["best_time"]):
					record["best_time"] = seconds
			record["plays"] = int(record.get("plays", 0)) + 1
			data["campaign"][str(level_data.get("id", index))] = record
			summary["unlocked_next"] = index + 1 < campaign.size() and not was_unlocked and campaign_unlocked(index + 1)
	else:
		var path := str(result.get("set_path", ""))
		var record := set_record(path).duplicate()
		record["plays"] = int(record.get("plays", 0)) + 1
		if won:
			if record.has("best_time") and seconds < float(record["best_time"]):
				summary["new_best_time"] = true
			if not record.has("best_time") or seconds < float(record["best_time"]):
				record["best_time"] = seconds
			if not record.has("best_attempts") or attempts < int(record["best_attempts"]):
				record["best_attempts"] = attempts
		data["sets"][path] = record

	summary["new_rewards"] = _unlock_rewards(result)
	summary["level_after"] = level()
	save_progress()
	return summary

func has_reward(id: String) -> bool:
	return data["rewards"].has(id)

func _unlock_rewards(result: Dictionary) -> Array:
	var unlocked: Array = []
	for reward in rewards:
		if not reward is Dictionary:
			continue
		var id := str(reward.get("id", ""))
		if id.is_empty() or has_reward(id):
			continue
		if _reward_reached(reward, result):
			data["rewards"].append(id)
			unlocked.append(reward)
	return unlocked

func _reward_reached(reward: Dictionary, result: Dictionary) -> bool:
	var value := float(reward.get("value", 0))
	var won := bool(result.get("won", false))
	var pairs := int(result.get("total_pairs", 0))
	var enough_pairs := pairs >= int(reward.get("min_pairs", 1))
	match str(reward.get("type", "")):
		"games_played":
			return stat("games_played") >= value
		"total_pairs":
			return stat("total_pairs") >= value
		"streak":
			return stat("best_streak") >= value
		"level":
			return level() >= value
		"topics":
			return data["topics_played"].size() >= value
		"campaign":
			return campaign_completed_count() >= value
		"accuracy":
			return won and enough_pairs and float(result.get("attempts", 0)) <= pairs * value
		"speed":
			return won and enough_pairs and float(result.get("time", 0.0)) <= pairs * value
		"boss":
			return won and bool(result.get("final_boss", false))
		"boss_hp":
			return won and bool(result.get("final_boss", false)) and float(result.get("player_hp_ratio", 0.0)) > value
		"minibosses":
			return minibosses_defeated() >= value
	return false

# --- Admin-Werkzeuge ----------------------------------------------------------

func admin_unlock_campaign() -> void:
	for i in range(campaign.size()):
		if campaign_stars(i) == 0:
			var record := campaign_record(i).duplicate()
			record["stars"] = 1
			data["campaign"][str(campaign[i].get("id", i))] = record
	save_progress()

func admin_max_stars() -> void:
	for i in range(campaign.size()):
		var record := campaign_record(i).duplicate()
		record["stars"] = 3
		data["campaign"][str(campaign[i].get("id", i))] = record
	save_progress()

func admin_reset_campaign() -> void:
	data["campaign"] = {}
	save_progress()

func admin_add_xp(amount: int) -> void:
	data["xp"] = maxi(0, xp() + amount)
	save_progress()

func admin_unlock_rewards() -> void:
	var ids: Array = []
	for reward in rewards:
		ids.append(str(reward.get("id", "")))
	data["rewards"] = ids
	save_progress()

func admin_lock_rewards() -> void:
	data["rewards"] = []
	save_progress()

# Index des Endbosses ("final": true).
func boss_index() -> int:
	for i in range(campaign.size()):
		if str(campaign[i].get("type", "")) == "boss" and bool(campaign[i].get("final", false)):
			return i
	return -1

func is_boss_level(index: int) -> bool:
	return str(campaign_level(index).get("type", "")) == "boss"

func minibosses_defeated() -> int:
	var count := 0
	for i in range(campaign.size()):
		if is_boss_level(i) and not bool(campaign[i].get("final", false)) and campaign_stars(i) > 0:
			count += 1
	return count
