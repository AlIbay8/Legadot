extends Control
class_name LdDebugMenu

@onready var debug_label = $MarginContainer/VBoxContainer/DebugLabel
@onready var time_label = $MarginContainer/VBoxContainer/TimeLabel
@onready var play_button = $MarginContainer/VBoxContainer/SongControls/PlayButton
@onready var pause_button = $MarginContainer/VBoxContainer/SongControls/PauseButton
@onready var stop_button = $MarginContainer/VBoxContainer/SongControls/StopButton
@onready var song_progress = $MarginContainer/VBoxContainer/SongControls/HBoxContainer/VBoxContainer/SongProgress
@onready var vertical_option = $MarginContainer/VBoxContainer/VerticalHorizontalControlsContainter/VerticalOption
@onready var horizontal_option = $MarginContainer/VBoxContainer/VerticalHorizontalControlsContainter/HorizontalOption
@onready var streams_container = $MarginContainer/VBoxContainer/StreamControls/StreamsScrollContainer/StreamsContainer
@onready var groups_container = $MarginContainer/VBoxContainer/GroupControls/GroupsScrollContainer/GroupsContainer
@onready var queueables_list = $MarginContainer/VBoxContainer/QueueablesContainer/QueuablesScrollContainer/QueueablesList
@onready var actions_list = $MarginContainer/VBoxContainer/ActionsContainer/ActionsScrollContainer/ActionsList
@onready var beat_label = $MarginContainer/VBoxContainer/BeatLabel

var stream_toggles: Dictionary
var group_toggles: Dictionary

var ld_player: LdStreamPlayer

signal stream_toggled(stream: String, button_pressed: bool)
signal group_toggled(group: String, button_pressed: bool)
signal queueable_pressed(queueable: String)
signal action_pressed(action_set: String)

# Called when the node enters the scene tree for the first time.
func _ready():
	var parent: Node = get_parent()
	if parent is LdStreamPlayer:
		ld_player = parent

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func init_debug_menu():
	if ld_player:
		init_vertical(ld_player.v_states)
		init_horizontal(ld_player.h_sections)
		init_stream_toggles(ld_player.stream_data)
		init_group_toggles(ld_player.groups)
		init_queueables(ld_player.stream_data)
		init_actions(ld_player.action_sets)

func init_vertical(v_state_data: Dictionary):
	vertical_option.clear()
	for v in v_state_data:
		vertical_option.add_item(v)

func init_horizontal(h_section_data: Dictionary):
	horizontal_option.clear()
	for h in h_section_data:
		horizontal_option.add_item(h)

func init_stream_toggles(stream_data: Dictionary):
	for stream in stream_data:
		var btn: CheckButton = CheckButton.new()
		btn.text = stream
		btn.set_pressed_no_signal(true)
		btn.toggled.connect(func(button_pressed:bool): stream_toggled.emit(stream,button_pressed))
		stream_toggles[stream] = btn
		streams_container.add_child(btn)

func init_group_toggles(group_data: Dictionary):
	for group in group_data:
		if group=="": continue
		var btn: CheckButton = CheckButton.new()
		btn.text = group
		btn.set_pressed_no_signal(false)
		btn.toggled.connect(func(button_pressed:bool): group_toggled.emit(group,button_pressed))
		group_toggles[group] = btn
		groups_container.add_child(btn)

func init_queueables(stream_data: Dictionary):
	for s in stream_data:
		if stream_data[s].queueable:
			var btn: Button = Button.new()
			btn.text = s
			queueables_list.add_child(btn)
			btn.pressed.connect(func(): queueable_pressed.emit(s))

func init_actions(action_set_data):
	for a in action_set_data:
		var btn: Button = Button.new()
		btn.text = a
		actions_list.add_child(btn)
		btn.pressed.connect(func(): action_pressed.emit(a))

func time_convert(time_in_sec: float):
	var milliseconds = int(fmod(time_in_sec, 1.0)*100)
	var seconds = int(time_in_sec)%60
	var minutes = int(int(time_in_sec)/60.0)%60
	
	#returns a string with the format "MM:SS.MS"
	return "%02d:%02d.%02d" % [minutes, seconds, milliseconds]

