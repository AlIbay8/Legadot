extends AudioStreamPlayer

var a_stream: AudioStream = load("res://tutorial_test.wav")

var playback: AudioStreamPlaybackPolyphonic
var id: int
# Called when the node enters the scene tree for the first time.
func _ready():
	self.play()
	playback = self.get_stream_playback()
	id = playback.play_stream(a_stream)
	await get_tree().create_timer(12.7).timeout
	if playback.is_stream_playing(id): playback.stop_stream(id)
	id = playback.play_stream(a_stream, 0.0)
