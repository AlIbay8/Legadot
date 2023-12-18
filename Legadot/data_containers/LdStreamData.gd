extends Resource
class_name LdStream

@export var audio_stream: AudioStream
@export var time: float = 0.0
@export_range(0.0, 1.5, 0.1) var vol: float = 1.0
@export var groups: String
