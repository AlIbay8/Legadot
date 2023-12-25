extends Resource
class_name LdPlaylistData

@export var playlist_name: String
@export var streams: Array[LdStream]
@export var bpm_times: Array[LdBpm]
@export var end_time: float = 0.0
@export var loop: bool = false
@export var loop_offset: float = 0.0

@export_category("Vertical Remixing")
@export var vertical_states: Array[LdVerticalState]
@export var fade_length: float

@export_category("Horizontal Remixing")
@export var sections: Array[LdSection]
@export var transitions: Array[LdTransition]

@export_category("Interactive Audio")
@export var count_subdivision: int = 1

@export_category("Events")
@export var events: Array[LdEvent]

@export_category("Defaults")
@export var default_v_state: String
@export var default_h_state: String
