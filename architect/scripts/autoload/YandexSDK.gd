extends Node
## YandexSDK — автозагрузка (Singleton). Скрипт-обёртка (stub) над Яндекс Games SDK.
##
## ВАЖНО (требование ТЗ): ВСЕ вызовы JavaScriptBridge строго обёрнуты в
## проверку web (`OS.has_feature("web")`). Вне web (редактор Godot, Android-отладка)
## отрабатывает безопасная заглушка: rewarded-реклама симулируется успешной через
## 2 секунды и callback вызывается, ошибок не возникает.

signal sdk_initialized
signal rewarded_ad_result(viewed: bool)

const STUB_AD_DELAY := 2.0  # сек., симуляция просмотра рекламы в редакторе/Android

var _initialized := false
var _ad_showing := false
var _is_web := false
var _js_callbacks := {}
var _next_callback_id := 1
var _global_registered := false

func _ready() -> void:
	_is_web = OS.has_feature("web")
	init()

# --- Публичный API -----------------------------------------------------------

func is_available() -> bool:
	## Реальный SDK доступен только внутри web-контейнера Яндекса.
	if not _is_web:
		return false
	var res = JavaScriptBridge.eval("(!!(window.__ysdk || window.__ysdkPromise));", false)
	return bool(res)

func init() -> void:
	if _initialized:
		return
	_initialized = true
	if _is_web:
		# Страница Яндекса сама подключает скрипт YaGames; мы асинхронно
		# инициализируем SDK и кэшируем промис в window.__ysdkPromise.
		_js_eval("""if (typeof YaGames !== 'undefined' && !window.__ysdkPromise) {
			window.__ysdkPromise = YaGames.init().then(function(ysdk) {
				window.__ysdk = ysdk;
				console.log('ysdk initialized');
				return ysdk;
			}).catch(function(e) {
				console.error('ysdk init failed', e);
				return null;
			});
		}""")
		print("YandexSDK[web]: init отправлен")
	else:
		print("YandexSDK[stub]: не-web окружение, используется заглушка")
	sdk_initialized.emit()

func notify_game_ready() -> void:
	## Сообщает Яндекс Game SDK, что игра загрузилась: ysdk.features.LoadingAPI.ready().
	## Обязателен для модерации: без него портал показывает экран «загрузки».
	if not _is_web:
		print("YandexSDK[stub]: notify_game_ready() — no-op вне web")
		return
	_js_eval("""function __ya_ready(ysdk) {
		if (ysdk && ysdk.features && ysdk.features.LoadingAPI) {
			ysdk.features.LoadingAPI.ready();
		}
	}
	if (window.__ysdk) {
		__ya_ready(window.__ysdk);
	} else if (window.__ysdkPromise) {
		window.__ysdkPromise.then(__ya_ready);
	} else if (typeof YaGames !== 'undefined') {
		YaGames.init().then(function(ysdk) {
			window.__ysdk = ysdk;
			__ya_ready(ysdk);
		}).catch(function() {});
	}""")
	print("YandexSDK[web]: LoadingAPI.ready() запрошен")

func show_rewarded_ad(callback: Callable = Callable()) -> void:
	## Показ rewarded-рекламы строго по желанию игрока (все точки в ТЗ — opt-in).
	## callback(viewed: bool) — получил ли игрок награду.
	if _ad_showing:
		push_warning("YandexSDK: реклама уже показывается, вызов пропущен")
		return
	_ad_showing = true
	if _is_web:
		var cb_id := _register_callback(callback)
		_js_eval("""function __ya_showRewarded(cbId) {
			var done = function(viewed) {
				if (typeof on_godot_cb === 'function') on_godot_cb(cbId, viewed);
			};
			var show = function(ysdk) {
				try {
					ysdk.adv.showRewardedVideo({
						callbacks: {
							onRewarded: function() {},
							onClosed: function() { done(true); },
							onError: function(e) {
								console.error('Rewarded error', e);
								done(false);
							}
						}
					});
				} catch (e) {
					console.error('Rewarded exception', e);
					done(false);
				}
			};
			if (window.__ysdk) {
				show(window.__ysdk);
			} else if (window.__ysdkPromise) {
				window.__ysdkPromise.then(function(ysdk) {
					if (ysdk) { show(ysdk); } else { done(false); }
				});
			} else {
				done(false);
			}
		}
		__ya_showRewarded(%d);""" % cb_id)
	else:
		# Безопасная заглушка (редактор/Android): симулируем успешный просмотр
		# через 2 секунды и вызываем callback — без единой ошибки.
		print("YandexSDK[stub]: симуляция rewarded-рекламы (%.1f сек)" % STUB_AD_DELAY)
		await get_tree().create_timer(STUB_AD_DELAY).timeout
		_finish_rewarded(true, callback)

# --- Внутреннее ---------------------------------------------------------------

func _finish_rewarded(viewed: bool, callback: Callable = Callable()) -> void:
	_ad_showing = false
	rewarded_ad_result.emit(viewed)
	if callback.is_valid():
		callback.call(viewed)

func _register_callback(callback: Callable) -> int:
	# Реестр id -> Callable. JS при завершении рекламы вызывает on_godot_cb(id, ok),
	# которая пробрасывает вызов в Godot-глобалку __godot_cb_pump.
	# Вызывается только из web-ветки show_rewarded_ad, но guard дублируем (требование ТЗ).
	if _is_web and not _global_registered:
		_global_registered = true
		JavaScriptBridge.eval("""window.on_godot_cb = function(id, ok) {
			if (typeof __godot_cb_pump === 'function') { __godot_cb_pump(id, ok); }
		};""")
		# Используем call(), чтобы парсер GDScript в editor/Android не падал на несуществующем методе
		JavaScriptBridge.call("register_global", "__godot_cb_pump", _on_js_callback)
	var id := _next_callback_id
	_next_callback_id += 1
	_js_callbacks[id] = callback
	return id

func _on_js_callback(cb_id: int, ok: bool) -> void:
	if not _js_callbacks.has(cb_id):
		return
	var callback: Callable = _js_callbacks[cb_id]
	_js_callbacks.erase(cb_id)
	_finish_rewarded(ok, callback)

func _js_eval(code: String) -> void:
	# Единственная точка выхода в JS — всегда под проверкой web.
	if _is_web:
		JavaScriptBridge.eval(code, true)
