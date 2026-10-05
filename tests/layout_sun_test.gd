extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func run_tests() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.automatic_spawns = false
	game.silent = true
	check(game.screen_to_cell(Vector2(40, 80)) == Vector2i(0, 0), "first lawn tile starts inside the original grass margin")
	check(game.screen_to_cell(Vector2(759, 579)) == Vector2i(8, 4), "all nine columns and five rows remain clickable")
	check(game.screen_to_cell(Vector2(780, 250)).x == -1 and game.screen_to_cell(Vector2(870, 250)).x == -1, "sidewalk and road are decorative and cannot accept plants")
	check(game.seed_buttons.peashooter.global_position == Vector2(95, 14), "card art and hit target share the inset toolbar transform")
	var target: Vector2 = game.sun_collection_target()
	check(target.x == 50 and target.y >= 39 and target.y <= 46, "sun returns to the inset slot rather than its old coordinate (%s)" % target)
	var a: Dictionary = game.spawn_sun(Vector2(450, 300))
	var b: Dictionary = game.spawn_sun(Vector2(600, 300))
	a.target_y = a.position.y
	b.target_y = b.position.y
	var view = a.art.get_meta("view")
	var other = b.art.get_meta("view")
	var rays: Sprite2D = a.art.get_node("Sun2")
	var center: Sprite2D = a.art.get_node("Sun1")
	var origin := center.transform
	var first_rotation := rays.rotation
	check(view.player.get_animation("idle").loop_mode == Animation.LOOP_LINEAR and view.player.get_playing_speed() == 0.5, "sun repeats the original layered clip at the original six-fps rate")
	check(view.player.get_animation("idle") != other.player.get_animation("idle"), "each sun owns its loop override without changing shared imported data")
	var probe = game.ACTORS.sun.instantiate()
	check(probe.get_node("AnimationPlayer").get_animation("idle").loop_mode == Animation.LOOP_NONE, "imported resource remains unchanged")
	probe.free()
	game.simulate(0.5)
	check(rays.rotation > first_rotation and center.transform == origin, "rays rotate slowly while the bright center remains steady")
	var saved := rays.transform
	game.toggle_pause()
	game.simulate(3)
	check(rays.transform == saved, "pause stops sun rotation as well as combat")
	game.toggle_pause()
	game.simulate(3.1)
	check(view.player.is_playing() and not rays.transform.is_equal_approx(saved), "rotation keeps moving after the former one-second stop and a full loop")
	var second_time: float = other.player.current_animation_position
	game.collect_sun(a)
	game.simulate(0.1)
	check(a.art.get_meta("view").player.is_playing() and a.art.scale.x < 0.7, "rotating layers survive reparenting and flight shrink")
	check(other.player.current_animation_position != second_time, "collecting one sun leaves the other sun's clock advancing")
	check(game.sun_count == 75, "rotating feedback does not alter collection value")
	game.free()
	await process_frame
	print("Layout/sun checks: %d; failures: %d" % [checks, failures])
	quit(failures)
