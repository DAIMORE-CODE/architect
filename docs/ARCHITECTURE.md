# Архитектура проекта

## Расположение
- Корень git-репозитория: `D:\Godot project\architect\` (содержит `AGENTS.md`, `docs/`, `.git`)
- Проект Godot: `architect\architect\` (содержит `project.godot`, `scenes/`, `scripts/`, `assets/`)
- Пути `res://` идут от папки с `project.godot`.

## Структура (`res://`)
```
res://
├── scenes/
│   ├── Main.tscn              — корневая сцена, роутер экранов
│   ├── screens/HubScreen.tscn
│   ├── gameplay/CleanStage.tscn
│   ├── gameplay/AssemblyStage.tscn
│   └── ui/HUD_TopBar.tscn
├── scripts/
│   ├── Main.gd
│   ├── autoload/  (GameData, SaveManager, YandexSDK, DayCycle)
│   ├── screens/   (HubScreen.gd)
│   ├── gameplay/  (CleanStage.gd, AssemblyStage.gd)
│   └── ui/        (HUD_TopBar.gd)
├── assets/
│   └── items/     (watch_clean.png, watch_dirt.png + .import)
└── project.godot
```

## Autoload-синглтоны (`project.godot` → `[autoload]`)
| Имя | Скрипт | Роль |
|---|---|---|
| `GameData` | `scripts/autoload/GameData.gd` | Монеты, энергия; сигналы изменения для UI |
| `SaveManager` | `scripts/autoload/SaveManager.gd` | Сохранение/загрузка (JSON, user://) |
| `YandexSDK` | `scripts/autoload/YandexSDK.gd` | Обёртка Яндекс SDK; в редакторе — заглушка; `notify_game_ready()` |
| `DayCycle` | `scripts/autoload/DayCycle.gd` | Дата, ежедневная награда, красная точка |

## Роутинг
- `Main.tscn` / `Main.gd` — единственная точка смены экранов. Загружает экран по сигналу (например, `clean_requested` из HubScreen → CleanStage).
- Сессия: Hub → CleanStage (`stage_finished` → `_route_to_assembly()`) → AssemblyStage (`stage_finished` → экран рейтинга, пока заглушка; `back_requested` → Hub).
- При смене экрана предыдущий экран освобождается (`queue_free`), чтобы не было утечек (исправлено в коммите `f3b62b8`).

## Принятые паттерны
- **UI:** только `Control`-наследники; `MarginContainer` + `VBoxContainer`/`HBoxContainer`; якоря через `anchors_preset`, `size_flags`.
- **Сигналы:** подписка в `_enter_tree()`, отписка в `_exit_tree()`, перед `connect()` — проверка `is_connected()`.
- **Сигналы UI ← данные:** HUD_TopBar подписан на сигналы `GameData`.
- **Web-вызовы:** все `JavaScriptBridge` внутри `if OS.has_feature("web"):`; в редакторе — заглушка.
- **Типизация:** `var x: int`, `func foo() -> void`; отступы только табами.
- **Очистка (CleanStage):**
  - `TextureRect` с двумя слоями (чистый + грязный).
  - Стирание через `Image` (альфа-канал) → `ImageTexture.create_from_image()` / `update()`; обновление текстуры батчится (~30 Гц).
  - Координаты: `get_global_transform().affine_inverse()` (у `Control` нет `to_local()`) → масштабирование под размер изображения.
  - Ввод: ЛКМ (`button_mask & MOUSE_BUTTON_MASK_LEFT`), тач (`ScreenTouch`/`ScreenDrag`), мышиный drag.
  - Интерполяция между точками свайпа — Bresenham.
  - Прогресс — подсчёт реально стёртых пикселей, порог 95% (D-013). Сигнал `stage_finished`.
- **Сборка (AssemblyStage):**
  - Корень `Control`; 4 детали (`ColorRect`) из константы `PARTS`, слоты-подсказки с альфой 0.25.
  - Раскладка только в долях `WorkArea.size` в `_layout()` (вызов по `resized` и при старте); лоток — нижние 30%.
  - Ввод: ЛКМ и тач; один активный указатель `_active_pointer` (мышь = -1, тач = `index`). Перемещение и отпускание — в `_input`; нажатие — по сигналу `gui_input` детали.
  - Защёлкивание в свой слот при расстоянии до центра ≤ `SNAP_RATIO * min(size)`; промах → `misses += 1` и возврат в лоток (Tween, 0.2 с, ввод блокируется).
  - Прогресс `placed / total`; `stage_finished(1.0)` эмитится один раз, после этого ввода нет. `back_requested` → Hub.
- **Рендерер:** Mobile; физика Jolt (3D не используется).

## Ограничения
- Git: агент не выполняет `commit`/`push` без явной команды PM.
- `.godot/` создаётся Godot автоматически, в `.gitignore`, в Git не коммитится (см. `AGENTS.md`).
