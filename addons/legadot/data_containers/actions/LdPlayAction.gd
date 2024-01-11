extends LdAction
class_name LdPlayAction

@export var from_position: float = 0.0
@export var from_sect: String

func trigger_action(ld_player: LdStreamPlayer):
	if from_sect!="":
		ld_player.play_from_sect(from_sect)
	else:
		ld_player.play(from_position if from_position>=0.0 else ld_player.sec_position)
	return
