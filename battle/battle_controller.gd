extends Control

@onready var arena: Control = %Arena
@onready var player_sprite: ColorRect = %PlayerFighter
@onready var enemy_sprite: ColorRect = %EnemyFighter
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
var distance := 180.0
var frame_acc := 0.0
var hit_stop_timer := 0.0
const FRAME_TIME := 0.08
var pending_hit: Dictionary = {}
var enemy_pending_hit: Dictionary = {}
var shake_power := 0.0
var shake_timer := 0.0
var arena_origin := Vector2.ZERO

func _ready() -> void:
	add_child(player)
	add_child(enemy)
	arena_origin = arena.position
	RunManager.fight_requested.connect(_on_fight_requested)
	FXManager.combat_log.connect(_append_log)
	FXManager.hit_stop.connect(_on_hit_stop)
	FXManager.camera_shake.connect(_on_camera_shake)
	FXManager.telegraph_flash.connect(_on_telegraph_flash)
	RunManager.start_next_fight()

func _process(delta: float) -> void:
	_update_fx(delta)
	if hit_stop_timer > 0.0:
		hit_stop_timer -= delta
		return
	if player.hp <= 0 or enemy.hp <= 0:
		_finish_fight()
		set_process(false)
		return
	frame_acc += delta
	if frame_acc < FRAME_TIME:
		return
	frame_acc = 0.0
	player.tick_regen(FRAME_TIME)
	enemy.tick_regen(FRAME_TIME)
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
	if e_state.get("phase") == "active_start":
		enemy_pending_hit = {"attacker": enemy, "defender": player, "move": e_state["move"]}

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
		"block":
			player.force_block()
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
				if player.enter_move(_tuned_move(move_data, true)):
					player.combo_index += 1
					_append_log("Player uses %s" % move_data.get("name", move_id))

func _take_enemy_action() -> void:
	var move_id := enemy_ai.pick_move(enemy, player, enemy_data, RunManager.all_moves, distance)
	if move_id == "":
		return
	var data: Dictionary = RunManager.all_moves.get(move_id, {})
	if enemy.enter_move(data):
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

	var punished := attacker.is_player and defender.just_whiffed_punishable
	var result = defender.take_hit(move, blocked, punished)
	FXManager.emit_hit_stop(0.07 if move.get("tags", []).has("heavy") else 0.04)
	FXManager.emit_camera_shake(9.0 if move.get("tags", []).has("heavy") else 4.0, 0.10)

	var line: String
	if blocked:
		line = "%s blocks %s (%s) %.1f"
		_append_log(line % [defender.fighter_name, attacker.fighter_name, move.get("name", "move"), result.get("damage", 0.0)])
	else:
		line = "%s hits %s with %s for %.1f"
		_append_log(line % [attacker.fighter_name, defender.fighter_name, move.get("name", "move"), result.get("damage", 0.0)])
	if result.get("guard_break", false):
		_append_log("[color=yellow]GUARD BREAK![/color] %s is vulnerable." % defender.fighter_name)
	if result.get("stagger", false):
		_append_log("[color=red]STAGGER![/color] %s can be punished." % defender.fighter_name)

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
	player_sprite.position.x = lerp(360.0, 560.0, 1.0 - t)
	enemy_sprite.position.x = lerp(820.0, 640.0, 1.0 - t)
	player_sprite.color = Color("5cc8ff") if player.state != Fighter.State.STAGGER else Color("ffd166")
	enemy_sprite.color = Color("ff6b6b") if enemy.state != Fighter.State.STAGGER else Color("ffd166")
	if player.state == Fighter.State.STARTUP:
		player_sprite.scale = Vector2(1.1, 1.1)
	else:
		player_sprite.scale = Vector2.ONE
	if enemy.state == Fighter.State.STARTUP:
		enemy_sprite.scale = Vector2(1.1, 1.1)
	else:
		enemy_sprite.scale = Vector2.ONE

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

func _finish_fight() -> void:
	RunManager.player_stats["hp"] = player.hp
	RunManager.player_stats["stamina"] = player.stamina
	RunManager.player_stats["guard"] = player.guard
	RunManager.on_fight_finished(player.hp > 0.0)
	if player.hp > 0.0:
		get_tree().change_scene_to_file("res://scenes/RewardScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
