extends LdStreamPlayer
class_name LdStreamPlayer3D

func get_player_template():
	var player_node: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	for child in self.get_children():
		if child is AudioStreamPlayer3D:
			player_node = child.duplicate()
			break
	return player_node
