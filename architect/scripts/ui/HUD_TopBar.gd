extends HBoxContainer
## HUD_TopBar — переиспользуемый компонент верхней панели (монеты + энергия).
## Единственный источник истины для отображения GameData.coins / энергии:
## сам подписывается на сигналы GameData. Экраны НЕ должны менять эти лейблы.
## Жизненный цикл сигналов: подписка в _enter_tree(), отписка в _exit_tree().

# --- Привязка узлов (явные пути, @onready вместо @export) -------------------

@onready var lbl_coins: Label = $CoinsBox/CoinsLabel
@onready var lbl_energy: Label = $EnergyBox/EnergyLabel

func _enter_tree() -> void:
	GameData.coins_changed.connect(_on_coins_changed)
	GameData.energy_changed.connect(_on_energy_changed)

func _exit_tree() -> void:
	if GameData.coins_changed.is_connected(_on_coins_changed):
		GameData.coins_changed.disconnect(_on_coins_changed)
	if GameData.energy_changed.is_connected(_on_energy_changed):
		GameData.energy_changed.disconnect(_on_energy_changed)

func _ready() -> void:
	_refresh(GameData.coins, GameData.energy_current, GameData.MAX_ENERGY_PER_DAY)

func _on_coins_changed(new_amount: int) -> void:
	if lbl_coins != null:
		lbl_coins.text = str(new_amount)

func _on_energy_changed(current: int, maximum: int) -> void:
	_refresh(GameData.coins, current, maximum)

func _refresh(coins: int, energy: int, energy_max: int) -> void:
	if lbl_coins != null:
		lbl_coins.text = str(coins)
	if lbl_energy != null:
		lbl_energy.text = "%d/%d" % [energy, energy_max]
