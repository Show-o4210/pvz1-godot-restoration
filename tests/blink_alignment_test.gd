extends SceneTree
## Eyelid placement must follow the face at every body phase, including loops.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, description: String) -> void:
	checks += 1
	if value: print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run_tests() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.automatic_spawns = false
	game.silent = true
	game.sun_count = 1000
	game.try_plant("sunflower", Vector2i(1, 2))
	var plant: Dictionary = game.plants[0]
	var view = plant.art.get_meta("view")
	var face: Sprite2D = plant.art.get_node("anim_idle")
	var eyelid: Sprite2D = view.blink_sprites[0]
	view.player.seek(0, true)
	view.blink_time = 0
	view.update(0)
	var reference_face := face.transform
	# Independent raw blink instance supplies the authored overlay, never bound.
	var raw = load("res://assets/actors/sunflower.tscn").instantiate()
	root.add_child(raw)
	var raw_player: AnimationPlayer = raw.get_node("AnimationPlayer")
	raw_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	raw_player.play("blink")
	for phase in [0.0, 0.4, 1.0, 1.8, 2.07]:
		view.player.seek(phase, true)
		view.eyelids.stop()
		view.blink_time = 0
		view.blink_left = 0
		view.update(0)
		for tick in 3:
			view.update(0.06)
			raw_player.seek(view.eyelids.current_animation_position, true)
			preload("res://scripts/reanim_discrete_state.gd").apply(raw_player)
			var authored: Sprite2D = raw.get_node("anim_blink")
			var expected := face.transform * reference_face.affine_inverse() * authored.transform
			var actual: Transform2D = plant.art.global_transform.affine_inverse() * eyelid.global_transform
			check(actual.is_equal_approx(expected) and eyelid.visible and face.visible,
				"blink follows face translation/scale at body phase %.2f, tick %d" % [phase, tick])
			check(eyelid.texture == authored.texture, "blink retains authored eyelid image at tick %d" % tick)
	var before := eyelid.global_transform
	var body_phase: float = view.player.current_animation_position
	var blink_phase: float = view.eyelids.current_animation_position
	game.paused = true
	game.simulate(0.5)
	check(eyelid.global_transform.is_equal_approx(before) and view.player.current_animation_position == body_phase and view.eyelids.current_animation_position == blink_phase, "pause freezes body and eyelids together")
	game.paused = false
	view.update(0.1)
	check(not eyelid.visible and face.visible, "blink completion removes overlay and leaves swaying face visible")
	# Freeze only blink time: a rotated/scaled actor and face must still carry it.
	view.blink_time = 0
	view.update(0.01)
	var local_before := face.global_transform.affine_inverse() * eyelid.global_transform
	plant.art.transform = Transform2D(0.3, Vector2(150, 200)).scaled(Vector2(1.2, 0.9))
	face.transform = Transform2D(-0.2, Vector2(22, 18)).scaled(Vector2(0.75, 0.8))
	if view.attachment != null: view.attachment.sync_pose()
	check((face.global_transform.affine_inverse() * eyelid.global_transform).is_equal_approx(local_before), "binding carries complete face and actor transforms without double sway")
	raw.free()
	game.free()
	await process_frame
	print("Blink alignment checks: %d; failures: %d" % [checks, failures])
	quit(failures)
