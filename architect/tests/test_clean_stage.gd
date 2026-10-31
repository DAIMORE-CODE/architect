extends SceneTree
## Headless-тест механики CleanStage (запуск: godot --headless -s res://tests/test_clean_stage.gd)

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/gameplay/CleanStage.tscn")
	assert(scene != null, "scene load failed")
	var stage: Control = scene.instantiate()
	root.add_child(stage)
	for i in 10:
		await process_frame
	print("TEST: has_script=", stage.get_script() != null)
	var dirt_rect: TextureRect = stage.get_node("WorkMargin/WorkArea/DirtLayer")
	var work_area: Control = stage.get_node("WorkMargin/WorkArea")
	print("TEST: dirt_class=", dirt_rect.get_class(), " rect_size=", dirt_rect.size, " work_size=", work_area.size)
	print("TEST: tex_class=", dirt_rect.texture.get_class())
	# 1) Motion БЕЗ зажатой ЛКМ — прогресс не двигается.
	var m := InputEventMouseMotion.new()
	m.global_position = work_area.get_global_rect().get_center()
	m.button_mask = 0
	stage._input(m)
	await process_frame
	print("TEST: hits_after_motion_no_lmb=", stage._brush_hits)
	assert(stage._brush_hits == 0, "motion without LMB must not erase")
	# 2) Клик ЛКМ внутри области + свайп — стирание идёт.
	var p := InputEventMouseButton.new()
	p.button_index = MOUSE_BUTTON_LEFT
	p.pressed = true
	p.global_position = work_area.get_global_position() + work_area.size * 0.3
	stage._input(p)
	for i in 60:
		var mm := InputEventMouseMotion.new()
		mm.global_position = work_area.get_global_position() + Vector2(50 + i * 4.0, 60 + i * 6.0)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		stage._input(mm)
		if i % 5 == 0:
			await process_frame
	await process_frame
	print("TEST: brush_hits=", stage._brush_hits, " progress=", stage.progress_bar.value, " finished=", stage._finished)
	assert(stage._brush_hits > 0, "brush must erase with LMB held")
	# 3) Стирание пикселей подтверждено альфой.
	var img: Image = stage.dirt_image
	var erased := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			if img.get_pixel(x, y).a == 0.0:
				erased += 1
	print("TEST: erased_samples=", erased)
	assert(erased > 0, "pixels must become transparent")
	# 4) Guard: свайп ВНЕ рабочей области (по TopBar) не стирает.
	var hits_before: int = stage._brush_hits
	var out := InputEventMouseMotion.new()
	out.global_position = Vector2(10, 10)
	out.button_mask = MOUSE_BUTTON_MASK_LEFT
	stage._input(out)
	await process_frame
	print("TEST: hits_outside_area_delta=", stage._brush_hits - hits_before)
	assert(stage._brush_hits == hits_before, "swipe outside work area must not erase")
	# 5) Довести до завершения: много свайпов по грязным зонам.
	var guard := 0
	var w: float = maxf(work_area.get_global_rect().size.x - 60.0, 10.0)
	var h: float = maxf(work_area.get_global_rect().size.y - 60.0, 10.0)
	while not stage._finished and guard < 400:
		guard += 1
		var mm2 := InputEventMouseMotion.new()
		mm2.global_position = work_area.get_global_position() + Vector2(30.0 + fmod(guard * 7.0, w), 30.0 + fmod(guard * 13.0, h))
		mm2.button_mask = MOUSE_BUTTON_MASK_LEFT
		stage._input(mm2)
		if guard % 10 == 0:
			await process_frame
	await process_frame
	print("TEST: finished=", stage._finished, " final_progress=", stage.progress_bar.value)
	assert(stage._finished, "stage must finish at >=85%")
	# 6) После завершения ввод заблокирован: новые события игнорируются.
	var hits_fin: int = stage._brush_hits
	var post := InputEventMouseMotion.new()
	post.global_position = work_area.get_global_position() + Vector2(100, 100)
	post.button_mask = MOUSE_BUTTON_MASK_LEFT
	stage._input(post)
	await process_frame
	print("TEST: input_locked_after_finish=", stage._brush_hits == hits_fin)
	assert(stage._brush_hits == hits_fin, "input must be locked after finish")
	print("ALL TESTS PASSED")
	quit(0)
