extends LdAction
class_name LdVStateAction

@export var v_state: String
@export_range(-1.0, 20.0, 0.05) var fade_length: float = -1.0
@export var toggle_state: bool = false
@export var await_finish: bool = false

func trigger_action(ld_player: LdStreamPlayer):
	print("triggered v state")
	if not toggle_state:
		if await_finish: 
			await ld_player.set_v_state(v_state, fade_length)
		else:
			ld_player.set_v_state(v_state, fade_length)
	else:
		if await_finish:
			await ld_player.toggle_v_state(v_state, fade_length)
		else:
			ld_player.toggle_v_state(v_state, fade_length)
	return
