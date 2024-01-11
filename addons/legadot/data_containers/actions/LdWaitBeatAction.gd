extends LdAction
class_name LdWaitBeatAction

@export var beat: float = 1.0

func trigger_action(ld_player: LdStreamPlayer):
	await ld_player.wait_for_beat(beat)
	return
