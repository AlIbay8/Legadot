@tool
extends EditorPlugin

const AUTOLOAD_NAME = "Legadot"
const BASE_CLASS_NAME = "LdStreamPlayer"

func _enter_tree():
	# Initialization of the plugin goes here.
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/legadot/global/LdManager.gd")
	add_custom_type(BASE_CLASS_NAME, "Node", preload("res://addons/legadot/LdStreamPlayer.gd"), preload("res://addons/legadot/icons/icon.svg"))

func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_autoload_singleton(AUTOLOAD_NAME)
	remove_custom_type(BASE_CLASS_NAME)
