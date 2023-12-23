extends Resource
class_name LdTimelineEvent

@export var streams: Array = []
@export var transition: LdTransition
@export var bpm: LdBpm
@export var section: String
@export var timer: Timer

func trigger_event(playlist: LdPlaylist, offset: float = -1.0, check_end: bool = true):
	if offset<0.0:
		offset = 0.0
		if transition:
			var transitioned: bool = playlist.check_h_transition(transition)
			if transitioned: return
		
	if section!="":
		playlist.current_section = section
	if bpm:
		playlist.current_beats_in_measure = bpm.beats_in_measure
	for s in streams:
		playlist.active_players+=1
		s.player.play(offset)
	
	if check_end:
		playlist.check_end("timer")
