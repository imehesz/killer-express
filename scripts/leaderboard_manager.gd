extends Node
## Persists top-15 high scores to user://leaderboard.json.
## Each entry: { "date": String, "score": int, "distance": int }

const SAVE_PATH := "user://leaderboard.json"
const MAX_ENTRIES := 15

var entries: Array = []  # [{date, score, distance}]

func _ready():
	_load()

func add_entry(score: int, distance_meters: int):
	var now = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d" % [now.year, now.month, now.day]
	var time_str = "%02d:%02d" % [now.hour, now.minute]
	entries.append({
		"date": "%s %s" % [date_str, time_str],
		"score": score,
		"distance": distance_meters,
	})
	# Sort descending by score, then keep top N
	entries.sort_custom(func(a, b): return a.score > b.score)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	_save()

func get_entries() -> Array:
	return entries

func _save():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(entries, "\t"))
		file.close()

func _load():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(text) == OK and json.data is Array:
			entries = json.data
