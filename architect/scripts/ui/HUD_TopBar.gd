extends HBoxContainer
## HUD_TopBar — переиспользуемый компонент верхней панели (монеты + энергия).
## Встраивается в HubScreen как отдельная сцена (instances). Отображает данные
## из автозагрузки GameData и подписывается на её сигналы, поэтому значение
## обновляется мгновенно при любой покупке/награде/трате энергии.

@export var lbl_coins: Label
@export var lbl_energy: Label

func _ready() -> void:
	if lbl_coins == null:
		lbl_coins = get_node_or_null("CoinsBox/CoinsLabel") as Label
	if lbl_energy == null:
		lbl_energy = get_node_or_null("EnergyBox/EnergyLabel") as Label
	GameData.coins_changed.connect(_on_coins_changed)
	GameData.energy_changed.connect(_on_energy_changed)
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
