extends Control

@onready var move_list: ItemList = %MoveList
@onready var combo_option: OptionButton = %ComboOption
@onready var slot_option: OptionButton = %SlotOption
@onready var risk_label: Label = %RiskLabel
@onready var stats_label: Label = %StatsLabel
@onready var rule_list: ItemList = %RuleList
@onready var combo_preview: Label = %ComboPreview

const SLOTS = ["opener", "link1", "link2", "finisher"]

func _ready() -> void:
	for id in RunManager.available_moves:
		move_list.add_item(id)
	for c in RunManager.selected_combos.keys():
		combo_option.add_item(c)
	for s in SLOTS:
		slot_option.add_item(s)
	if combo_option.item_count > 0:
		combo_option.select(0)
	if slot_option.item_count > 0:
		slot_option.select(0)
	if not combo_option.item_selected.is_connected(_on_combo_selected):
		combo_option.item_selected.connect(_on_combo_selected)
	_refresh_rules()
	_refresh_stats()
	%AssignButton.pressed.connect(_assign_move)
	%StartFightButton.pressed.connect(_start_fight)

func _on_combo_selected(_i: int) -> void:
	_refresh_stats()

func _refresh_stats() -> void:
	var ps: Dictionary = RunManager.player_stats
	stats_label.text = "HP %d/%d | STA %.0f/%.0f | GRD %.0f/%.0f | Dmg x%.2f (+L %.0f%% / +H %.0f%%)" % [
		int(ps.get("hp", 0.0)), int(ps.get("max_hp", 0.0)),
		float(ps.get("stamina", 0.0)), float(ps.get("max_stamina", 0.0)),
		float(ps.get("guard", 0.0)), float(ps.get("max_guard", 0.0)),
		float(ps.get("damage_multiplier", 1.0)),
		float(ps.get("light_damage_bonus", 0.0)) * 100.0,
		float(ps.get("heavy_damage_bonus", 0.0)) * 100.0
	]
	var combo_name := _selected_combo_name()
	var chain: Array = RunManager.selected_combos.get(combo_name, [])
	var total_damage := 0.0
	var total_recovery := 0
	for m in chain:
		var d: Dictionary = RunManager.all_moves.get(m, {})
		total_damage += float(d.get("damage", 0))
		total_recovery += int(d.get("recovery_frames", 0))
	risk_label.text = "Risk/Reward → Damage %.0f, Recovery %d" % [total_damage, total_recovery]
	combo_preview.text = "%s: %s" % [combo_name, " -> ".join(chain)]

func _refresh_rules() -> void:
	rule_list.clear()
	for r in RunManager.behavior_rules:
		rule_list.add_item("%s => %s" % [r.get("id", ""), r.get("action", "")])

func _assign_move() -> void:
	if move_list.get_selected_items().is_empty():
		return
	var move_id := move_list.get_item_text(move_list.get_selected_items()[0])
	var combo := _selected_combo_name()
	var slot := clamp(slot_option.selected, 0, SLOTS.size() - 1)
	var chain: Array = RunManager.selected_combos.get(combo, []).duplicate()
	while chain.size() < SLOTS.size():
		chain.append(move_id)
	chain[slot] = move_id
	if _combo_is_valid(chain):
		RunManager.selected_combos[combo] = chain
		risk_label.modulate = Color.WHITE
	else:
		risk_label.text = "Invalid link: combo_rules violated"
		risk_label.modulate = Color(1.0, 0.4, 0.4)
	_refresh_stats()

func _combo_is_valid(chain: Array) -> bool:
	for i in range(chain.size() - 1):
		var now: Dictionary = RunManager.all_moves.get(chain[i], {})
		var nxt: Dictionary = RunManager.all_moves.get(chain[i + 1], {})
		var allowed: Array = now.get("combo_rules", [])
		if allowed.is_empty():
			continue
		var ok := false
		for tag in nxt.get("tags", []):
			if allowed.has(tag):
				ok = true
				break
		if not ok:
			return false
	return true

func _selected_combo_name() -> String:
	if combo_option.item_count <= 0:
		push_warning("PreparationScreen: no combos available, fallback to default")
		return "default"
	var selected := clamp(combo_option.selected, 0, combo_option.item_count - 1)
	return combo_option.get_item_text(selected)

func _start_fight() -> void:
	if RunManager.enemies.is_empty():
		push_error("PreparationScreen: cannot start fight, no enemies loaded.")
		return
	get_tree().change_scene_to_file("res://scenes/FightScreen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_fight()
