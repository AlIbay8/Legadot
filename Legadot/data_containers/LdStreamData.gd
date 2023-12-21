extends Resource
class_name LdStream

@export var name: String
@export var audio_stream: AudioStream
@export var time: float = 0.0
@export_range(0.0, 1.5, 0.1) var vol: float = 1.0
@export var group: String

@export_category("Interactive Audio Data")
@export var queueable: bool = false
@export var allow_dupes: bool = false
