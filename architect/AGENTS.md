# Правила для AI-агента разработчика

## 🚨 КРИТИЧЕСКИЕ ПРАВИЛА (нарушение = провал задачи)

1. **Git-честность**: Никогда не пиши "git commit выполнен" или "push успешен", если ты не получил реальный вывод терминала с подтверждением. Если команда упала с ошибкой — напиши текст ошибки ПРЯМЫМ ТЕКСТОМ.

2. **Файловая система**: 
   - НИКОГДА не читай/изменяй папку `.godot/` или файл `.gitignore`
   - Скрипты (`.gd`) → `res://scripts/`
   - Сцены (`.tscn`) → `res://scenes/`
   - Ресурсы → `res://assets/`

3. **Форматирование**: Только табы (Tabs), никаких пробелов. Строгая типизация (`var x: int`, `func foo() -> void`).

4. **UI-узлы**: Для интерфейса используй ТОЛЬКО `Control`-наследники (Button, Label, VBoxContainer и т.д.). Никаких `Node2D`/`Sprite2D` для UI.

5. **Адаптивность**: Все UI-элементы должны использовать `anchors_preset` и `size_flags` для корректного отображения на разных экранах.

6. **Сигналы**: Подписка в `_enter_tree()`, отписка в `_exit_tree()`. Используй `is_connected()` перед `connect()`.

7. **Яндекс SDK**: Все вызовы `JavaScriptBridge` обернуты в `if OS.has_feature("web"):`. В редакторе — безопасная заглушка.

8. **Рабочий процесс**: После выполнения задачи напиши: "✅ Код написан, закоммичен и запушен. Ожидаю апрува от AI-Ревьюера перед передачей на тестирование." НЕ предлагай тестировать в Godot до прохождения ревью.

## 📁 Структура проекта
res://
├── scenes/
│ ├── screens/ (HubScreen, MuseumScreen, ShopScreen, DailyRewardScreen)
│ ├── gameplay/ (CleanStage, AssemblyStage, PolishStage, RestoreSession)
│ └── ui/ (HUD_TopBar, ResultScreen)
├── scripts/
│ ├── autoload/ (GameData, SaveManager, YandexSDK, DayCycle)
│ ├── screens/
│ ├── gameplay/
│ └── ui/
├── assets/
│ └── items/ (watch_clean.png, watch_dirt.png, и т.д.)
└── project.godot
