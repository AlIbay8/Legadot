extends LdAction
class_name LdHStateAction

@export var h_state: String
@export var auto_play: bool = false

func trigger_action(ld_player: LdStreamPlayer):
	ld_player.set_h_state(h_state, auto_play)
	return
