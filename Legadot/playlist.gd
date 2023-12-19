extends Node2D

@export var tutorial_stream: AudioStreamPlayer
@export var game_stream: AudioStreamPlayer

var test_timeline: Dictionary = {
	"1.25": {
		"stream": "first"
	},
	"3.87": {
		"stream": "second"
	}
}
# Called when the node enters the scene tree for the first time.
func _ready():
#	tutorial_stream.play(12.8)
#	game_stream.play(-12.8)
	play_new(tutorial_stream)
	play_new(game_stream, -12.8)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func play_new(stream: AudioStreamPlayer, time: float = 0.0):
	if time<0.0:
		await get_tree().create_timer(abs(time+AudioServer.get_time_to_next_mix())).timeout
		stream.play(0.0)
	else:
		stream.play(time)

