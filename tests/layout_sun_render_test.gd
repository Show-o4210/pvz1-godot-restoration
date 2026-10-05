extends SceneTree
var checks := 0
var failures := 0
var viewport: SubViewport
var game: Node
func _initialize() -> void:
	call_deferred("run_tests")
func check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func mouse(pos: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	viewport.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = pos
	click.pressed = pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	viewport.push_input(click, true)
func snapshot() -> Image:
	game._update_hud()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run_tests() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(900, ProjectSettings.get_setting("display/window/size/viewport_height"))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.automatic_spawns = false
	game.silent = true
	game.sun_count = 1000
	game.try_plant("sunflower", Vector2i(0, 0))
	game.try_plant("peashooter", Vector2i(7, 1))
	for frame in 2: await process_frame
	mouse(Vector2(230, 30), true)
	mouse(Vector2(230, 30), false)
	check(game.selected == "wallnut", "real inset card click selects the correct seed")
	mouse(game.to_global(game.cell_center(Vector2i(8, 4))), true)
	mouse(game.to_global(game.cell_center(Vector2i(8, 4))), false)
	check(game.plants[-1].kind == "wallnut" and game.plants[-1].cell == Vector2i(8, 4), "real click reaches the entire rightmost bottom lawn tile")
	var sun: Dictionary = game.spawn_sun(Vector2(500, 300))
	sun.target_y = 300
	game.simulate(0.2)
	var first := await snapshot()
	first.save_png("res://build/layout-sun.png")
	var road := first.get_pixel(870, 300 + roundi(game.position.y))
	check(maxf(road.r, maxf(road.g, road.b)) - minf(road.r, minf(road.g, road.b)) < 0.08 and road.g > 0.3 and road.g < 0.9, "GPU visibly renders the gray road beyond the complete lawn")
	check(game.seed_bar.global_position.x >= 10 and game.seed_bar.global_position.y >= 6, "toolbar has a visible inset on both edges")
	game.simulate(0.5)
	var second := await snapshot()
	game.simulate(3.1)
	var third := await snapshot()
	third.save_png("res://build/layout-sun-later.png")
	var changed_early := 0
	var changed_late := 0
	var world_y := 300 + roundi(game.position.y)
	for y in range(world_y - 50, world_y + 50):
		for x in range(450, 550):
			if not first.get_pixel(x, y).is_equal_approx(second.get_pixel(x, y)): changed_early += 1
			if not second.get_pixel(x, y).is_equal_approx(third.get_pixel(x, y)): changed_late += 1
	check(changed_early > 100, "GPU shows moving sun rays rather than a static icon (%d pixels)" % changed_early)
	check(changed_late > 100, "GPU sun keeps animating after multiple original clip boundaries (%d pixels)" % changed_late)
	game.toggle_pause()
	game.menu_panel.hide() # Inspect the frozen actor without the pause dialog covering it.
	game.simulate(1)
	var paused := await snapshot()
	check(paused.get_pixel(500, world_y) == third.get_pixel(500, world_y), "pause retains the sun's captured pose")
	viewport.free()
	await process_frame
	print("Layout/sun GPU checks: %d; failures: %d" % [checks, failures])
	quit(failures)
