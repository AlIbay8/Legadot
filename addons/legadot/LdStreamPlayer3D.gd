extends LdStreamPlayer
class_name LdStreamPlayer3D

func init_stream_players_node():
	var stream_players_node: Node = Node3D.new()
	stream_players_node.name = "StreamPlayers"
	self.add_child(stream_players_node)
	self.stream_players = stream_players_node

func get_player_template():
	var player_node: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	for child in self.get_children():
		if child is AudioStreamPlayer3D:
			player_node = child.duplicate()
			break
	return player_node
