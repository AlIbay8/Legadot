extends Control
class_name LdDebugMenu

@onready var debug_label: Label = $MarginContainer/VBoxContainer/DebugLabel as Label
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel as Label
@onready var play_button: Button = $MarginContainer/VBoxContainer/SongControls/PlayButton as Button
@onready var pause_button: Button = $MarginContainer/VBoxContainer/SongControls/PauseButton as Button
@onready var stop_button: Button = $MarginContainer/VBoxContainer/SongControls/StopButton as Button
@onready var song_progress: HSlider = $MarginContainer/VBoxContainer/SongControls/HBoxContainer/VBoxContainer/SongProgress as HSlider
@onready var vertical_option: OptionButton = $MarginContainer/VBoxContainer/VerticalHorizontalControlsContainter/VerticalOption as OptionButton
@onready var horizontal_option: OptionButton = $MarginContainer/VBoxContainer/VerticalHorizontalControlsContainter/HorizontalOption as OptionButton
@onready var streams_container: HBoxContainer = $MarginContainer/VBoxContainer/StreamControls/StreamsScrollContainer/StreamsContainer as HBoxContainer
@onready var groups_container: HBoxContainer = $MarginContainer/VBoxContainer/GroupControls/GroupsScrollContainer/GroupsContainer as HBoxContainer
@onready var queueables_list: HBoxContainer = $MarginContainer/VBoxContainer/QueueablesContainer/QueuablesScrollContainer/QueueablesList as HBoxContainer
@onready var actions_list: HBoxContainer = $MarginContainer/VBoxContainer/ActionsContainer/ActionsScrollContainer/ActionsList as HBoxContainer
@onready var beat_label: Label = $MarginContainer/VBoxContainer/BeatLabel as Label


var vertical_states: Array[String]
var horizontal_states: Array[String]
var stream_toggles: Dictionary
var group_toggles: Dictionary

var ld_player: LdStreamPlayer


signal play_pressed()
signal pause_pressed()
signal stop_pressed()
signal v_changed(vertical_state: String)
signal h_changed(horizontal_state: String)
signal progress_seeked(pos: float)
signal stream_toggled(stream: String, button_pressed: bool)
signal group_toggled(group: String, button_pressed: bool)
signal queueable_pressed(queueable: String)
signal action_pressed(action_set: String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var parent: Node = get_parent()
	if parent is LdStreamPlayer:
		ld_player = parent

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta) -> void:
	if ld_player and ld_player.is_playing:
		update_time()

func init_debug_menu() -> void:
	if ld_player:
		init_vertical(ld_player.v_states)
		init_horizontal(ld_player.h_sections, ld_player.h_names)
		init_stream_toggles(ld_player.stream_data)
		init_group_toggles(ld_player.groups)
		init_queueables(ld_player.stream_data)
		init_actions(ld_player.action_sets)

func init_vertical(v_state_data: Dictionary) -> void:
	vertical_option.clear()
	for v in v_state_data:
		vertical_states.append(v)
		vertical_option.add_item(v)
	vertical_option.select(-1)

func init_horizontal(h_section_data: Dictionary, custom_names: Array) -> void:
	horizontal_option.clear()
	for h_name in custom_names:
		horizontal_states.append(h_name)
		horizontal_option.add_item(h_name)
	for h in h_section_data:
		horizontal_states.append(h)
		horizontal_option.add_item(h)
	horizontal_option.select(-1)

func init_stream_toggles(stream_data: Dictionary) -> void:
	for stream in stream_data:
		var btn: CheckButton = CheckButton.new()
		btn.text = stream
		btn.set_pressed_no_signal(true)
		btn.toggled.connect(func(button_pressed:bool): stream_toggled.emit(stream,button_pressed))
		stream_toggled.connect(func(stream, active): ld_player.fade_stream(1.0 if active else 0.0, stream))
		stream_toggles[stream] = btn
		streams_container.add_child(btn)

func init_group_toggles(group_data: Dictionary) -> void:
	for group in group_data:
		if group=="": continue
		var btn: CheckButton = CheckButton.new()
		btn.text = group
		btn.set_pressed_no_signal(false)
		btn.toggled.connect(func(button_pressed:bool): group_toggled.emit(group,button_pressed))
		group_toggled.connect(func(group, active): ld_player.fade_group(1.0 if active else 0.0, group))
		group_toggles[group] = btn
		groups_container.add_child(btn)

func init_queueables(stream_data: Dictionary) -> void:
	for s in stream_data:
		if stream_data[s].queueable:
			var btn: Button = Button.new()
			btn.text = s
			queueables_list.add_child(btn)
			btn.pressed.connect(func(): queueable_pressed.emit(s))
	queueable_pressed.connect(ld_player.play_queueable.bind(1.0/ld_player.playlist_data.count_subdivision))

func init_actions(action_set_data) -> void:
	for a in action_set_data:
		var btn: Button = Button.new()
		btn.text = a
		actions_list.add_child(btn)
		btn.pressed.connect(func(): action_pressed.emit(a))
	action_pressed.connect(ld_player.start_action_set)

func v_select(v_state: String) -> void:
	if v_state in vertical_states:
		vertical_option.select(vertical_states.find(v_state))
	else:
		vertical_option.select(-1)

func h_select(h_state: String) -> void:
	if h_state in horizontal_states:
		horizontal_option.select(horizontal_states.find(h_state))
	else:
		horizontal_option.select(-1)

func update_time() -> void:
	if time_label:
		time_label.text = time_convert(ld_player.sec_position) + ", " + str(ld_player.raw_beat_position)
	if song_progress:
		song_progress.value = ld_player.sec_position

func time_convert(time_in_sec: float) -> String:
	var milliseconds = int(fmod(time_in_sec, 1.0)*100)
	var seconds = int(time_in_sec)%60
	var minutes = int(int(time_in_sec)/60.0)%60
	
	#returns a string with the format "MM:SS.MS"
	return "%02d:%02d.%02d" % [minutes, seconds, milliseconds]

func set_debug_label(section: String, beat_pos: float) -> void:
	if debug_label:
		debug_label.text = section + ", " + str(beat_pos)

func set_beat_label(measure_count: int, beat: float, beats_in_measure: int, beat_value: int) -> void:
	if beat_label:
		beat_label.text = "Measure, Beat, Time Signature: {msr}, {bt}, {bim}/{bv}".format({"msr": measure_count, "bt": beat, "bim": beats_in_measure, "bv":beat_value})

func _on_play_button_pressed() -> void:
	play_pressed.emit()
	if ld_player.is_playing:
		ld_player.play(0.0)
	else:
		ld_player.play(ld_player.sec_position)

func _on_pause_button_pressed() -> void:
	pause_pressed.emit()
	ld_player.pause()

func _on_stop_button_pressed() -> void:
	stop_pressed.emit()
	ld_player.stop()
	update_time()

func _on_song_progress_drag_started() -> void:
	var was_playing: bool = false
	if ld_player.is_playing:
		was_playing = true
		ld_player.pause()
		
	await song_progress.drag_ended
	if was_playing:
		ld_player.play(song_progress.value)
	else:
		ld_player.sec_position = song_progress.value
		if time_label:
			time_label.text = time_convert(ld_player.sec_position)

func _on_vertical_option_item_selected(index) -> void:
	v_changed.emit(vertical_option.get_item_text(index))
	ld_player.set_v_state(vertical_option.get_item_text(index))

func _on_horizontal_option_item_selected(index) -> void:
	h_changed.emit(horizontal_option.get_item_text(index))
	ld_player.set_h_state(horizontal_option.get_item_text(index))
