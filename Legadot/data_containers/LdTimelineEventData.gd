extends Resource
class_name LdTimelineEvent

@export var streams: Array = []
@export var transition: LdTransition
@export var bpm: float
@export var section: String
@export var timer: Timer

func trigger_event(playlist: LdPlaylist, offset: float = -1.0):
	if offset<0.0:
		offset = 0.0
		if transition:
			var transitioned: bool = playlist.check_h_transition(transition)
			if transitioned: return
		
	if section!="":
		playlist.current_section = section
	for s in streams:
		s.player.play(offset)
