extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.automatic_spawns = false
	game.silent = true
	var suns := [game.spawn_sun(Vector2(260, 240)), game.spawn_sun(Vector2(520, 370)), game.spawn_sun(Vector2(700, 500))]
	DirAccess.make_dir_recursive_absolute("res://build/sun-collection-frames")
	for tick in 120:
		if tick in [12, 24, 36]: game.collect_sun(suns[(tick - 12) / 12])
		game.simulate(1.0 / 60.0)
		game._update_hud()
		await process_frame
		if tick % 3 == 0:
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.resize(800, 600, Image.INTERPOLATE_LANCZOS)
			frame.save_png("res://build/sun-collection-frames/%03d.png" % (tick / 3))
	print("Sun collection preview captured.")
	quit()
