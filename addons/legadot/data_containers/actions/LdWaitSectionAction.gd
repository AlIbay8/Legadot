extends LdAction
class_name LdWaitSectionAction

@export var section_name: String
@export var fire_in_middle: bool = false

func trigger_action(ld_player: LdStreamPlayer):
	await ld_player.wait_for_section(section_name, fire_in_middle)
	return
