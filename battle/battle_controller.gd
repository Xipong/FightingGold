extends Control

@onready var arena: Control = %Arena
@onready var slash_layer: Control = %SlashLayer
@onready var impact_flash: ColorRect = %ImpactFlash
@onready var player_sprite: ColorRect = %PlayerFighter
@onready var enemy_sprite: ColorRect = %EnemyFighter
@onready var player_shadow: ColorRect = %PlayerShadow
@onready var enemy_shadow: ColorRect = %EnemyShadow
@onready var telegraph_label: Label = %TelegraphLabel
@onready var log_label: RichTextLabel = %CombatLog
@onready var player_hp: ProgressBar = %PlayerHP
@onready var enemy_hp: ProgressBar = %EnemyHP
@onready var player_stamina: ProgressBar = %PlayerStamina
@onready var enemy_stamina: ProgressBar = %EnemyStamina
@onready var player_guard: ProgressBar = %PlayerGuard
@onready var enemy_guard: ProgressBar = %EnemyGuard
@onready var status_line: Label = %StatusLine
@onready var combo_line: Label = %ComboLine

var player := Fighter.new()
var enemy := Fighter.new()
var player_ai := PlayerAI.new()
var enemy_ai := EnemyAI.new()

var enemy_data: Dictionary = {}
var distance := 130.0
const NEUTRAL_DISTANCE := 130.0
var frame_acc := 0.0
var hit_stop_timer := 0.0
const FRAME_TIME := 0.08
var pending_hit: Dictionary = {}
var enemy_pending_hit: Dictionary = {}
var shake_power := 0.0
var shake_timer := 0.0
var arena_origin := Vector2.ZERO

var player_lunge := 0.0
var enemy_lunge := 0.0
var player_hit_bump := 0.0
var enemy_hit_bump := 0.0
var player_scale_boost := 0.0
var enemy_scale_boost := 0.0
var elapsed := 0.0
var player_tint := Color("5cc8ff")
var enemy_tint := Color("ff6b6b")

const ATTACK_VFX := {
	"jab": {"lunge": 18.0, "scale": 0.08, "trail": 1, "angle": 4.0, "width": 48.0, "thickness": 5.0, "travel": 20.0, "color": Color(0.78, 0.93, 1.0, 0.9)},
	"hook": {"lunge": 24.0, "scale": 0.10, "trail": 1, "angle": 28.0, "width": 56.0, "thickness": 6.0, "travel": 24.0, "color": Color(0.92, 0.83, 1.0, 0.9)},
	"step_slash": {"lunge": 32.0, "scale": 0.11, "trail": 2, "angle": 14.0, "width": 66.0, "thickness": 6.0, "travel": 32.0, "color": Color(0.72, 0.96, 1.0, 0.9)},
	"gut_punch": {"lunge": 30.0, "scale": 0.14, "trail": 1, "angle": 0.0, "width": 62.0, "thickness": 8.0, "travel": 20.0, "color": Color(1.0, 0.85, 0.72, 0.92)},
	"rising_kick": {"lunge": 34.0, "scale": 0.16, "trail": 2, "angle": 50.0, "width": 70.0, "thickness": 8.0, "travel": 28.0, "color": Color(1.0, 0.9, 0.7, 0.9), "lift": 14.0},
	"shoulder_bash": {"lunge": 52.0, "scale": 0.18, "trail": 1, "angle": 0.0, "width": 84.0, "thickness": 11.0, "travel": 40.0, "color": Color(1.0, 0.84, 0.72, 0.95)},
	"crusher": {"lunge": 38.0, "scale": 0.18, "trail": 2, "angle": -22.0, "width": 86.0, "thickness": 11.0, "travel": 36.0, "color": Color(1.0, 0.74, 0.6, 0.95)},
	"sunder": {"lunge": 42.0, "scale": 0.2, "trail": 2, "angle": -30.0, "width": 90.0, "thickness": 12.0, "travel": 38.0, "color": Color(1.0, 0.7, 0.58, 0.95)},
	"execute": {"lunge": 48.0, "scale": 0.24, "trail": 3, "angle": -38.0, "width": 96.0, "thickness": 13.0, "travel": 44.0, "color": Color(1.0, 0.62, 0.56, 0.97)},
	"anvil_breaker": {"lunge": 40.0, "scale": 0.19, "trail": 2, "angle": -32.0, "width": 88.0, "thickness": 12.0, "travel": 38.0, "color": Color(1.0, 0.74, 0.64, 0.95)},
	"shield_splitter": {"lunge": 40.0, "scale": 0.18, "trail": 2, "angle": 90.0, "width": 78.0, "thickness": 9.0, "travel": 30.0, "color": Color(0.82, 0.95, 1.0, 0.93)},
	"backfist": {"lunge": 22.0, "scale": 0.09, "trail": 1, "angle": -26.0, "width": 54.0, "thickness": 6.0, "travel": 22.0, "color": Color(0.78, 0.9, 1.0, 0.88)},
	"low_sweep": {"lunge": 28.0, "scale": 0.1, "trail": 2, "angle": -8.0, "width": 62.0, "thickness": 5.0, "travel": 34.0, "color": Color(0.72, 0.84, 1.0, 0.88), "y_offset": 102.0},
	"counter_lunge": {"lunge": 46.0, "scale": 0.16, "trail": 2, "angle": 8.0, "width": 82.0, "thickness": 9.0, "travel": 44.0, "color": Color(1.0, 0.9, 0.75, 0.94)},
	"meteor_smash": {"lunge": 58.0, "scale": 0.27, "trail": 3, "angle": -70.0, "width": 102.0, "thickness": 14.0, "travel": 48.0, "color": Color(1.0, 0.58, 0.52, 0.98)},
	"iron_wall": {"lunge": 10.0, "scale": 0.12, "trail": 1, "angle": 90.0, "width": 52.0, "thickness": 11.0, "travel": 0.0, "color": Color(0.72, 0.9, 1.0, 0.9)},
	"piercing_dash": {"lunge": 56.0, "scale": 0.16, "trail": 2, "angle": 4.0, "width": 92.0, "thickness": 9.0, "travel": 52.0, "color": Color(0.9, 0.96, 1.0, 0.95)},
	"whirl_kick": {"lunge": 34.0, "scale": 0.16, "trail": 3, "angle": 0.0, "width": 74.0, "thickness": 7.0, "travel": 26.0, "color": Color(0.84, 0.92, 1.0, 0.9)},
	"snap_knee": {"lunge": 26.0, "scale": 0.11, "trail": 1, "angle": 20.0, "width": 58.0, "thickness": 7.0, "travel": 24.0, "color": Color(0.86, 0.95, 1.0, 0.9)}
}

func _ready() -> void:
	add_child(player)
	add_child(enemy)
	arena_origin = arena.position
	impact_flash.modulate.a = 0.0
	RunManager.fight_requested.connect(_on_fight_requested)
	FXManager.combat_log.connect(_append_log)
	FXManager.hit_stop.connect(_on_hit_stop)
	FXManager.camera_shake.connect(_on_camera_shake)
	FXManager.telegraph_flash.connect(_on_telegraph_flash)
	RunManager.start_next_fight()

func _process(delta: float) -> void:
	_update_fx(delta)
	_decay_animation_params(delta)
	if hit_stop_timer > 0.0:
		hit_stop_timer -= delta
		return
	if player.hp <= 0 or enemy.hp <= 0:
		_finish_fight()
		set_process(false)
		return
	frame_acc += delta
	elapsed += delta
	if frame_acc < FRAME_TIME:
		return
	frame_acc = 0.0
	player.tick_regen(FRAME_TIME)
	enemy.tick_regen(FRAME_TIME)
	distance = move_toward(distance, NEUTRAL_DISTANCE, 65.0 * FRAME_TIME)
	_resolve_actions()
	_update_visual_positions()
	_update_ui()

func _on_fight_requested(data: Dictionary) -> void:
	enemy_data = data
	player.configure_from_stats("Player", RunManager.player_stats, true)
	var scaled: Dictionary = data.get("stats", {}).duplicate(true)
	var mult := float(data.get("scale", 1.0))
	scaled["max_hp"] = float(scaled.get("max_hp", 100)) * mult
	scaled["hp"] = scaled["max_hp"]
	scaled["max_stamina"] = float(scaled.get("max_stamina", 90))
	scaled["stamina"] = scaled["max_stamina"]
	scaled["max_guard"] = float(scaled.get("max_guard", 60))
	scaled["guard"] = scaled["max_guard"]
	enemy.configure_from_stats(String(data.get("name", "Enemy")), scaled, false)
	distance = NEUTRAL_DISTANCE
	elapsed = 0.0
	player_tint = Color("5cc8ff")
	enemy_tint = Color("ff6b6b")
	log_label.clear()
	status_line.text = "Fight: %s" % enemy.fighter_name
	telegraph_label.text = ""
	_append_log("[b]Enemy:[/b] %s enters the arena." % enemy.fighter_name)

func _resolve_actions() -> void:
	if player.can_act():
		_take_player_action()
	if enemy.can_act():
		_take_enemy_action()

	var p_state = player.step_frames()
	var e_state = enemy.step_frames()
	if p_state.get("phase") == "active_start":
		pending_hit = {"attacker": player, "defender": enemy, "move": p_state["move"]}
		_advance_distance(player, p_state["move"])
		_play_attack_animation(player, p_state["move"])
	if e_state.get("phase") == "active_start":
		enemy_pending_hit = {"attacker": enemy, "defender": player, "move": e_state["move"]}
		_advance_distance(enemy, e_state["move"])
		_play_attack_animation(enemy, e_state["move"])

	if not pending_hit.is_empty():
		_apply_hit(pending_hit)
		pending_hit.clear()
	if not enemy_pending_hit.is_empty():
		_apply_hit(enemy_pending_hit)
		enemy_pending_hit.clear()

func _take_player_action() -> void:
	var action = player_ai.pick_action(player, enemy, RunManager.behavior_rules, RunManager.selected_combos, RunManager.all_moves, distance)
	combo_line.text = "Player plan: %s" % action.get("label", action.get("combo", "-"))
	match action.get("type", "wait"):
		"wait":
			return
		"reaction":
			if not player.force_dodge():
				player.force_block()
				_play_defense_animation(player, false)
			else:
				_play_defense_animation(player, true)
		"block":
			if player.force_block():
				_play_defense_animation(player, false)
		"combo":
			var combo_name := String(action.get("combo", "default"))
			var chain: Array = RunManager.selected_combos.get(combo_name, [])
			if chain.is_empty():
				return
			var move_id: String = chain[player.combo_index % chain.size()]
			if action.get("prefer_tag", "") != "":
				for candidate in chain:
					if RunManager.all_moves.get(candidate, {}).get("tags", []).has(action["prefer_tag"]):
						move_id = candidate
						break
			var move_data: Dictionary = RunManager.all_moves.get(move_id, {})
			if _move_allowed(player.current_move, move_data):
				var tuned := _tuned_move(move_data, true)
				tuned["id"] = move_id
				if player.enter_move(tuned):
					player.combo_index += 1
					_append_log("Player uses %s" % move_data.get("name", move_id))

func _take_enemy_action() -> void:
	var move_id := enemy_ai.pick_move(enemy, player, enemy_data, RunManager.all_moves, distance)
	if move_id == "":
		return
	var data: Dictionary = RunManager.all_moves.get(move_id, {})
	var move_with_id := data.duplicate(true)
	move_with_id["id"] = move_id
	if enemy.enter_move(move_with_id):
		if data.get("telegraph", false):
			FXManager.emit_telegraph("enemy")
			_append_log("[color=orange]Telegraph:[/color] %s prepares %s" % [enemy.fighter_name, data.get("name", move_id)])

func _apply_hit(event: Dictionary) -> void:
	var attacker: Fighter = event["attacker"]
	var defender: Fighter = event["defender"]
	var move: Dictionary = event["move"]

	var blocked := defender.state == Fighter.State.BLOCKSTUN
	if defender.state == Fighter.State.DODGE:
		_append_log("%s dodges %s" % [defender.fighter_name, move.get("name", "attack")])
		return
	if not _is_in_range(move):
		_append_log("%s whiffs %s" % [attacker.fighter_name, move.get("name", "attack")])
		return

	var result = defender.take_hit(move, blocked, {
		"attack_multiplier": _attack_multiplier(attacker, move),
		"punish_multiplier": attacker.punish_bonus,
		"punished": defender.just_whiffed_punishable
	})
	FXManager.emit_hit_stop(0.07 if move.get("tags", []).has("heavy") else 0.04)
	FXManager.emit_camera_shake(9.0 if move.get("tags", []).has("heavy") else 4.0, 0.10)
	_play_hit_animation(defender, blocked, move)

	if blocked:
		_append_log("%s blocks %s (%s) %.1f" % [defender.fighter_name, attacker.fighter_name, move.get("name", "move"), result.get("damage", 0.0)])
	else:
		_append_log("%s hits %s with %s for %.1f" % [attacker.fighter_name, defender.fighter_name, move.get("name", "move"), result.get("damage", 0.0)])
	if result.get("guard_break", false):
		_append_log("[color=yellow]GUARD BREAK![/color] %s is vulnerable." % defender.fighter_name)
	if result.get("stagger", false):
		_append_log("[color=red]STAGGER![/color] %s can be punished." % defender.fighter_name)

func _attack_multiplier(attacker: Fighter, move: Dictionary) -> float:
	var mult := attacker.damage_multiplier
	if attacker.is_player:
		var tags: Array = move.get("tags", [])
		if tags.has("light"):
			mult += float(RunManager.player_stats.get("light_damage_bonus", 0.0))
		if tags.has("heavy"):
			mult += float(RunManager.player_stats.get("heavy_damage_bonus", 0.0))
	return mult

func _advance_distance(attacker: Fighter, move: Dictionary) -> void:
	var dash := float(move.get("move_forward_distance", 0.0))
	if attacker.is_player:
		distance = max(40.0, distance - dash)
	else:
		distance = max(40.0, distance - dash * 0.9)

func _is_in_range(move: Dictionary) -> bool:
	return distance <= float(move.get("range", 70.0))

func _play_attack_animation(attacker: Fighter, move: Dictionary) -> void:
	var move_id := String(move.get("id", ""))
	var profile := _attack_profile(move_id, move)
	if attacker.is_player:
		player_lunge = max(player_lunge, float(profile.get("lunge", 28.0)))
		player_scale_boost = max(player_scale_boost, float(profile.get("scale", 0.1)))
		player_tint = Color(1.0, 0.95, 0.78)
		if profile.get("lift", 0.0) > 0.0:
			player_hit_bump = min(player_hit_bump, -float(profile.get("lift", 0.0)))
		_spawn_move_vfx(player_sprite.global_position + Vector2(70, float(profile.get("y_offset", 80.0))), true, profile)
	else:
		enemy_lunge = max(enemy_lunge, float(profile.get("lunge", 28.0)))
		enemy_scale_boost = max(enemy_scale_boost, float(profile.get("scale", 0.1)))
		enemy_tint = Color(1.0, 0.95, 0.78)
		if profile.get("lift", 0.0) > 0.0:
			enemy_hit_bump = max(enemy_hit_bump, float(profile.get("lift", 0.0)))
		_spawn_move_vfx(enemy_sprite.global_position + Vector2(20, float(profile.get("y_offset", 80.0))), false, profile)

func _play_hit_animation(defender: Fighter, blocked: bool, move: Dictionary) -> void:
	var heavy := move.get("tags", []).has("heavy")
	if defender.is_player:
		player_hit_bump = max(player_hit_bump, 30.0 if heavy else 18.0)
		player_tint = Color(1.0, 0.75, 0.75) if not blocked else Color(0.8, 0.95, 1.0)
	else:
		enemy_hit_bump = max(enemy_hit_bump, 30.0 if heavy else 18.0)
		enemy_tint = Color(1.0, 0.75, 0.75) if not blocked else Color(0.8, 0.95, 1.0)
	var flash_color := Color(1, 0.9, 0.85, 0.24)
	if blocked:
		flash_color = Color(0.6, 0.85, 1.0, 0.2)
	impact_flash.color = flash_color
	impact_flash.modulate.a = flash_color.a

func _play_defense_animation(target: Fighter, dodge: bool) -> void:
	if target.is_player:
		if dodge:
			player_hit_bump = -24.0
			player_tint = Color(0.85, 1.0, 1.0)
		else:
			player_tint = Color(0.8, 0.95, 1.0)
	else:
		if dodge:
			enemy_hit_bump = 24.0
			enemy_tint = Color(0.85, 1.0, 1.0)
		else:
			enemy_tint = Color(0.8, 0.95, 1.0)

func _attack_profile(move_id: String, move: Dictionary) -> Dictionary:
	var base := ATTACK_VFX.get(move_id, {}).duplicate(true)
	if base.is_empty():
		var heavy := move.get("tags", []).has("heavy")
		base = {
			"lunge": 48.0 if heavy else 28.0,
			"scale": 0.16 if heavy else 0.10,
			"trail": 2 if heavy else 1,
			"angle": 18.0,
			"width": 80.0 if heavy else 56.0,
			"thickness": 10.0 if heavy else 6.0,
			"travel": 34.0,
			"color": Color(1.0, 0.95, 0.85, 0.9) if heavy else Color(0.7, 0.9, 1.0, 0.85)
		}
	return base

func _spawn_move_vfx(pos: Vector2, left_to_right: bool, profile: Dictionary) -> void:
	var trails := int(profile.get("trail", 1))
	for i in range(trails):
		var spread := float(i - (trails - 1) * 0.5)
		var p := pos + Vector2(0.0, spread * 10.0)
		var angle := float(profile.get("angle", 18.0)) + spread * 9.0
		_spawn_slash(p, left_to_right, {
			"width": float(profile.get("width", 56.0)) * (1.0 - abs(spread) * 0.14),
			"thickness": float(profile.get("thickness", 6.0)),
			"travel": float(profile.get("travel", 30.0)),
			"angle": angle,
			"color": profile.get("color", Color(0.7, 0.9, 1.0, 0.85)),
			"duration": 0.11 + float(i) * 0.02
		})

func _spawn_slash(pos: Vector2, left_to_right: bool, data: Dictionary) -> void:
	var slash := ColorRect.new()
	slash.custom_minimum_size = Vector2(float(data.get("width", 56.0)), float(data.get("thickness", 6.0)))
	slash.position = slash_layer.get_global_transform().affine_inverse() * pos
	slash.pivot_offset = slash.custom_minimum_size * 0.5
	var signed_angle := float(data.get("angle", 18.0)) * (1.0 if left_to_right else -1.0)
	slash.rotation = deg_to_rad(signed_angle)
	slash.color = data.get("color", Color(0.7, 0.9, 1.0, 0.85))
	slash_layer.add_child(slash)
	var duration := float(data.get("duration", 0.12))
	var travel := float(data.get("travel", 34.0)) * (1.0 if left_to_right else -1.0)
	var t = create_tween()
	t.tween_property(slash, "scale", Vector2(1.35, 1.08), min(0.07, duration * 0.6))
	t.parallel().tween_property(slash, "modulate:a", 0.0, duration)
	t.parallel().tween_property(slash, "position:x", slash.position.x + travel, duration)
	t.finished.connect(func(): slash.queue_free())

func _tuned_move(move_data: Dictionary, from_player: bool) -> Dictionary:
	var tuned = move_data.duplicate(true)
	if from_player:
		var tags: Array = tuned.get("tags", [])
		if tags.has("light"):
			tuned["recovery_frames"] = max(4, int(tuned.get("recovery_frames", 8)) - int(RunManager.player_stats.get("recovery_reduction_light", 0)))
		if tags.has("heavy"):
			tuned["recovery_frames"] = max(6, int(tuned.get("recovery_frames", 14)) - int(RunManager.player_stats.get("recovery_reduction_heavy", 0)))
	return tuned

func _move_allowed(prev: Dictionary, nxt: Dictionary) -> bool:
	if prev.is_empty():
		return true
	var allowed: Array = prev.get("combo_rules", [])
	if allowed.is_empty():
		return true
	for tag in nxt.get("tags", []):
		if allowed.has(tag):
			return true
	return false

func _update_visual_positions() -> void:
	var t = clamp(distance / 260.0, 0.0, 1.0)
	player_sprite.position.x = lerp(360.0, 560.0, 1.0 - t) + player_lunge - player_hit_bump
	enemy_sprite.position.x = lerp(820.0, 640.0, 1.0 - t) - enemy_lunge + enemy_hit_bump
	player_shadow.position.x = player_sprite.position.x + 12.0
	enemy_shadow.position.x = enemy_sprite.position.x - 4.0
	var base_player := Color("ffd166") if player.state == Fighter.State.STAGGER else Color("5cc8ff")
	var base_enemy := Color("ffd166") if enemy.state == Fighter.State.STAGGER else Color("ff6b6b")
	player_tint = player_tint.lerp(base_player, 0.24)
	enemy_tint = enemy_tint.lerp(base_enemy, 0.24)
	player_sprite.color = player_tint
	enemy_sprite.color = enemy_tint
	var bob := sin(elapsed * 3.2)
	player_sprite.position.y = 160.0 + bob * 3.0
	enemy_sprite.position.y = 160.0 - bob * 3.0
	player_shadow.scale = Vector2(1.0 - abs(bob) * 0.04, 1.0)
	enemy_shadow.scale = Vector2(1.0 - abs(bob) * 0.04, 1.0)
	if player.state == Fighter.State.STARTUP:
		player_scale_boost = max(player_scale_boost, 0.06)
	if enemy.state == Fighter.State.STARTUP:
		enemy_scale_boost = max(enemy_scale_boost, 0.06)
	player_sprite.scale = Vector2(1.0 + player_scale_boost, 1.0 - player_scale_boost * 0.55)
	enemy_sprite.scale = Vector2(1.0 + enemy_scale_boost, 1.0 - enemy_scale_boost * 0.55)

func _update_ui() -> void:
	player_hp.max_value = player.max_hp
	player_hp.value = player.hp
	enemy_hp.max_value = enemy.max_hp
	enemy_hp.value = enemy.hp
	player_stamina.max_value = player.max_stamina
	player_stamina.value = player.stamina
	enemy_stamina.max_value = enemy.max_stamina
	enemy_stamina.value = enemy.stamina
	player_guard.max_value = player.max_guard
	player_guard.value = player.guard
	enemy_guard.max_value = enemy.max_guard
	enemy_guard.value = enemy.guard
	status_line.text = "Player=%s | Enemy=%s | Dist=%.0f" % [Fighter.State.keys()[player.state], Fighter.State.keys()[enemy.state], distance]

func _append_log(t: String) -> void:
	if is_instance_valid(log_label):
		log_label.append_text(t + "\n")

func _on_hit_stop(duration: float) -> void:
	hit_stop_timer = max(hit_stop_timer, duration)

func _on_camera_shake(power: float, duration: float) -> void:
	shake_power = max(shake_power, power)
	shake_timer = max(shake_timer, duration)

func _on_telegraph_flash(target: String) -> void:
	telegraph_label.text = "TELEGRAPH: %s heavy incoming" % target.capitalize()
	telegraph_label.modulate = Color(1.0, 0.4, 0.2, 1.0)

func _update_fx(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		arena.position = arena_origin + Vector2(randf_range(-shake_power, shake_power), randf_range(-shake_power, shake_power))
	else:
		arena.position = arena_origin
		shake_power = 0.0
	if telegraph_label.text != "":
		telegraph_label.modulate.a = max(0.0, telegraph_label.modulate.a - delta * 1.2)
		if telegraph_label.modulate.a <= 0.05:
			telegraph_label.text = ""
	if impact_flash.modulate.a > 0.0:
		impact_flash.modulate.a = max(0.0, impact_flash.modulate.a - delta * 3.2)

func _decay_animation_params(delta: float) -> void:
	player_lunge = move_toward(player_lunge, 0.0, 220.0 * delta)
	enemy_lunge = move_toward(enemy_lunge, 0.0, 220.0 * delta)
	player_hit_bump = move_toward(player_hit_bump, 0.0, 260.0 * delta)
	enemy_hit_bump = move_toward(enemy_hit_bump, 0.0, 260.0 * delta)
	player_scale_boost = move_toward(player_scale_boost, 0.0, 2.8 * delta)
	enemy_scale_boost = move_toward(enemy_scale_boost, 0.0, 2.8 * delta)

func _finish_fight() -> void:
	RunManager.player_stats["hp"] = player.hp
	RunManager.player_stats["stamina"] = player.stamina
	RunManager.player_stats["guard"] = player.guard
	RunManager.on_fight_finished(player.hp > 0.0)
	if player.hp > 0.0:
		get_tree().change_scene_to_file("res://scenes/RewardScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
