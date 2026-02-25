extends Node
class_name FXManager

signal hit_stop(duration: float)
signal camera_shake(power: float, duration: float)
signal telegraph_flash(target: String)
signal combat_log(message: String)

func emit_hit_stop(duration := 0.05) -> void:
	hit_stop.emit(duration)

func emit_camera_shake(power := 6.0, duration := 0.12) -> void:
	camera_shake.emit(power, duration)

func emit_telegraph(target: String) -> void:
	telegraph_flash.emit(target)

func log_line(message: String) -> void:
	combat_log.emit(message)
