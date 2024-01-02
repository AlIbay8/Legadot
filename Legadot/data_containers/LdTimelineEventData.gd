extends Resource
class_name LdTimelineEvent

@export var time: float
@export var streams: Array = []
@export var transition: LdTransition
@export var bpm: LdBpm
@export var section: String
@export var event: LdEvent
@export var timer: Timer

func _init(event_time: float=0.0):
	self.time = event_time

func trigger_event(playlist: LdStreamPlayer, offset: float = -1.0, check_end: bool = true):
	if offset<0.0:
		offset = 0.0
		if transition:
			var transitioned: bool = playlist.check_h_transition(transition)
			if transitioned: return
	
	if event:
		playlist.event_reached.emit(event.event_name)
		if event.has_method("custom_event"):
			event.custom_event(playlist)
	if section!="":
		playlist.current_section = section
	if bpm:
		playlist.current_beats_in_measure = bpm.beats_in_measure
		playlist.current_beat_value = bpm.beat_value
	for s in streams:
		playlist.active_players+=1
		s.play(offset)
	
	if check_end:
		playlist.check_end(time)
