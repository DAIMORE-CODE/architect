extends Node
## YandexSDK — автозагрузка (Singleton). Скрипт-обёртка (stub) над Яндекс Games SDK.
##
## ВАЖНО (требование ТЗ): ВСЕ вызовы JavaScriptBridge строго обёрнуты в
## проверку web (`OS.has_feature("web")`). В редакторе отрабатывает безопасная
## заглушка: rewarded-реклама симулируется успешной через 2 секунды.
## На Android реклама идёт через плагин GodotAndroidYandexAds (Yandex Mobile Ads);
## без ANDROID_REWARDED_ID реклама не показывается и награда не выдаётся.

signal sdk_initialized
signal rewarded_ad_result(viewed: bool)

const STUB_AD_DELAY := 2.0  # сек., симуляция просмотра рекламы в редакторе
const ANDROID_REWARDED_ID := ""  # ID rewarded-блока Yandex Mobile Ads (заполняет PM)
const ANDROID_LOAD_TIMEOUT := 15.0  # сек., защита от зависания при загрузке рекламы
const YandexAdsScript = preload("res://addons/GodotAndroidYandexAds/yandex_ads.gd")

var _initialized := false
var _ad_showing := false
var _is_web := false
var _is_android := false
var _js_callbacks := {}
var _next_callback_id := 1
var _global_registered := false

var _android_ads: YandexAdsScript = null
var _android_active := false
var _android_loading := false
var _android_granted := false
var _android_callback := Callable()
var _android_request_id := 0

func _ready() -> void:
	_is_web = OS.has_feature("web")
	_is_android = OS.get_name() == "Android"
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
	elif _is_android:
		_setup_android_ads()
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
	elif _is_android:
		_show_android_rewarded(callback)
	else:
		# Безопасная заглушка (редактор): симулируем успешный просмотр
		# через 2 секунды и вызываем callback — без единой ошибки.
		print("YandexSDK[stub]: симуляция rewarded-рекламы (%.1f сек)" % STUB_AD_DELAY)
		await get_tree().create_timer(STUB_AD_DELAY).timeout
		_finish_rewarded(true, callback)

# --- Android (плагин GodotAndroidYandexAds) -----------------------------------

func _setup_android_ads() -> void:
	if ANDROID_REWARDED_ID.is_empty():
		push_warning("YandexSDK: ANDROID_REWARDED_ID не задан, rewarded-реклама отключена")
		return
	if not Engine.has_singleton("GodotAndroidYandexAds"):
		push_warning("YandexSDK: Android-плагин GodotAndroidYandexAds не загружен")
		return
	var ads: YandexAdsScript = YandexAdsScript.new()
	ads.rewarded_id = ANDROID_REWARDED_ID
	ads.rewarded.connect(_on_android_rewarded)
	ads.rewarded_video_loaded.connect(_on_android_loaded)
	ads.rewarded_video_failed_to_load.connect(_on_android_failed_to_load)
	ads.rewarded_video_closed.connect(_on_android_closed)
	add_child(ads)
	_android_ads = ads
	_android_ads.load_rewarded_video()

func _show_android_rewarded(callback: Callable) -> void:
	if ANDROID_REWARDED_ID.is_empty():
		push_warning("YandexSDK: ANDROID_REWARDED_ID не задан, награда не выдана")
		_finish_rewarded(false, callback)
		return
	if _android_ads == null:
		push_warning("YandexSDK: плагин рекламы не загружен, награда не выдана")
		_finish_rewarded(false, callback)
		return
	_android_active = true
	_android_granted = false
	_android_callback = callback
	_android_request_id += 1
	if _android_ads.is_rewarded_video_loaded():
		_android_loading = false
		_android_ads.show_rewarded_video()
	else:
		_android_loading = true
		_android_ads.load_rewarded_video()
		_start_android_load_timeout(_android_request_id)

func _start_android_load_timeout(request_id: int) -> void:
	await get_tree().create_timer(ANDROID_LOAD_TIMEOUT).timeout
	if _android_active and _android_loading and request_id == _android_request_id:
		push_warning("YandexSDK: таймаут загрузки rewarded-рекламы")
		_finish_android(false)

func _on_android_loaded() -> void:
	if _android_active and _android_loading:
		_android_loading = false
		_android_ads.show_rewarded_video()

func _on_android_failed_to_load(error_code: int) -> void:
	if _android_active and _android_loading:
		push_warning("YandexSDK: rewarded не загрузился, код ошибки %d" % error_code)
		_finish_android(false)

func _on_android_rewarded(_currency: String, _amount: int) -> void:
	if _android_active:
		_android_granted = true

func _on_android_closed() -> void:
	if _android_active:
		_finish_android(_android_granted)

func _finish_android(viewed: bool) -> void:
	var callback := _android_callback
	_android_active = false
	_android_loading = false
	_android_granted = false
	_android_callback = Callable()
	_android_request_id += 1
	_finish_rewarded(viewed, callback)
	_android_ads.load_rewarded_video()

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
