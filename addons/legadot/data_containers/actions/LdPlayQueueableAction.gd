extends LdAction
class_name LdPlayQueueableAction

@export var queueable_name: String
@export var wait_beat: float = 1.0

func trigger_action(ld_player: LdStreamPlayer):
	ld_player.play_queueable(queueable_name, wait_beat)
	return
