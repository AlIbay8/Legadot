@tool
extends EditorPlugin


func _enter_tree():
	# Initialization of the plugin goes here.
	add_custom_type("LdStreamPlayer", "Node", preload("res://addons/legadot/LdStreamPlayer.gd"), preload("res://icon.svg"))
	pass


func _exit_tree():
	remove_custom_type("LegadotStreamPlayer")
	# Clean-up of the plugin goes here.
	pass
