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
var timer: Timer
var max_vol: float
var connected: float
var variant_i: int

func play(from_position: float = 0.0):
	if queueable:
		if not player.playing:
			player.play()
		elif not allow_dupes:
			player.play()
		var playback: AudioStreamPlayback = player.get_stream_playback()
		if not playback:
			player.stream = AudioStreamPolyphonic.new()
			playback = player.get_stream_playback()
	
		if playback is AudioStreamPlaybackPolyphonic:
			playback.play_stream(audio_stream,from_position)
	else:
		player.play(from_position)
	
