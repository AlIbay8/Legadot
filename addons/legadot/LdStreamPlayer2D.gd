extends LdStreamPlayer
class_name LdStreamPlayer2D

func get_player_template():
	var player_node: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	for child in self.get_children():
		if child is AudioStreamPlayer2D:
			player_node = child.duplicate()
			break
	return player_node
