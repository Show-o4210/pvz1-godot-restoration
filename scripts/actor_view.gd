extends RefCounted
## Presentation for the community-converted reanim scenes. Every clock is manual,
## so combat, damage flashes, detached parts and corpses share the pause clock.

const FLASH_SHADER = preload("res://scripts/hit_flash.gdshader")
const Attachment := preload("res://scripts/reanim_attachment.gd")
const Motion := preload("res://scripts/reanim_motion.gd")
const DiscreteState := preload("res://scripts/reanim_discrete_state.gd")
const ZOMBIE_MOTION = preload("res://assets/actors/zombie_motion.json")
const HEAD_PARTS = ["anim_sprout", "anim_face", "idle_mouth", "idle_shoot_blink", "anim_blink"]
var art: Node2D
var player: AnimationPlayer
var head: AnimationPlayer
var eyelids: AnimationPlayer
var kind: String
var frozen := false
var hurt_time := 0.0
var shoot_time := 0.0
var blink_time := 4.0
var blink_left := 0.0
var arm_lost := false
var head_lost := false
var dead := false
var armor := 0.0
var damage_stage := 0
var material: ShaderMaterial
var attachment: Node2D
var motion: RefCounted
var blink_sprites: Array[Sprite2D] = []

func setup(node: Node2D, actor_kind: String, animation: String, static_icon := false) -> void:
	art = node
	kind = actor_kind
	frozen = static_icon or kind == "mower"
	player = art.get_node("AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if kind == "sun":
		# Coin.cpp explicitly loops Sun at 6 fps. The unlabelled rotating
		# track is not numerically closed, so the converter marks it one-shot.
		# Duplicate before overriding: never mutate shared imported resources.
		var sun_clip: Animation = player.get_animation("idle").duplicate()
		sun_clip.loop_mode = Animation.LOOP_LINEAR
		var sun_library := AnimationLibrary.new()
		sun_library.add_animation("idle", sun_clip)
		player.remove_animation_library("")
		player.add_animation_library("", sun_library)
	material = ShaderMaterial.new()
	material.shader = FLASH_SHADER
	for child in art.get_children():
		if child is Sprite2D:
			child.material = material
			if String(child.name).begins_with("anim_blink"): blink_sprites.append(child)
	if kind == "zombie":
		motion = Motion.new()
		motion.configure(ZOMBIE_MOTION.data.walk, 12.0)
	if kind in ["peashooter", "sunflower", "wallnut"] and not static_icon:
		var blink_source := "blink_twice" if kind == "wallnut" else "blink"
		var blink_animation: Animation = player.get_animation(blink_source).duplicate()
		for i in range(blink_animation.get_track_count() - 1, -1, -1):
			if not String(blink_animation.track_get_path(i).get_name(0)).begins_with("anim_blink"):
				blink_animation.remove_track(i)
		var blink_library := AnimationLibrary.new()
		blink_library.add_animation("blink", blink_animation)
		eyelids = AnimationPlayer.new()
		eyelids.name = "BlinkAnimation"
		eyelids.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		art.add_child(eyelids)
		eyelids.add_animation_library("", blink_library)
	if kind == "peashooter" and not static_icon:
		# Body and head have separate original animation segments. Filtering avoids
		# the head's shooting segment hiding the leaves or freezing the stem.
		var body_library := AnimationLibrary.new()
		body_library.add_animation("idle", filtered(player.get_animation("idle"), false))
		var head_library := AnimationLibrary.new()
		head_library.add_animation("idle", Attachment.retarget(filtered(player.get_animation("head_idle"), true), HEAD_PARTS, "HeadAttachment"))
		head_library.add_animation("shooting", Attachment.retarget(filtered(player.get_animation("shooting"), true), HEAD_PARTS, "HeadAttachment"))
		player.remove_animation_library("")
		player.add_animation_library("", body_library)
		play("idle")
		attachment = Attachment.new()
		attachment.name = "HeadAttachment"
		art.add_child(attachment)
		attachment.bind(art, "anim_stem", HEAD_PARTS)
		var blink_copy := Attachment.retarget(eyelids.get_animation("blink"), HEAD_PARTS, "HeadAttachment")
		eyelids.get_animation_library("").remove_animation("blink")
		eyelids.get_animation_library("").add_animation("blink", blink_copy)
		head = AnimationPlayer.new()
		head.name = "HeadAnimation"
		head.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		art.add_child(head)
		head.add_animation_library("", head_library)
		head.play("idle", -1, 18.0 / 12.0)
		head.advance(0)
		DiscreteState.apply(head)
	else:
		play(animation)
		if kind == "sunflower" and not static_icon:
			# The blink segment is an overlay authored in the idle face's bind
			# coordinates. Carry it with the full face transform, not the stem.
			attachment = Attachment.new()
			attachment.name = "FaceAttachment"
			art.add_child(attachment)
			attachment.bind(art, "anim_idle", ["anim_blink"])
			var body_library := AnimationLibrary.new()
			for clip_name in player.get_animation_list():
				body_library.add_animation(clip_name, Attachment.retarget(player.get_animation(clip_name), ["anim_blink"], "FaceAttachment"))
			player.remove_animation_library("")
			player.add_animation_library("", body_library)
			var blink_copy := Attachment.retarget(eyelids.get_animation("blink"), ["anim_blink"], "FaceAttachment")
			eyelids.get_animation_library("").remove_animation("blink")
			eyelids.get_animation_library("").add_animation("blink", blink_copy)
			play(animation)
	if kind == "zombie":
		apply_damage_parts()

func filtered(source: Animation, head_only: bool) -> Animation:
	var animation: Animation = source.duplicate()
	for i in range(animation.get_track_count() - 1, -1, -1):
		var part := String(animation.track_get_path(i).get_name(0))
		if HEAD_PARTS.has(part) != head_only:
			animation.remove_track(i)
	return animation

func play(animation: String) -> void:
	var rate := 1.0
	if kind == "peashooter": rate = 18.0 / 12.0
	elif kind in ["sunflower", "wallnut"]: rate = 12.5 / 12.0
	elif kind == "mower": rate = 35.0 / 20.0
	elif kind == "sun": rate = 6.0 / 12.0
	elif kind == "zombie" and animation == "death": rate = 24.0 / 12.0
	elif kind == "zombie" and animation == "eat": rate = 36.0 / 12.0
	elif kind == "zombie" and animation == "walk": rate = motion.playback_rate
	var blend := 0.18 if kind == "zombie" and player.is_playing() else 0.0
	player.play(animation, blend, rate)
	player.advance(0)
	DiscreteState.apply(player)
	if kind == "zombie": apply_damage_parts()

func shoot() -> void:
	if head == null: return
	shoot_time = head.get_animation("shooting").length / (35.0 / 12.0)
	head.play("shooting", 0.12, 35.0 / 12.0)
	head.advance(0)
	DiscreteState.apply(head)

func hurt() -> void:
	hurt_time = 0.25
	material.set_shader_parameter("flash", 0.3)

func update(delta: float) -> void:
	if not frozen:
		player.advance(delta)
		DiscreteState.apply(player)
		if head != null:
			head.advance(delta)
			if shoot_time > 0:
				shoot_time -= delta
				if shoot_time <= 0:
					head.play("idle", 0.12, 18.0 / 12.0)
					head.seek(player.current_animation_position, false)
			DiscreteState.apply(head)
		# A separate eyelid player preserves the current body/head pose.
		blink_time -= delta
		if kind in ["sunflower", "wallnut", "peashooter"] and not dead:
			if blink_time <= 0 and shoot_time <= 0 and damage_stage == 0:
				blink_left = eyelids.get_animation("blink").length
				eyelids.play("blink")
				blink_time = randf_range(3.5, 6.0)
			if blink_left > 0:
				eyelids.advance(delta)
				DiscreteState.apply(eyelids)
			blink_left = maxf(0, blink_left - delta)
			if blink_left <= 0 or shoot_time > 0:
				for eyelid in blink_sprites: eyelid.hide()
		if attachment != null: attachment.sync_pose()
	hurt_time = maxf(0, hurt_time - delta)
	material.set_shader_parameter("flash", hurt_time * 1.2)
	if kind == "zombie": apply_damage_parts()
	elif kind == "wallnut" and damage_stage > 0:
		art.get_node("anim_face").texture = load("res://assets/images/Wallnut_cracked%d.png" % damage_stage)

func set_health(hp: float, max_hp: float) -> void:
	damage_stage = 2 if hp < max_hp / 3.0 else (1 if hp < max_hp * 2.0 / 3.0 else 0)
	update(0)

func apply_damage_parts() -> void:
	for name in ["anim_bucket", "anim_screendoor", "Zombie_flaghand", "Zombie_duckytube", "Zombie_whitewater", "Zombie_whitewater2", "Zombie_mustache", "Zombie_innerarm_screendoor", "Zombie_innerarm_screendoor_hand", "Zombie_outerarm_screendoor"]:
		var part := art.get_node_or_null(name)
		if part: part.hide()
	# anim_head2 is Zombie_jaw.png, a required body part rather than a spare head.
	art.get_node("anim_head2").visible = not head_lost
	art.get_node("anim_cone").visible = armor > 0 and not head_lost
	if armor > 0:
		var stage := 3 if armor < 370.0 / 3.0 else (2 if armor < 370.0 * 2.0 / 3.0 else 1)
		art.get_node("anim_cone").texture = load("res://assets/images/Zombie_cone%d.png" % stage)
	if arm_lost:
		art.get_node("Zombie_outerarm_lower").hide()
		art.get_node("Zombie_outerarm_hand").hide()
		art.get_node("Zombie_outerarm_upper").texture = preload("res://assets/images/Zombie_outerarm_upper2.png")
	if head_lost:
		for child in art.get_children():
			if child is Sprite2D and (String(child.name).begins_with("anim_head") or String(child.name).begins_with("anim_hair") or String(child.name).begins_with("anim_tongue")):
				child.hide()

func muzzle_position() -> Vector2:
	var mouth: Sprite2D = attachment.get_node("idle_mouth")
	return mouth.to_global(Vector2(28, 26))

func walk_distance(delta: float) -> float:
	return motion.displacement(player.current_animation_position, delta)
