extends Node
## SaveManager — автозагрузка (Singleton). Сохранение/загрузка GameData и DayCycle.
## Хранит один JSON-файл в user://save.json. Работает одинаково на Web (HTML5)
## и Android: Godot проксирует user:// в IndexedDB/LocalStorage (web) и во
## внутреннее хранилище (Android).

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var _save_pending := false
var _dirty := false

func _ready() -> void:
	load_game()

# --- Публичный API -----------------------------------------------------------

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
	DayCycle.from_dict(data.get("day_cycle", {}))
	GameData.from_dict(data.get("game_data", {}))
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
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: сохранение повреждено, начинаем заново")
		return {}
	return parsed

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			save_now()
