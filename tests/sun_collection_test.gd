extends SceneTree
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
	var sun: Dictionary = game.spawn_sun(Vector2(500, 400))
	sun.life = 0.01
	var actor: Node2D = sun.art
	var origin := actor.position
	game.collect_sun(sun)
	check(game.sun_count == 75, "collection credits exactly once at click")
	check(game.suns.is_empty() and game.sun_flights.size() == 1, "collected sun leaves clickable/falling collection")
	check(not actor.is_queued_for_deletion() and actor.position == origin, "same visible sun starts its flight without teleporting")
	check(actor.get_parent() == game.sun_flight_layer and game.sun_flight_layer.layer > 1, "flight draws above the seed-bank UI")
	game.collect_sun(sun)
	check(game.sun_count == 75 and game.sun_flights.size() == 1, "duplicate collection cannot credit or animate twice")
	game.simulate(0.15)
	check(actor.position.distance_to(game.sun_collection_target()) < origin.distance_to(game.sun_collection_target()), "sun moves toward the slot")
	check(actor.scale.x < 0.7 and not actor.is_queued_for_deletion(), "flight shrinks and ignores original expiry")
	var before := actor.position
	game.toggle_pause()
	game.simulate(1)
	check(actor.position == before, "pause freezes the collection flight")
	game.toggle_pause()
	var second: Dictionary = game.spawn_sun(Vector2(650, 550), true)
	game.collect_sun(second)
	check(game.sun_flights.size() == 2 and game.sun_count == 100, "multiple collections fly independently")
	game.simulate(1)
	check(actor.position.is_equal_approx(game.sun_collection_target()) and actor.is_queued_for_deletion(), "arrival reaches the slot and removes the actor")
	check(game.sun_flights.is_empty() and game.sun_slot_flash > 0, "arrival clears flights and pulses the counter")
	var last: Dictionary = game.spawn_sun(Vector2(400, 200))
	game.collect_sun(last)
	game._finish("胜利！", "test")
	game._update_presentation(1)
	check(game.sun_flights.is_empty() and last.art.is_queued_for_deletion(), "in-progress flight completes after victory")
	game.free()
	await process_frame
	print("Sun collection checks: %d; failures: %d" % [checks, failures])
	quit(failures)
