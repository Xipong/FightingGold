extends Node
class_name Fighter

enum State { IDLE, STARTUP, ACTIVE, RECOVERY, BLOCKSTUN, HITSTUN, STAGGER, DODGE, GUARD_BREAK }

signal action_state_changed(new_state: int)

var fighter_name := ""
var is_player := false
var hp := 100.0
var max_hp := 100.0
var stamina := 100.0
var max_stamina := 100.0
var stamina_regen := 10.0
var guard := 50.0
var max_guard := 50.0
var guard_regen := 5.0
var poise := 30.0
var damage_multiplier := 1.0
var punish_bonus := 1.0

var state: State = State.IDLE
var frame_timer := 0
var current_move: Dictionary = {}
var combo_name := "default"
var combo_index := 0
var stunned := false
var telegraphing := false
var just_whiffed_punishable := false

func configure_from_stats(name: String, stats: Dictionary, as_player: bool) -> void:
	fighter_name = name
	is_player = as_player
	max_hp = float(stats.get("max_hp", 100))
	hp = float(stats.get("hp", max_hp))
	max_stamina = float(stats.get("max_stamina", 100))
	stamina = float(stats.get("stamina", max_stamina))
	stamina_regen = float(stats.get("stamina_regen", 10))
	max_guard = float(stats.get("max_guard", 50))
	guard = float(stats.get("guard", max_guard))
	guard_regen = float(stats.get("guard_regen", 5))
	poise = float(stats.get("poise", 30))
	damage_multiplier = float(stats.get("damage_multiplier", 1.0))
	punish_bonus = float(stats.get("punish_bonus", 1.0))

func is_action_locked() -> bool:
	return state in [State.STARTUP, State.ACTIVE, State.RECOVERY, State.BLOCKSTUN, State.HITSTUN, State.STAGGER, State.GUARD_BREAK, State.DODGE]

func can_act() -> bool:
	return state == State.IDLE

func tick_regen(delta: float) -> void:
	stamina = min(max_stamina, stamina + stamina_regen * delta)
	guard = min(max_guard, guard + guard_regen * delta)

func set_state(new_state: State, frames := 0) -> void:
	state = new_state
	frame_timer = frames
	action_state_changed.emit(state)

func enter_move(move_data: Dictionary) -> bool:
	var cost = float(move_data.get("stamina_cost", 0.0))
	if stamina < cost:
		return false
	stamina -= cost
	current_move = move_data
	telegraphing = move_data.get("telegraph", false)
	set_state(State.STARTUP, int(move_data.get("startup_frames", 8)))
	return true

func step_frames() -> Dictionary:
	just_whiffed_punishable = false
	if frame_timer > 0:
		frame_timer -= 1
	if frame_timer > 0:
		return {"phase":"none"}
	match state:
		State.STARTUP:
			telegraphing = false
			set_state(State.ACTIVE, int(current_move.get("active_frames", 4)))
			return {"phase":"active_start", "move": current_move}
		State.ACTIVE:
			var recovery = int(current_move.get("recovery_frames", 12))
			set_state(State.RECOVERY, recovery)
			return {"phase":"active_end", "move": current_move}
		State.RECOVERY:
			if current_move.get("on_whiff", "") == "punishable":
				just_whiffed_punishable = true
			set_state(State.IDLE)
			current_move = {}
			return {"phase":"recovered"}
		State.BLOCKSTUN, State.HITSTUN, State.STAGGER, State.GUARD_BREAK, State.DODGE:
			set_state(State.IDLE)
			return {"phase":"neutral"}
	return {"phase":"none"}

func take_hit(move_data: Dictionary, blocked: bool, context: Dictionary = {}) -> Dictionary:
	var result := {"hit": true, "blocked": blocked, "guard_break": false, "stagger": false, "damage": 0.0}
	var attack_multiplier := float(context.get("attack_multiplier", 1.0))
	var punish_multiplier := float(context.get("punish_multiplier", 1.0))
	var punished := bool(context.get("punished", false))
	if blocked:
		var guard_dmg = float(move_data.get("guard_damage", 8.0))
		guard -= guard_dmg
		var reduced = float(move_data.get("damage", 10.0)) * attack_multiplier * 0.35
		if stamina < 20.0:
			reduced *= 1.2
		hp -= reduced
		result.damage = reduced
		set_state(State.BLOCKSTUN, int(move_data.get("block_stun", 10)))
		if guard <= 0.0:
			guard = 0.0
			set_state(State.GUARD_BREAK, 25)
			result.guard_break = true
	else:
		var base = float(move_data.get("damage", 10.0)) * attack_multiplier
		if punished:
			base *= punish_multiplier
		hp -= base
		result.damage = base
		set_state(State.HITSTUN, int(move_data.get("hit_stun", 14)))
		poise -= float(move_data.get("poise_damage", 10.0))
		if poise <= 0:
			poise = max(15.0, poise + 35.0)
			set_state(State.STAGGER, 22)
			result.stagger = true
	hp = max(0.0, hp)
	return result

func force_dodge() -> bool:
	if stamina < 18.0:
		return false
	stamina -= 18.0
	set_state(State.DODGE, 12)
	return true

func force_block() -> bool:
	if stamina < 8.0:
		return false
	stamina -= 8.0
	set_state(State.BLOCKSTUN, 8)
	return true
