extends Node2D
## Minimal daytime PvZ recreation. Simulation is updated independently of animation.

const GRID_ORIGIN := Vector2(80, 80)
const CELL_SIZE := Vector2(80, 100)
const ROWS := 5
const COLS := 9
const DEFINITIONS := {
	"sunflower": {"name": "向日葵", "cost": 50, "hp": 300.0, "cooldown": 7.5, "packet": 1},
	"peashooter": {"name": "豌豆射手", "cost": 100, "hp": 300.0, "cooldown": 7.5, "packet": 0},
	"wallnut": {"name": "坚果墙", "cost": 50, "hp": 4000.0, "cooldown": 30.0, "packet": 3},
}
const ACTORS := {
	"sunflower": preload("res://assets/actors/sunflower.tscn"),
	"peashooter": preload("res://assets/actors/peashootersingle.tscn"),
	"wallnut": preload("res://assets/actors/wallnut.tscn"),
	"zombie": preload("res://assets/actors/zombie.tscn"),
	"sun": preload("res://assets/actors/sun.tscn"),
	"mower": preload("res://assets/actors/lawnmower.tscn"),
}
const PEA_TEXTURE := preload("res://assets/images/ProjectilePea.png")
const ActorView := preload("res://scripts/actor_view.gd")
const PLANT_OFFSET := Vector2(-40, -50)

var sun_count := 50
var selected := ""
var elapsed := 0.0
var sky_timer := 3.0
var paused := false
var result := ""
var plants: Array[Dictionary] = []
var zombies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var suns: Array[Dictionary] = []
var sun_flights: Array[Dictionary] = []
var sun_flight_layer: CanvasLayer
var sun_slot_flash := 0.0
var mowers: Array[Dictionary] = []
var schedule: Array[Dictionary] = []
var cooldowns := {"sunflower": 0.0, "peashooter": 0.0, "wallnut": 0.0}
var spawn_index := 0
var defeated := 0
var automatic_spawns := true
var silent := false
var seed_buttons: Dictionary = {}
var sun_label: Label
var wave_label: Label
var hint_label: Label
var pause_button: Button
var shovel_button: Button
var result_panel: PanelContainer
var result_label: Label
var hover_cell := Vector2i(-1, -1)
var ghost: Node2D
var voices: Array[AudioStreamPlayer] = []
var views: Array = []
var effects: Array[Dictionary] = []
var corpses: Array[Dictionary] = []
var progress_fill: Sprite2D
var progress_head: Sprite2D
var menu_panel: Control


func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = preload("res://assets/images/background1.jpg")
	background.centered = false
	background.position.x = -160
	add_child(background)
	for i in 10:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	_build_hud()
	_build_schedule()
	for row in ROWS:
		var art := _new_actor("mower", Vector2(20, GRID_ORIGIN.y + row * CELL_SIZE.y + 23), "normal")
		art.scale = Vector2.ONE * 0.85
		art.z_index = 100 + row * 10 + 5
		mowers.append({"row": row, "x": 20.0, "active": false, "used": false, "art": art})
	_update_hud()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bank := TextureRect.new()
	bank.texture = preload("res://assets/images/SeedBank.png")
	bank.position = Vector2(0, 0)
	bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bank)
	sun_flight_layer = CanvasLayer.new()
	sun_flight_layer.layer = 2
	add_child(sun_flight_layer)
	sun_label = _label(layer, Vector2(8, 58), Vector2(64, 24), 19)
	sun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sun_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.04))
	sun_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	var packet := AtlasTexture.new()
	packet.atlas = preload("res://assets/images/seeds.png")
	packet.region = Rect2(100, 0, 50, 70)
	var order := ["peashooter", "sunflower", "wallnut"]
	for i in order.size():
		var kind: String = order[i]
		var button := Button.new()
		button.position = Vector2(85 + i * 59, 8)
		button.size = Vector2(50, 70)
		button.flat = true
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.tooltip_text = "%s · %d 阳光\n快捷键 %d" % [DEFINITIONS[kind].name, DEFINITIONS[kind].cost, i + 1]
		button.pressed.connect(select_seed.bind(kind))
		layer.add_child(button)
		var icon := Sprite2D.new()
		icon.name = "Card"
		icon.centered = false
		icon.texture = packet
		button.add_child(icon)
		var miniature: Node2D = ACTORS[kind].instantiate()
		miniature.position = Vector2(5, 8)
		miniature.scale = Vector2.ONE * 0.5
		button.add_child(miniature)
		var icon_view = ActorView.new()
		icon_view.setup(miniature, kind, "full_idle" if kind == "peashooter" else "idle", true)
		var cost := _label(button, Vector2(0, 50), Vector2(50, 20), 13)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.add_theme_color_override("font_color", Color.BLACK)
		cost.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		cost.text = str(DEFINITIONS[kind].cost)
		var shade := ColorRect.new()
		shade.name = "Recharge"
		shade.color = Color(0, 0, 0, 0.55)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(shade)
		var timer_label := _label(button, Vector2(0, 25), Vector2(50, 25), 17)
		timer_label.name = "Cooldown"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seed_buttons[kind] = button
	shovel_button = Button.new()
	shovel_button.position = Vector2(456, 0)
	shovel_button.size = Vector2(70, 72)
	shovel_button.flat = true
	shovel_button.tooltip_text = "铲除植物 · 快捷键 4"
	shovel_button.pressed.connect(select_seed.bind("shovel"))
	layer.add_child(shovel_button)
	var shovel_bank := Sprite2D.new()
	shovel_bank.centered = false
	shovel_bank.texture = preload("res://assets/images/ShovelBank.png")
	shovel_button.add_child(shovel_bank)
	var shovel_icon := Sprite2D.new()
	shovel_icon.centered = false
	shovel_icon.texture = preload("res://assets/images/Shovel.png")
	shovel_icon.position = Vector2(0, -4)
	shovel_button.add_child(shovel_icon)
	pause_button = _button(layer, "菜单", Vector2(681, -10), Vector2(117, 46))
	pause_button.pressed.connect(toggle_pause)
	wave_label = _label(layer, Vector2(410, 577), Vector2(175, 22), 13)
	hint_label = _label(layer, Vector2(8, 578), Vector2(390, 22), 13)
	hint_label.text = "1/2/3 选卡 · 4 铲子 · 空格暂停"
	var meter := Sprite2D.new()
	meter.centered = false
	var meter_texture := AtlasTexture.new()
	meter_texture.atlas = preload("res://assets/images/FlagMeter.png")
	meter_texture.region = Rect2(0, 0, 158, 27)
	meter.texture = meter_texture
	meter.position = Vector2(600, 575)
	layer.add_child(meter)
	progress_fill = Sprite2D.new()
	var fill_texture := AtlasTexture.new()
	fill_texture.atlas = preload("res://assets/images/FlagMeter.png")
	fill_texture.region = Rect2(7, 27, 143, 27)
	progress_fill.texture = fill_texture
	progress_fill.centered = false
	progress_fill.position = Vector2(607, 575)
	layer.add_child(progress_fill)
	var meter_caption := Sprite2D.new()
	meter_caption.centered = false
	meter_caption.texture = preload("res://assets/images/FlagMeterLevelProgress.png")
	meter_caption.position = Vector2(638, 589)
	layer.add_child(meter_caption)
	progress_head = Sprite2D.new()
	var head_icon := AtlasTexture.new()
	head_icon.atlas = preload("res://assets/images/FlagMeterParts.png")
	head_icon.region = Rect2(0, 0, 25, 25)
	progress_head.texture = head_icon
	progress_head.centered = false
	progress_head.position = Vector2(738, 572)
	layer.add_child(progress_head)
	menu_panel = _dialog(layer, Vector2(200, 135), Vector2(400, 300))
	var menu_title := _label(menu_panel, Vector2(50, 35), Vector2(300, 40), 28)
	menu_title.text = "游戏暂停"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(menu_panel, "继续游戏", Vector2(70, 105), Vector2(260, 46)).pressed.connect(toggle_pause)
	_button(menu_panel, "重新开始", Vector2(70, 169), Vector2(260, 46)).pressed.connect(restart_game)
	menu_panel.hide()
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(180, 165)
	result_panel.size = Vector2(440, 245)
	result_panel.add_theme_stylebox_override("panel", _dialog_style())
	layer.add_child(result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	result_panel.add_child(box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 30)
	box.add_child(result_label)
	var replay := _button(box, "再玩一次", Vector2.ZERO, Vector2(250, 46))
	replay.custom_minimum_size = Vector2(250, 46)
	replay.pressed.connect(restart_game)
	result_panel.hide()


func _label(parent: Node, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	for state in ["normal", "hover", "pressed", "disabled"]:
		var skin := StyleBoxTexture.new()
		skin.texture = _button_texture(state == "pressed")
		skin.texture_margin_left = 36
		skin.texture_margin_right = 35
		button.add_theme_stylebox_override(state, skin)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.95, 0.89, 0.63))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.8))
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	return button


func _button_texture(down: bool) -> Texture2D:
	var prefix := "button_down_" if down else "button_"
	var image := Image.create(117, 46, false, Image.FORMAT_RGBA8)
	var x := 0
	for side in ["left", "middle", "right"]:
		var tile: Image = load("res://assets/images/" + prefix + side + ".png").get_image()
		image.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x, 0))
		x += tile.get_width()
	return ImageTexture.create_from_image(image)


func _dialog_style() -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = preload("res://assets/images/dialog.png")
	skin.texture_margin_left = 107
	skin.texture_margin_right = 120
	skin.texture_margin_top = 97
	skin.texture_margin_bottom = 114
	skin.content_margin_left = 50
	skin.content_margin_right = 50
	skin.content_margin_top = 50
	skin.content_margin_bottom = 45
	return skin


func _dialog(parent: Node, pos: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _dialog_style())
	parent.add_child(panel)
	return panel


func _build_schedule() -> void:
	# A short authored daytime encounter, not a copy of the original adventure levels.
	var lanes := [2, 1, 3, 0, 4, 2, 1, 3, 0, 4, 2, 1, 3, 0, 4]
	for i in lanes.size():
		var wave := 1 if i < 3 else (2 if i < 8 else 3)
		var start := 25.0 if wave == 1 else (62.0 if wave == 2 else 112.0)
		var local_index: int = i if wave == 1 else (i - 3 if wave == 2 else i - 8)
		schedule.append({"time": start + local_index * 7.0, "row": lanes[i], "cone": i >= 10 and i % 2 == 0, "wave": wave})


func lane_y(row: int) -> float:
	return GRID_ORIGIN.y + (row + 0.5) * CELL_SIZE.y


func cell_center(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE


func screen_to_cell(pos: Vector2) -> Vector2i:
	var cell := Vector2i(floori((pos.x - GRID_ORIGIN.x) / CELL_SIZE.x), floori((pos.y - GRID_ORIGIN.y) / CELL_SIZE.y))
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return Vector2i(-1, -1)
	return cell


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ESCAPE: toggle_pause()
			KEY_R: restart_game()
			KEY_1: select_seed("peashooter")
			KEY_2: select_seed("sunflower")
			KEY_3: select_seed("wallnut")
			KEY_4: select_seed("shovel")
	if paused or not result.is_empty():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			select_seed("")
		elif event.button_index == MOUSE_BUTTON_LEFT:
			handle_click(get_global_mouse_position())


func handle_click(pos: Vector2) -> void:
	if paused or not result.is_empty():
		return
	# Suns take precedence over planting, including when overlapping an empty cell.
	for sun in suns.duplicate():
		if pos.distance_to(sun.position) < 33:
			collect_sun(sun)
			return
	var cell := screen_to_cell(pos)
	if cell.x < 0:
		return
	if selected == "shovel":
		for plant in plants.duplicate():
			if plant.cell == cell:
				_remove_entity(plants, plant)
				_play_sound("plant")
				break
		select_seed("")
	elif not selected.is_empty():
		try_plant(selected, cell)


func select_seed(kind: String) -> void:
	if paused or not result.is_empty():
		return
	if not kind.is_empty() and kind != "shovel":
		if not DEFINITIONS.has(kind) or sun_count < DEFINITIONS[kind].cost or cooldowns[kind] > 0:
			return
	selected = kind
	if not kind.is_empty(): _play_sound("seedlift")
	if is_instance_valid(ghost):
		ghost.queue_free()
		ghost = null
	if DEFINITIONS.has(kind):
		ghost = _new_actor(kind, Vector2.ZERO, "full_idle" if kind == "peashooter" else "idle")
		ghost.modulate.a = 0.45
		ghost.z_index = 190
	_update_hud()


func try_plant(kind: String, cell: Vector2i) -> bool:
	if paused or not result.is_empty() or not DEFINITIONS.has(kind):
		return false
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return false
	if sun_count < DEFINITIONS[kind].cost or cooldowns[kind] > 0:
		return false
	for plant in plants:
		if plant.cell == cell:
			return false
	var pos := cell_center(cell)
	var art := _new_actor(kind, pos + PLANT_OFFSET, "full_idle" if kind == "peashooter" else "idle")
	art.z_index = 100 + cell.y * 10
	_add_shadow(art, Vector2(-3, 51))
	plants.append({"kind": kind, "cell": cell, "hp": DEFINITIONS[kind].hp, "attack": 0.3, "windup": -1.0, "produce": 6.0, "art": art})
	sun_count -= DEFINITIONS[kind].cost
	cooldowns[kind] = DEFINITIONS[kind].cooldown
	_play_sound("plant")
	select_seed("")
	return true


func _new_actor(kind: String, pos: Vector2, animation: String) -> Node2D:
	var art: Node2D = ACTORS[kind].instantiate()
	art.position = pos
	add_child(art)
	var view = ActorView.new()
	view.setup(art, kind, animation)
	art.set_meta("view", view)
	views.append(view)
	return art


func _add_shadow(art: Node2D, pos: Vector2) -> void:
	var shadow := Sprite2D.new()
	shadow.name = "GroundShadow"
	shadow.centered = false
	shadow.texture = preload("res://assets/images/plantshadow.png")
	shadow.position = pos
	shadow.z_index = -1
	art.add_child(shadow)


func spawn_zombie(row: int, cone: bool = false, x: float = 825.0) -> Dictionary:
	var art := _new_actor("zombie", Vector2(x - 40, GRID_ORIGIN.y + row * CELL_SIZE.y - 30), "walk")
	art.z_index = 100 + row * 10 + 2
	for part in ["anim_bucket", "anim_screendoor", "Zombie_flaghand", "Zombie_duckytube", "Zombie_whitewater", "Zombie_whitewater2", "Zombie_mustache", "Zombie_innerarm_screendoor", "Zombie_innerarm_screendoor_hand", "Zombie_outerarm_screendoor"]:
		var node := art.get_node_or_null(part)
		if node:
			node.visible = false
	art.get_meta("view").armor = 370.0 if cone else 0.0
	art.get_meta("view").apply_damage_parts()
	_add_shadow(art, Vector2(12, 106))
	art.get_node("GroundShadow").scale = Vector2(0.8, 0.8)
	var zombie := {"row": row, "x": x, "hp": 200.0, "armor": 370.0 if cone else 0.0, "bite": 0.0, "art": art, "state": "walk"}
	zombies.append(zombie)
	_play_sound("groan")
	return zombie


func spawn_sun(pos: Vector2, falling: bool = false) -> Dictionary:
	var art := _new_actor("sun", pos, "idle")
	art.scale = Vector2.ONE * 0.7
	art.z_index = 210
	var sun := {"position": pos, "target_y": randf_range(170, 515) if falling else pos.y + 35, "life": 12.0, "art": art}
	suns.append(sun)
	return sun


func collect_sun(sun: Dictionary) -> void:
	if paused or not result.is_empty() or not suns.has(sun):
		return
	# Credit once at the click, preserving the existing economy. The same actor
	# becomes a non-clickable UI flight, independent of falling/expiry logic.
	sun_count += int(sun.get("value", 25))
	suns.erase(sun)
	var start: Vector2 = sun.art.global_position
	sun.art.reparent(sun_flight_layer, false)
	sun.art.position = start
	var target := sun_collection_target()
	sun_flights.append({"art": sun.art, "start": start, "target": target, "age": 0.0,
		"duration": clampf(start.distance_to(target) / 900.0, 0.35, 0.75), "scale": sun.art.scale})
	_play_sound("points")
	_update_hud()


func sun_collection_target() -> Vector2:
	return sun_label.get_global_rect().get_center() - Vector2(0, 36)


func fire_pea(row: int, x: float, y: float = NAN) -> Dictionary:
	var art := Sprite2D.new()
	art.texture = PEA_TEXTURE
	art.position = Vector2(x, lane_y(row) - 20 if is_nan(y) else y)
	art.z_index = 100 + row * 10 + 3
	add_child(art)
	var pea := {"row": row, "x": x, "art": art}
	projectiles.append(pea)
	return pea


func _physics_process(delta: float) -> void:
	if not paused and result.is_empty():
		simulate(delta)
	elif not paused:
		_update_presentation(delta)
	_update_hud()
	var mouse := get_global_mouse_position()
	hover_cell = screen_to_cell(mouse)
	if is_instance_valid(ghost):
		ghost.visible = hover_cell.x >= 0 and not paused and result.is_empty()
		if ghost.visible:
			ghost.position = cell_center(hover_cell) + PLANT_OFFSET
	queue_redraw()


func simulate(delta: float) -> void:
	if paused or not result.is_empty():
		return
	elapsed += delta
	for kind in cooldowns:
		cooldowns[kind] = maxf(0, cooldowns[kind] - delta)
	if automatic_spawns:
		sky_timer -= delta
		if sky_timer <= 0:
			spawn_sun(Vector2(randf_range(110, 740), 90), true)
			sky_timer += 9.0
		while spawn_index < schedule.size() and elapsed >= schedule[spawn_index].time:
			var entry := schedule[spawn_index]
			spawn_zombie(entry.row, entry.cone)
			spawn_index += 1
	_update_plants(delta)
	_update_projectiles(delta)
	_update_zombies(delta)
	_update_mowers(delta)
	for sun in suns.duplicate():
		sun.life -= delta
		sun.position.y = move_toward(sun.position.y, sun.target_y, 40 * delta)
		sun.art.position = sun.position
		if sun.life <= 0:
			_remove_entity(suns, sun)
	# Movement samples the current pose; animate to the resulting pose afterwards.
	_update_presentation(delta)
	if automatic_spawns and spawn_index == schedule.size() and zombies.is_empty() and result.is_empty():
		_finish("胜利！", "你守住了草坪。")


func _update_plants(delta: float) -> void:
	for plant in plants.duplicate():
		plant.attack -= delta
		plant.produce -= delta
		var center := cell_center(plant.cell)
		if plant.kind == "peashooter" and plant.windup >= 0:
			plant.windup -= delta
			if plant.windup <= 0:
				var muzzle: Vector2 = plant.art.get_meta("view").muzzle_position()
				fire_pea(plant.cell.y, muzzle.x, muzzle.y)
				_play_sound("throw" if randf() < 0.5 else "throw2")
				plant.windup = -1.0
		if plant.kind == "sunflower" and plant.produce <= 0:
			spawn_sun(center + Vector2(5, -35))
			plant.produce += 24.0
		elif plant.kind == "peashooter" and plant.attack <= 0:
			for zombie in zombies:
				if zombie.row == plant.cell.y and zombie.x > center.x - 15 and zombie.x < 855:
					plant.art.get_meta("view").shoot()
					plant.windup = 0.35
					plant.attack = 1.425
					break


func _update_projectiles(delta: float) -> void:
	for pea in projectiles.duplicate():
		var old_x: float = pea.x
		pea.x += 330 * delta
		var target: Dictionary = {}
		var nearest := INF
		for zombie in zombies:
			if zombie.row != pea.row:
				continue
			# Swept collision catches the first body crossed during this tick.
			if old_x <= zombie.x + 22 and pea.x >= zombie.x - 22 and zombie.x < nearest:
				target = zombie
				nearest = zombie.x
		if not target.is_empty():
			_pea_splat(Vector2(target.x - 12, pea.art.position.y), pea.row)
			damage_zombie(target, 20)
			_play_sound("splat")
			_remove_entity(projectiles, pea)
		elif pea.x > 890:
			_remove_entity(projectiles, pea)
		else:
			pea.art.position.x = pea.x


func damage_zombie(zombie: Dictionary, amount: float, flash := true) -> void:
	if not zombies.has(zombie):
		return
	var absorbed := minf(zombie.armor, amount)
	zombie.armor -= absorbed
	zombie.hp -= amount - absorbed
	var view = zombie.art.get_meta("view")
	view.armor = zombie.armor
	if flash: view.hurt()
	if zombie.hp < 200.0 * 2.0 / 3.0 and not view.arm_lost:
		_drop_part(zombie, "ZombieArm", "Zombie_outerarm_hand")
		view.arm_lost = true
	if zombie.hp < 200.0 / 3.0 and not view.head_lost:
		_drop_part(zombie, "ZombieHead", "anim_head1")
		view.head_lost = true
	view.apply_damage_parts()
	if zombie.hp <= 0:
		defeated += 1
		var art: Node2D = zombie.art
		zombies.erase(zombie)
		view.dead = true
		view.play("death")
		corpses.append({"art": art, "life": 2.3, "fade": 0.7})


func _update_zombies(delta: float) -> void:
	for zombie in zombies.duplicate():
		var view = zombie.art.get_meta("view")
		if view.head_lost:
			damage_zombie(zombie, 20 * delta, false)
			if not zombies.has(zombie): continue
		var target: Dictionary = {}
		var rightmost := -INF
		for plant in plants:
			var center := cell_center(plant.cell)
			if not view.head_lost and plant.cell.y == zombie.row and zombie.x - center.x >= -28 and center.x > rightmost:
				target = plant
				rightmost = center.x
		var biting: bool = not target.is_empty() and zombie.x - rightmost <= 37
		var bite_delta := delta if biting else 0.0
		if not biting:
			if zombie.state != "walk":
				view.play("walk")
				zombie.state = "walk"
			var distance: float = view.walk_distance(delta)
			if not target.is_empty() and distance >= zombie.x - rightmost - 37:
				var gap: float = maxf(0, zombie.x - rightmost - 37)
				zombie.x -= gap
				biting = true
				bite_delta = delta * (1.0 - gap / maxf(distance, 0.00001))
			else:
				zombie.x -= distance
		var next_state := "eat" if biting else "walk"
		if next_state != zombie.state:
			view.play(next_state)
			zombie.state = next_state
		if biting:
			target.hp -= 100 * bite_delta
			zombie.bite -= bite_delta
			if zombie.bite <= 0:
				target.art.get_meta("view").hurt()
				_play_sound("chomp")
				zombie.bite = 0.8
			target.art.get_meta("view").set_health(target.hp, DEFINITIONS[target.kind].hp)
			if target.hp <= 0:
				_remove_entity(plants, target)
		zombie.art.position.x = zombie.x - 40
		if zombie.x < 58:
			var mower := mowers[zombie.row]
			if not mower.used:
				mower.active = true
				mower.used = true
				mower.art.get_meta("view").frozen = false
				_play_sound("lawnmower")
			elif not mower.active and zombie.x < 18:
				_finish("僵尸吃掉了你的脑子！", "补上防线，再试一次。")
				return


func _update_mowers(delta: float) -> void:
	for mower in mowers:
		if not mower.active:
			continue
		var old_x: float = mower.x
		mower.x += 500 * delta
		mower.art.position.x = mower.x
		for zombie in zombies.duplicate():
			if zombie.row == mower.row and zombie.x >= old_x - 45 and zombie.x <= mower.x + 45:
				damage_zombie(zombie, 10000)
		if mower.x > 900:
			mower.active = false
			mower.art.hide()


func _remove_entity(collection: Array[Dictionary], entity: Dictionary) -> void:
	collection.erase(entity)
	entity.art.queue_free()


func _update_presentation(delta: float) -> void:
	sun_slot_flash = maxf(0, sun_slot_flash - delta)
	sun_label.modulate = Color(1, 0.65, 0.15) if sun_slot_flash > 0 else Color.WHITE
	for flight in sun_flights.duplicate():
		flight.age += delta
		var t := clampf(float(flight.age) / float(flight.duration), 0, 1)
		var progress := 1.0 - pow(1.0 - t, 2.0)
		flight.art.position = flight.start.lerp(flight.target, progress) + Vector2(0, -sin(t * PI) * 12)
		flight.art.scale = flight.scale.lerp(Vector2.ONE * 0.3, progress)
		if t >= 1:
			flight.art.queue_free()
			sun_flights.erase(flight)
			sun_slot_flash = 0.18
	for view in views.duplicate():
		if not is_instance_valid(view.art) or view.art.is_queued_for_deletion():
			views.erase(view)
		else:
			view.update(delta)
	for corpse in corpses.duplicate():
		corpse.life -= delta
		corpse.art.modulate.a = clampf(corpse.life / corpse.fade, 0, 1)
		if corpse.life <= 0:
			corpse.art.queue_free()
			corpses.erase(corpse)
	for effect in effects.duplicate():
		effect.age += delta
		effect.velocity.y += effect.gravity * delta
		effect.art.position += effect.velocity * delta
		effect.art.rotation += effect.spin * delta
		if effect.gravity > 0 and effect.art.position.y >= effect.ground:
			effect.art.position.y = effect.ground
			effect.velocity = Vector2(effect.velocity.x * 0.6, -absf(effect.velocity.y) * 0.22)
			effect.spin *= 0.4
			if absf(effect.velocity.y) < 12:
				effect.gravity = 0
				effect.velocity = Vector2.ZERO
				effect.spin = 0
		effect.art.modulate.a = clampf((effect.life - effect.age) / minf(0.5, effect.life), 0, 1)
		if effect.age >= effect.life:
			effect.art.queue_free()
			effects.erase(effect)


func _effect(texture: Texture2D, pos: Vector2, row: int, velocity: Vector2, lifetime: float, gravity := 0.0, spin := 0.0) -> Dictionary:
	var art := Sprite2D.new()
	art.texture = texture
	art.position = pos
	art.z_index = 100 + row * 10 + 4
	add_child(art)
	var effect := {"art": art, "velocity": velocity, "age": 0.0, "life": lifetime, "gravity": gravity, "spin": spin, "ground": GRID_ORIGIN.y + row * CELL_SIZE.y + 85}
	effects.append(effect)
	return effect


func _pea_splat(pos: Vector2, row: int) -> void:
	var splat := AtlasTexture.new()
	splat.atlas = preload("res://assets/images/pea_splats.png")
	splat.region = Rect2(randi_range(0, 3) * 24, 0, 24, 24)
	var impact := _effect(splat, pos, row, Vector2.ZERO, 0.2)
	impact.art.scale = Vector2.ONE * 0.6
	for i in randi_range(6, 10):
		var fragment := AtlasTexture.new()
		fragment.atlas = preload("res://assets/images/Pea_particles.png")
		fragment.region = Rect2(randi_range(0, 2) * 11, 0, 11, 11)
		var angle := randf() * TAU
		var chip := _effect(fragment, pos, row, Vector2.from_angle(angle) * 150, 0.2, 1000)
		chip.art.scale = Vector2.ONE * randf_range(0.8, 1.2)


func _drop_part(zombie: Dictionary, texture_name: String, track: String) -> void:
	var part: Sprite2D = zombie.art.get_node(track)
	var pos: Vector2 = part.to_global(part.texture.get_size() * 0.5)
	# Values decoded from the local original ZombieHead/ZombieArm particle files.
	var is_head := texture_name == "ZombieHead"
	var angle := deg_to_rad(randf_range(150, 185) if is_head else randf_range(90, 185))
	var velocity := Vector2(sin(angle), cos(angle)) * (330 if is_head else 40)
	var part_effect := _effect(load("res://assets/images/" + texture_name + ".png"), pos, zombie.row, velocity, 1.8 if is_head else 1.0, 1700 if is_head else 1500, randf_range(-4, 4))
	part_effect.art.scale = Vector2.ONE * 0.8
	_play_sound("limbs_pop")


func toggle_pause() -> void:
	if not result.is_empty():
		return
	paused = not paused
	menu_panel.visible = paused
	pause_button.text = "继续" if paused else "菜单"
	for voice in voices: voice.stream_paused = paused
	hint_label.text = "已暂停 · 空格或右上角按钮继续" if paused else "1/2/3 选卡 · 4 铲子 · 空格暂停"


func _finish(title: String, message: String) -> void:
	result = title
	result_label.text = title
	result_label.add_theme_font_size_override("font_size", 24 if title.length() > 8 else 30)
	hint_label.text = message
	result_panel.show()
	if is_instance_valid(ghost):
		ghost.hide()


func restart_game() -> void:
	get_tree().reload_current_scene()


func _play_sound(name: String) -> void:
	if silent:
		return
	var path := "res://assets/sounds/%s.ogg" % name
	if ResourceLoader.exists(path):
		for voice in voices:
			if not voice.playing:
				voice.stream = load(path)
				voice.volume_db = -12
				voice.play()
				break


func _update_hud() -> void:
	sun_label.text = str(sun_count)
	for kind in seed_buttons:
		var button: Button = seed_buttons[kind]
		button.disabled = sun_count < DEFINITIONS[kind].cost or cooldowns[kind] > 0 or paused or not result.is_empty()
		button.modulate = Color(1, 0.9, 0.6) if selected == kind else (Color(0.55, 0.55, 0.55) if button.disabled else Color.WHITE)
		button.get_node("Recharge").size = Vector2(50, 70 * cooldowns[kind] / DEFINITIONS[kind].cooldown)
		button.get_node("Cooldown").text = str(ceili(cooldowns[kind])) if cooldowns[kind] > 0 else ""
		button.tooltip_text = "%s · %d 阳光%s" % [DEFINITIONS[kind].name, DEFINITIONS[kind].cost, " · 冷却 %.1fs" % cooldowns[kind] if cooldowns[kind] > 0 else ""]
	shovel_button.modulate = Color(1, 0.85, 0.4) if selected == "shovel" else Color.WHITE
	var wave := 1
	if spawn_index > 0:
		wave = schedule[spawn_index - 1].wave
	wave_label.text = "第 %d / 3 波 · %d / 15" % [wave, defeated]
	var progress := clampf(elapsed / 155.0, 0, 1)
	progress_fill.visible = progress > 0
	progress_fill.texture.region = Rect2(151 - progress * 143, 27, progress * 143, 27)
	progress_fill.position.x = 751 - progress * 143
	progress_head.position.x = 738 - progress * 135


func _draw() -> void:
	if not selected.is_empty() and hover_cell.x >= 0 and not paused and result.is_empty():
		draw_rect(Rect2(GRID_ORIGIN + Vector2(hover_cell) * CELL_SIZE, CELL_SIZE), Color(1, 1, 0.7, 0.2))
