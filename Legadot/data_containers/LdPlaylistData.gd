extends Resource
class_name LdPlaylistData

@export var playlist_name: String
@export var streams: Array[LdStream]

@export var end_time: float = 0.0
@export var loop: bool = false
@export var loop_offset: float = 0.0

@export_subgroup("Vertical Remixing")
@export var vertical_states: Array[LdVerticalState]
@export var fade_length: float

@export_subgroup("Horizontal Remixing")
@export var sections: Array[LdSection]
@export var transitions: Array[LdTransition]

@export_subgroup("Interactive Audio")
@export var bpm_times: Array[LdBpm]
@export var count_subdivision: int = 1

@export_subgroup("Events")
@export var events: Array[LdEvent]

@export_subgroup("Defaults")
@export var default_v_state: String
@export var default_h_state: String
