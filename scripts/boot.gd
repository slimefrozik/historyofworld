## Boot: jumps to main menu.
extends Node

func _ready() -> void:
	# Wait one frame so autoloads finish initializing.
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
