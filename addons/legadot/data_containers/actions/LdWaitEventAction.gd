extends LdAction
class_name LdWaitEventAction

@export var event_name: String

func trigger_action(ld_player: LdStreamPlayer):
	await ld_player.wait_for_event(event_name)
	return
