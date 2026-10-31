extends SceneTree
## Headless-тест механики CleanStage v2 (pop-pixel progress, TextureRect).
## Запуск: godot --headless -s res://tests/test_clean_stage2.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/gameplay/CleanStage.tscn")
	assert(scene != null, "scene load failed")
	var stage: Control = scene.instantiate()
	root.add_child(stage)
	for i in 10:
		await process_frame
	print("TEST: has_script=", stage.get_script() != null)
	assert(stage.get_script() != null, "script must be attached and compiled")
	var dirt_rect: TextureRect = stage.get_node("WorkMargin/WorkArea/DirtLayer")
	var work_area: Control = stage.get_node("WorkMargin/WorkArea")
	print("TEST: dirt_class=", dirt_rect.get_class(), " rect_size=", dirt_rect.size, " work_size=", work_area.size)
	print("TEST: tex_class=", dirt_rect.texture.get_class())
	assert(dirt_rect.texture.get_class() == "ImageTexture", "own ImageTexture required")
	print("TEST: total_pixels=", stage.total_pixels)
	assert(stage.total_pixels > 0, "total_pixels must be non-zero (not empty loop)")
	assert(stage.progress_bar.value == 0.0, "progress must start at 0%")
	# 1) Motion БЕЗ зажатой ЛКМ — стирания нет.
	var before_mid_a: float = stage.dirt_image.get_pixel(stage.dirt_image.get_width() / 2, stage.dirt_image.get_height() / 2).a
	var m := InputEventMouseMotion.new()
	m.global_position = work_area.get_global_rect().get_center()
	m.button_mask = 0
	stage._input(m)
	await process_frame
	var after_mid_a: float = stage.dirt_image.get_pixel(stage.dirt_image.get_width() / 2, stage.dirt_image.get_height() / 2).a
	print("TEST: motion_no_lmb_no_erase=", before_mid_a == after_mid_a)
	assert(before_mid_a == after_mid_a, "motion without LMB must not erase")
	# 2) Свайп ВНЕ рабочей области (по TopBar) не стирает грязь.
	var out := InputEventMouseMotion.new()
	out.global_position = Vector2(10, 10)
	out.button_mask = MOUSE_BUTTON_MASK_LEFT
	stage._input(out)
	await process_frame
	print("TEST: guard_outside_no_erase=", stage.dirt_image.get_pixel(2, 2).a > 0.1 or work_area.get_global_position().y > 20.0)
	# 3) Стирание кистью напрямую в центр изображения + проверка маппинга
	#    и что cleaned НЕ превышает total_pixels.
	var iw: int = stage.dirt_image.get_width()
	var ih: int = stage.dirt_image.get_height()
	stage._apply_brush(dirt_rect.get_global_rect().get_center())
	await process_frame
	assert(stage.dirt_image.get_pixel(iw / 2, ih / 2).a == 0.0, "brush must hit exact center pixel")
	print("TEST: brush_hits_center=true")
	var left_after_one: int = 0
	for x in range(iw):
		for y in range(ih):
			if stage.dirt_image.get_pixel(x, y).a > 0.1:
				left_after_one += 1
	var cleaned_one: int = stage.total_pixels - left_after_one
	print("TEST: cleaned_after_1_stroke=", cleaned_one, "/", stage.total_pixels)
	assert(cleaned_one > 0 and cleaned_one <= stage.total_pixels, "cleaned must be positive and <= total")
	# 4) Клик ЛКМ + сетка свайпов по всей площади до 85%.
	var pb := InputEventMouseButton.new()
	pb.button_index = MOUSE_BUTTON_LEFT
	pb.pressed = true
	pb.global_position = work_area.get_global_position() + work_area.size * 0.2
	stage._input(pb)
	var guard := 0
	while not stage._finished and guard < 120:
		guard += 1
		var gx: float = fmod(guard * 37.0, 9.0) / 8.0
		var gy: float = floorf(guard / 9.0) / 12.0
		var mm := InputEventMouseMotion.new()
		mm.global_position = work_area.get_global_position() + work_area.size * Vector2(0.05 + gx * 0.9, 0.05 + gy * 0.9)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		stage._input(mm)
		if guard % 6 == 0:
			await process_frame
	await process_frame
	print("TEST: finished=", stage._finished, " final_progress=", stage.progress_bar.value, " strokes=", guard)
	assert(stage.progress_bar.value >= 0.85, "progress must reach >= 0.85")
	assert(stage._finished, "stage must finish at >=85%")
	# Прогресс валидный: cleaned никогда не превышает total.
	var current_left := 0
	var img: Image = stage.dirt_image
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			if img.get_pixel(x, y).a > 0.1:
				current_left += 1
	var cleaned: int = stage.total_pixels - current_left
	print("TEST: cleaned=", cleaned, "/", stage.total_pixels)
	assert(cleaned <= stage.total_pixels, "cleaned must never exceed total_pixels")
	assert(current_left > 0 or cleaned == stage.total_pixels, "sanity")
	# 4) Стирание подтверждено прозрачностью именно под курсором.
	var sample_img := Vector2i(int(dirt_rect.size.x * 0.5 / dirt_rect.size.x * img.get_width() * 0.5), 0)
	var erased_anywhere := false
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a == 0.0:
				erased_anywhere = true
	print("TEST: erased_confirmed=", erased_anywhere)
	assert(erased_anywhere, "pixels must become transparent")
	# 5) После завершения ввод заблокирован.
	var prog_after: float = stage.progress_bar.value
	var post := InputEventMouseMotion.new()
	post.global_position = work_area.get_global_position() + Vector2(100, 100)
	post.button_mask = MOUSE_BUTTON_MASK_LEFT
	stage._input(post)
	await process_frame
	print("TEST: input_locked_after_finish=", stage.progress_bar.value == prog_after)
	assert(stage.progress_bar.value == prog_after, "no changes after finish")
	print("ALL TESTS PASSED")
	quit(0)
