extends Resource
class_name LdPlaylistData

@export var playlist_name: String
@export var streams: Array[LdStream]
@export var bpm_times: Array[LdBpm]

@export_category("Vertical Remixing")
@export var vertical_states: Array[LdVerticalState]
@export var fade_length: float

@export_category("Horizontal Remixing")
@export var sections: Array[LdSection]
@export var transitions: Array[LdTransition]
