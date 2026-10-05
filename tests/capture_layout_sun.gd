extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	seed(1051)
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.automatic_spawns = false
	game.silent = true
	game.sun_count = 2500 # Preview fixture only.
	game.try_plant("sunflower", Vector2i(0, 0))
	game.try_plant("peashooter", Vector2i(2, 1))
	game.cooldowns.peashooter = 0
	game.try_plant("peashooter", Vector2i(8, 4))
	var mod: bool = game.has_method("request_controlled_action")
	if mod:
		for rank in 2:
			game.cooldowns.sunflower = 0
			game.try_plant("sunflower", Vector2i(0, 0))
		game.control.select(game.plants[0], game.plants)
		game.request_controlled_action()
	game.spawn_zombie(1, false, 850)
	game.spawn_zombie(4, true, 825)
	for point in [Vector2(400, 210), Vector2(575, 345), Vector2(680, 465)]:
		var sun: Dictionary = game.spawn_sun(point)
		sun.target_y = point.y
	var filename := "mod-v0.5" if mod else "v1.1-layout-sun"
	for tick in 480:
		if tick == 150 and mod: game.release_controlled_action()
		if tick == 300: game.collect_sun(game.suns[0])
		game.simulate(1.0 / 60.0)
		game._update_hud()
		await process_frame
		if tick == 179:
			RenderingServer.force_draw()
			var frame := root.get_texture().get_image()
			frame.resize(900, 640 if mod else 600, Image.INTERPOLATE_LANCZOS)
			frame.save_png("res://build/%s.png" % filename)
	print("Layout/sun preview: 8 seconds, full lawn, road, inset toolbar, continuous original Sun rays and collection.")
	game.free()
	await process_frame
	quit()
