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
			var transitioned: bool = playlist.check_h_transition(transition, time)
			if transitioned: return
	if streams.size()>0:
		playlist.set_tracker_stream(get_longest_stream())
	if event and offset<=0.0:
		playlist.event_reached.emit(event.event_name)
		if event.has_method("custom_event"):
			event.custom_event(playlist)
		if event.action_set:
			event.action_set.trigger_actions(playlist)
	if section!="":
		playlist.current_section = section
	if bpm:
		playlist.current_beats_in_measure = bpm.beats_in_measure
		playlist.current_beat_value = bpm.beat_value
	for s in streams:
		s.play(offset)
	
	if check_end:
		playlist.check_end(time)

func get_longest_stream() -> LdStream:
	var long_stream: LdStream
	var stream_len: float = 0.0
	for s in streams:
		if s is LdStream:
			if not s.queueable:
				var len: float = s.audio_stream.get_length()
				if len>stream_len and s.player:
					stream_len=len
					long_stream=s
	return long_stream if long_stream else null
