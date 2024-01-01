extends Resource
class_name LdStream

@export var name: String
@export var audio_stream: AudioStream
@export var time: float = 0.0
@export_range(0.0, 1.5, 0.01) var vol: float = 1.0
@export var group: String

@export_category("Interactive Audio Data")
@export var queueable: bool = false
@export var allow_dupes: bool = false

var player: AudioStreamPlayer
var playback_stream: AudioStreamPlaybackPolyphonic
var playback_id: int
var queueable_ids: Array[int]
var timer: Timer
var max_vol: float
var volume_db: float:
	set(db):
		if playback_stream:
			if not allow_dupes:
				if playback_stream.is_stream_playing(playback_id):
					playback_stream.set_stream_volume(playback_id, db)
			else:
				for id in queueable_ids:
					if playback_stream.is_stream_playing(id):
						playback_stream.set_stream_volume(id, db)
					else:
						queueable_ids.erase(id)
		volume_db = db
var connected: float
var variant_i: int

func play(from_position: float = 0.0):
	if playback_stream:
		if queueable and allow_dupes:
			queueable_ids.append(playback_stream.play_stream(audio_stream,from_position,volume_db))
		else:
#			if playback_stream.is_stream_playing(playback_id): 
#				playback_stream.stop_stream(playback_id)
			playback_id = playback_stream.play_stream(audio_stream,from_position,volume_db)

func stop():
	if playback_stream:
		if queueable and allow_dupes:
			for id in queueable_ids:
				if playback_stream.is_stream_playing(id):
					playback_stream.stop_stream(id)
			queueable_ids.clear()
		else:
			if playback_stream.is_stream_playing(playback_id):
				print("Stop stream")
				playback_stream.stop_stream(playback_id)
