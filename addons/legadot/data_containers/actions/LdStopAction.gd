extends LdAction
class_name LdStopAction

@export_range(0.0,10.0,0.5) var fade_length: float = 0.0
@export var reset_position: bool = true

func trigger_action(ld_player: LdStreamPlayer):
	if fade_length==0.0:
		ld_player.stop(false, reset_position)
	else:
		ld_player.fade_playlist(0.0, true, fade_length)
	return
