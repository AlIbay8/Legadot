extends Resource
class_name LdActionSet

@export var action_set_name: String
@export var actions: Array[LdAction]
@export var cancel_on_new_set: bool = false
var local_password: float
var ld_stream_player: LdStreamPlayer

func trigger_actions(ld_player: LdStreamPlayer):
	ld_stream_player = ld_player
	self.local_password = Time.get_unix_time_from_system()
	ld_player.coroutine_password = self.local_password
	
	for action in actions:
		if is_password_valid():
			if action.has_method("trigger_action"):
				await action.trigger_action(ld_player)
		else:
			break
	if local_password == ld_stream_player.coroutine_password:
		ld_player.coroutine_password = 0.0

func is_password_valid() -> bool:
	if not cancel_on_new_set: return true
	if local_password == ld_stream_player.coroutine_password:
		return true
	else:
		return false
	
