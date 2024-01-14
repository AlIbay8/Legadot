extends LdAction
class_name LdWaitSectionAction

@export var section_names: String
@export var fire_in_middle: bool = false

func trigger_action(ld_player: LdStreamPlayer):
	await ld_player.wait_for_section(section_names, fire_in_middle)
	return
