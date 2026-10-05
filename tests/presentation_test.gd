extends SceneTree

var failures := 0
var checks := 0
var game: Node

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, description: String) -> void:
	checks += 1
	if value: print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run_tests() -> void:
	seed(1051)
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.automatic_spawns = false
	game.silent = true
	game.sun_count = 1000
	var mower: Node2D = game.mowers[0].art
	var wheel: Sprite2D = mower.get_node("Lawnmower_frontwheel1")
	var initial_rotation := wheel.rotation
	game.simulate(0.4)
	check(wheel.rotation == initial_rotation, "idle mower wheels remain still")
	for button in game.seed_buttons.values():
		check(button.size == Vector2(50, 70) and button.get_node("Card").texture.get_size() == Vector2(50, 70), "seed card and clickable region use original 50x70 dimensions")
	check(game.screen_to_cell(Vector2(80, 570)) == Vector2i(0, 4), "bottom lawn row stays fully clickable")
	game.try_plant("peashooter", Vector2i(1, 2))
	var shooter: Dictionary = game.plants[0]
	var view = shooter.art.get_meta("view")
	var victim: Dictionary = game.spawn_zombie(2, false, 550)
	for i in 20: game.simulate(1.0 / 60.0)
	check(view.head.current_animation == "shooting" and game.projectiles.is_empty(), "original head shooting animation starts before pea release")
	check(shooter.art.get_node("frontleaf").visible and shooter.art.get_node("stalk_bottom").visible, "shooting preserves body and leaves")
	for i in 22: game.simulate(1.0 / 60.0)
	check(game.projectiles.size() == 1, "windup releases exactly one pea")
	check(absf(game.projectiles[0].art.position.y - view.muzzle_position().y) < 5, "pea height follows animated mouth")
	for i in 35: game.simulate(1.0 / 60.0)
	check(view.head.current_animation == "idle", "shooting head returns to idle")
	game.damage_zombie(victim, 80)
	var zombie_view = victim.art.get_meta("view")
	check(zombie_view.arm_lost and not victim.art.get_node("Zombie_outerarm_hand").visible, "damage threshold detaches outer arm")
	zombie_view.play("eat")
	game._update_presentation(0.2)
	check(not victim.art.get_node("Zombie_outerarm_lower").visible, "animation changes cannot restore lost arm")
	game.damage_zombie(victim, 70)
	check(zombie_view.head_lost and not victim.art.get_node("anim_head1").visible, "damage threshold detaches head")
	check(game.effects.size() >= 2, "detached head and arm have visible falling effects")
	game.try_plant("wallnut", Vector2i(4, 2))
	var nut: Dictionary = game.plants[-1]
	victim.x = game.cell_center(nut.cell).x + 25
	var nut_hp: float = nut.hp
	game._update_zombies(0.1)
	check(nut.hp == nut_hp and victim.state == "walk", "headless zombie cannot bite")
	nut.hp = 2500
	nut.art.get_meta("view").set_health(nut.hp, 4000)
	check(nut.art.get_node("anim_face").texture.resource_path.ends_with("Wallnut_cracked1.png"), "wallnut uses first original damage texture")
	nut.hp = 1200
	nut.art.get_meta("view").set_health(nut.hp, 4000)
	check(nut.art.get_node("anim_face").texture.resource_path.ends_with("Wallnut_cracked2.png"), "wallnut uses second original damage texture")
	nut.art.get_meta("view").hurt()
	check(nut.art.get_meta("view").material.get_shader_parameter("flash") > 0, "plant damage starts a white flash")
	game._update_presentation(0.3)
	check(nut.art.get_meta("view").material.get_shader_parameter("flash") == 0, "damage flash decays without leaving permanent tint")
	game._pea_splat(Vector2(500, 250), 1)
	check(game.effects.size() >= 7, "pea impact creates original splat and debris")
	game.toggle_pause()
	var age: float = game.effects[-1].age
	var animation_time: float = view.player.current_animation_position
	game.simulate(1)
	check(game.effects[-1].age == age and view.player.current_animation_position == animation_time, "pause freezes effects and animation clocks")
	game.toggle_pause()
	game.spawn_zombie(0, false, 55)
	game._update_zombies(0.01)
	game._update_presentation(0.15)
	check(wheel.rotation != initial_rotation, "activated mower wheels animate")
	var dying: Dictionary = game.spawn_zombie(4, false, 700)
	game.damage_zombie(dying, 10000)
	check(dying.art.get_meta("view").player.current_animation == "death", "lethal hit plays original collapse animation")
	game._finish("胜利！", "test")
	game._update_presentation(3)
	check(game.corpses.is_empty() and dying.art.is_queued_for_deletion(), "corpses finish and fade even after victory")
	game.free()
	await process_frame
	print("Presentation checks: %d; failures: %d" % [checks, failures])
	quit(failures)
