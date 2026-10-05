extends SceneTree
## Close-up: three body phases blink together, while each face keeps swaying.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.16, 0.35, 0.18)
	background.size = viewport.size
	viewport.add_child(background)
	var views := []
	for i in 3:
		var actor = load("res://assets/actors/sunflower.tscn").instantiate()
		actor.position = Vector2(35 + i * 240, 45)
		actor.scale = Vector2(2.5, 2.5)
		viewport.add_child(actor)
		var view = preload("res://scripts/actor_view.gd").new()
		view.setup(actor, "sunflower", "idle")
		view.update(i * 0.55)
		views.append(view)
	DirAccess.make_dir_recursive_absolute("res://build/blink-frames")
	for tick in 240:
		for view in views:
			if tick % 48 == 0: view.blink_time = 0
			view.update(1.0 / 60.0)
		await process_frame
		if tick % 3 == 0:
			await RenderingServer.frame_post_draw
			var frame := viewport.get_texture().get_image()
			frame.save_png("res://build/blink-frames/%03d.png" % (tick / 3))
			if tick == 6: frame.save_png("res://build/sunflower-blink.png")
	print("Sunflower close-up rendered: 4 seconds, three independent sway phases.")
	quit()
