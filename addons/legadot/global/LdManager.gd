extends Node
class_name LdManager

var playlists: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func add_playlist(playlist_name: String, player_node: LdStreamPlayer):
	playlists[playlist_name] = player_node

func remove_playlist(playlist_name: String):
	playlists.erase(playlist_name)
