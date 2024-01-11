extends LdAction
class_name LdFadeStreamAction

@export var stream_name: String
@export var vol: float
@export var fade_length: float = -1.0
@export var await_finish: bool = false

func trigger_action(ld_player: LdStreamPlayer):
	if await_finish:
		await ld_player.fade_stream(vol, stream_name, fade_length)
	else:
		ld_player.fade_stream(vol, stream_name, fade_length)
	return
