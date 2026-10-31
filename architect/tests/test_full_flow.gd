extends SceneTree
## Интеграционный тест: Main -> HubScreen -> CleanStage -> stage_finished.

func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	assert(main_scene != null, "Main scene load failed")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	for i in 15:
		await process_frame
	var hub: Node = main.get_node_or_null("HubScreen")
	assert(hub != null, "hub missing")
	hub._on_start_pressed()
	for i in 10:
		await process_frame
	var stage: Control = main.get_node_or_null("CleanStage")
	assert(stage != null, "clean stage missing after start")
	print("TEST: stage_has_script=", stage.get_script() != null)
	var work_area: Control = stage.get_node("WorkMargin/WorkArea")
	var finished_seen := [false]
	stage.stage_finished.connect(func(_p: float) -> void: finished_seen[0] = true)
	var guard := 0
	while not stage._finished and guard < 120:
		guard += 1
		var gx: float = fmod(guard * 37.0, 9.0) / 8.0
		var gy: float = floorf(guard / 9.0) / 12.0
		var mm2 := InputEventMouseMotion.new()
		mm2.global_position = work_area.get_global_position() + work_area.size * Vector2(0.05 + gx * 0.9, 0.05 + gy * 0.9)
		mm2.button_mask = MOUSE_BUTTON_MASK_LEFT
		stage._input(mm2)
		if guard % 6 == 0:
			await process_frame
	for i in 5:
		await process_frame
	print("TEST: stage_finished_emitted=", finished_seen[0], " progress=", stage.progress_bar.value)
	assert(finished_seen[0], "stage_finished must be emitted")
	print("FULL FLOW PASSED")
	quit(0)
