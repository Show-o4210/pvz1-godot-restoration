extends SceneTree

var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func fresh_game() -> void:
	if is_instance_valid(game):
		game.free()
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.automatic_spawns = false
	game.silent = true
	game.sun_count = 1000

func run_tests() -> void:
	fresh_game()
	check(game.screen_to_cell(Vector2(39, 150)).x == -1, "left boundary rejects outside lawn")
	check(game.try_plant("peashooter", Vector2i(0, 2)), "planting succeeds")
	check(game.sun_count == 900, "planting spends exact cost")
	var money: int = game.sun_count
	check(not game.try_plant("wallnut", Vector2i(0, 2)), "occupied cell rejects planting")
	check(game.sun_count == money, "rejected placement spends no sun")
	check(not game.try_plant("peashooter", Vector2i(1, 2)), "seed cooldown is enforced")
	game.sun_count = 0
	check(not game.try_plant("sunflower", Vector2i(1, 1)), "insufficient sun rejects planting")
	var far: Dictionary = game.spawn_zombie(2, false, 600)
	game._update_plants(0.4)
	check(game.projectiles.is_empty(), "shooting windup precedes projectile release")
	game._update_plants(0.35)
	check(game.projectiles.size() == 1 and far.hp == 200, "firing does not cause instant damage")
	game._update_projectiles(0.2)
	check(far.hp == 200, "pea does not hit before reaching zombie")
	var front: Dictionary = game.spawn_zombie(2, false, 400)
	var other_lane: Dictionary = game.spawn_zombie(1, false, 350)
	game._update_projectiles(2.0)
	check(front.hp == 180 and far.hp == 200 and other_lane.hp == 200, "swept pea hits only nearest zombie in its lane")
	var cone: Dictionary = game.spawn_zombie(3, true, 550)
	game.damage_zombie(cone, 400)
	check(cone.armor == 0 and cone.hp == 170, "armor absorbs damage and overflow reaches body")
	check(not cone.art.get_node("anim_cone").visible, "broken cone disappears")
	var sun: Dictionary = game.spawn_sun(game.cell_center(Vector2i(1, 4)))
	game.cooldowns.sunflower = 0
	game.sun_count = 100
	game.select_seed("sunflower")
	game.handle_click(sun.position)
	check(game.sun_count == 125 and game.plants.size() == 1, "collecting sun takes precedence over planting")
	game.toggle_pause()
	var time: float = game.elapsed
	var cooldown: float = game.cooldowns.peashooter
	game.simulate(4)
	check(game.elapsed == time and game.cooldowns.peashooter == cooldown, "pause freezes combat and cooldowns")
	game.toggle_pause()
	game.select_seed("shovel")
	game.handle_click(game.cell_center(Vector2i(0, 2)))
	check(game.plants.is_empty() and game.sun_count == 125, "shovel frees cell without refund")
	fresh_game()
	game.try_plant("wallnut", Vector2i(4, 2))
	var eater: Dictionary = game.spawn_zombie(2, false, game.cell_center(Vector2i(4, 2)).x + 25)
	game._update_zombies(1)
	check(eater.state == "eat" and game.plants[0].hp == 3900, "zombie stops and bites plant")
	game.plants[0].hp = 20
	game._update_zombies(1)
	game._update_zombies(0.1)
	check(game.plants.is_empty() and eater.state == "walk", "zombie resumes walking after plant dies")
	fresh_game()
	var breach: Dictionary = game.spawn_zombie(0, false, 55)
	game._update_zombies(0.01)
	game._update_mowers(0.08) # Travel from the restored left-side parking position.
	check(game.mowers[0].used and game.zombies.is_empty(), "mower clears first breach")
	game._update_mowers(2)
	game.spawn_zombie(0, false, 10)
	game._update_zombies(0.01)
	check(not game.result.is_empty(), "second breach loses after mower is used")
	fresh_game()
	game.automatic_spawns = true
	game.spawn_index = game.schedule.size()
	game.sky_timer = 999
	var last: Dictionary = game.spawn_zombie(2, false, 700)
	game.simulate(0.01)
	check(game.result.is_empty(), "victory waits for last surviving zombie")
	game.damage_zombie(last, 10000)
	game.simulate(0.01)
	check(game.result == "胜利！", "clearing final zombie wins")
	game.free()
	await process_frame
	print("Gameplay checks complete; failures: ", failures)
	quit(failures)
