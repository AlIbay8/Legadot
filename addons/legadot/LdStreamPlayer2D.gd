extends LdStreamPlayer
class_name LdStreamPlayer2D

func init_stream_players_node() -> void:
	var stream_players_node: Node = Node2D.new()
	stream_players_node.name = "StreamPlayers"
	self.add_child(stream_players_node)
	self.stream_players = stream_players_node

func get_player_template() -> Node:
	var player_node: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	for child in self.get_children():
		if child is AudioStreamPlayer2D:
			player_node = child.duplicate()
			child.queue_free()
			break
	return player_node
