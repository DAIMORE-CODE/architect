extends Node
## SaveManager — автозагрузка (Singleton). Сохранение/загрузка GameData и DayCycle.
## Хранит один JSON-файл в user://save.json. Работает одинаково на Web (HTML5)
## и Android: Godot проксирует user:// в IndexedDB/LocalStorage (web) и во
## внутреннее хранилище (Android).

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

const DEFAULT_SETTINGS := {"sfx_volume": 100, "music_volume": 100, "vibration": true, "music_enabled": true}
const TUTORIAL_KEYS: Array[String] = ["tutorial_clean", "tutorial_assembly", "tutorial_polish"]

var _save_pending := false
var _dirty := false
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## Первая завершённая сессия проходит с подсказками (Шаг 7c, фаза 5).
var onboarding_done := false
var _tutorials_seen: Dictionary = {}

func _ready() -> void:
	load_game()

# --- Публичный API -----------------------------------------------------------

func get_setting(key: String) -> Variant:
	return _settings.get(key, DEFAULT_SETTINGS.get(key))

func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	request_save()

func is_tutorial_seen(key: String) -> bool:
	return bool(_tutorials_seen.get(key, false))

func mark_tutorial_seen(key: String) -> void:
	if not TUTORIAL_KEYS.has(key) or is_tutorial_seen(key):
		return
	_tutorials_seen[key] = true
	request_save()

func request_save() -> void:
	# Отложенное сохранение: несколько изменений за кадр -> одна запись файла.
	_dirty = true
	if not _save_pending:
		_save_pending = true
		call_deferred("_do_save")

func save_now() -> void:
	_do_save()

func load_game() -> void:
	var data := _read_file()
	if data.is_empty():
		print("SaveManager: сохранение не найдено, игра стартует с дефолтных данных")
		return
	GameData.from_dict(data.get("game_data", {}))
	DayCycle.from_dict(data.get("day_cycle", {}))
	var saved_settings: Variant = data.get("settings", {})
	if typeof(saved_settings) == TYPE_DICTIONARY:
		for key in DEFAULT_SETTINGS:
			if saved_settings.has(key):
				_settings[key] = saved_settings[key]
	onboarding_done = bool(data.get("onboarding_done", false))
	var saved_tutorials: Variant = data.get("tutorials", {})
	if typeof(saved_tutorials) == TYPE_DICTIONARY:
		_tutorials_seen = saved_tutorials
	print("SaveManager: сохранение загружено (v%s)" % str(data.get("version", "?")))

func wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

# --- Внутреннее ---------------------------------------------------------------

func _do_save() -> void:
	_save_pending = false
	if not _dirty:
		return
	_dirty = false
	var data := {
		"version": SAVE_VERSION,
		"day_cycle": DayCycle.to_dict(),
		"game_data": GameData.to_dict(),
		"settings": _settings,
		"onboarding_done": onboarding_done,
		"tutorials": _tutorials_seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: не удалось открыть файл для записи: %s (%s)"
			% [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _read_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("SaveManager: не удалось прочитать сохранение")
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: сохранение повреждено (err=%s), начинаем заново" % error_string(err))
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
		return {}
	return json.data

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			save_now()
