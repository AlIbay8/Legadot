extends LdAction
class_name LdHStateAction

@export var h_state: String
@export var auto_play: bool = false
@export var await_transition: bool = false

func trigger_action(ld_player: LdStreamPlayer):
	if await_transition:
		await ld_player.set_h_state(h_state, auto_play)
	else:
		ld_player.set_h_state(h_state, auto_play)
	return
