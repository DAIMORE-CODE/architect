extends Node
## DayCycle — автозагрузка (Singleton). Определяет «новый игровой день»
## и ведёт 7-дневный цикл ежедневной награды (ТЗ: пропуск дня сбрасывает прогресс).
## Даты храним как строку "YYYY-MM-DD" — локальный день игрока.

signal new_day(day_index: int)              # наступил новый день
signal daily_reward_state_changed           # можно/нельзя забрать награду сегодня

const DAILY_CYCLE_LENGTH := 7
const REWARD_COINS: Array[int] = [50, 50, 75, 75, 100, 100, 200]
const SEVENTH_DAY_CONSUMABLE: String = "polish"

var last_visit_date: String = ""            # последний визит (дата строкой)
var first_play_date: String = ""            # дата первого запуска (для day_index)
var daily_streak: int = 0                   # текущая позиция в 7-дневном цикле (0..6)
var reward_claimed_date: String = ""        # дата, когда уже забрали награду

func _ready() -> void:
	_check_new_day_on_start()

func _check_new_day_on_start() -> void:
	var today := _today()
	if first_play_date.is_empty():
		first_play_date = today
	_reset_streak_if_missed()
	if last_visit_date == today:
		return
	var is_first_install := last_visit_date.is_empty()
	last_visit_date = today
	if not is_first_install:
		new_day.emit(get_day_index())
	daily_reward_state_changed.emit()

func get_day_index() -> int:
	## Сколько дней прошлось с первого запуска (0 в день установки).
	return _days_between(first_play_date, _today())

func is_daily_reward_available() -> bool:
	return reward_claimed_date != _today()

func claim_daily_reward() -> bool:
	## Возвращает true, если награда реально выдана. Вызывать из DailyRewardScreen.
	if not is_daily_reward_available():
		return false
	var index := clampi(daily_streak, 0, DAILY_CYCLE_LENGTH - 1)
	GameData.add_coins(REWARD_COINS[index])
	if index == DAILY_CYCLE_LENGTH - 1:
		GameData.add_consumable(SEVENTH_DAY_CONSUMABLE)
	reward_claimed_date = _today()
	daily_streak = (index + 1) % DAILY_CYCLE_LENGTH
	daily_reward_state_changed.emit()
	SaveManager.request_save()
	return true

func get_today_index() -> int:
	## Индекс дня цикла (0..6), который показывается как «сегодня».
	## После получения награды это уже выданный день, а не следующий.
	if reward_claimed_date == _today():
		return (daily_streak - 1 + DAILY_CYCLE_LENGTH) % DAILY_CYCLE_LENGTH
	return daily_streak

func get_current_cycle_day() -> int:
	## День в 7-дневном цикле (1..7) для текущего состояния.
	return get_today_index() + 1

# --- Сериализация -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"last_visit_date": last_visit_date,
		"first_play_date": first_play_date,
		"daily_streak": daily_streak,
		"reward_claimed_date": reward_claimed_date,
	}

func from_dict(data: Dictionary) -> void:
	first_play_date = str(data.get("first_play_date", ""))
	last_visit_date = str(data.get("last_visit_date", ""))
	daily_streak = int(data.get("daily_streak", 0))
	reward_claimed_date = str(data.get("reward_claimed_date", ""))
	_reset_streak_if_missed()
	# После загрузки перепроверяем: возможно игрок пришёл на следующий день.
	_check_new_day_on_start()

# --- Внутреннее -----------------------------------------------------------------

func _reset_streak_if_missed() -> void:
	## Пропуск дня: награда не забрана ни сегодня, ни вчера — цикл начинается заново.
	var today := _today()
	if reward_claimed_date != today and reward_claimed_date != _yesterday_of(today):
		daily_streak = 0

func _today() -> String:
	return Time.get_date_string_from_system(true)

func _yesterday_of(date_string: String) -> String:
	var d := Time.get_datetime_dict_from_unix_time(_date_to_unix(date_string) - 86400)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _date_to_unix(date_string: String) -> int:
	if date_string.length() < 10:
		return int(Time.get_unix_time_from_system())
	var parts := date_string.split("-")
	var dt := {
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 12, "minute": 0, "second": 0,
	}
	return int(Time.get_unix_time_from_datetime_dict(dt))

func _days_between(from_date: String, to_date: String) -> int:
	if from_date.is_empty():
		return 0
	var diff := _date_to_unix(to_date) - _date_to_unix(from_date)
	return int(floor(diff / 86400.0))
