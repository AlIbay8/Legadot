extends Node2D
class_name LdPlaylist

@export var playlist_data: LdPlaylistData

@export var stream_players: Node2D
@export var timers: Node2D

var stream_data: Dictionary = {}
var groups: Dictionary = {}
var timeline: Dictionary = {}
var v_states: Dictionary = {}
var h_sections: Dictionary = {}
var bpms: Dictionary = {}
var bpm_times: Array
var event_names: Array

var is_playing: bool = false
var start_position: float = 0.0
var sec_position: float = 0.0
var beat_position: float = 0
var last_reported_beat: float = 0
var current_section: String = "":
	set(sect):
		self.section.emit(sect)
		current_section=sect
var current_beats_in_measure: int = 4
var current_beat_value: int = 4
var total_measures: int = 0

var playlist_vol: float = 1.0

@export var auto_start: bool = false

@export var v_state: String:
	set(state):
		if state in v_states:
			set_v_state(state)
		
@export var h_state: String:
	set(state):
		if state in h_sections:
			h_state = state

var tracker_timer: Timer
var longest_time: float = 0.0
var active_timers: int = 0
var active_players: int = 0

signal measure(beat_pos: float)
signal quarter_beat(beat_pos: float)
signal eighth_beat(beat_pos: float)
signal section(sect: String)
signal event_reached(event: String)
signal playlist_finished()

@export_category("Debug")
@export var debug_label: Label
@export var vertical_btn: OptionButton
@export var horizontal_btn: OptionButton
@export var queueables_list: HBoxContainer
@export var beat_label: Label

func _ready():
	init_playlist()

func init_playlist():
	if playlist_data:
		build_data()
		build_groups()
		build_timeline()
		assign_timers()
		build_v_states()
		build_h_sections()
		build_bpm()
		
		prepare_debug()
		
		if playlist_data.default_v_state!="":
			#v_state = playlist_data.default_v_state
			set_v_state(playlist_data.default_v_state,0.0)
		else:
			fade_playlist(1.0,false,0.0)
		
		if playlist_data.default_h_state!="":
			h_state = playlist_data.default_h_state
			await get_tree().create_timer(1.0).timeout
			set_h_state(playlist_data.default_h_state, auto_start)
		else:
			if not Engine.is_editor_hint():
				if auto_start and OS.get_name()!="Web":
					play(-1)
			else:
				stop()

func build_data():
	for stream in playlist_data.streams:
		add_stream(stream)

func add_stream(stream: LdStream):
	if stream.name != "":
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = AudioStreamPolyphonic.new() if stream.allow_dupes else stream.audio_stream
		player.set_bus("Music")
		
		stream.player = player
		stream.max_vol = stream.vol
		stream_data[stream.name] = stream
		check_longest_time(stream.time, stream.audio_stream)
		
		stream_players.add_child(player)

func check_longest_time(time: float, stream: AudioStream):
	var stream_length: float = 0.0
	if stream is AudioStreamRandomizer:
		for i in range(stream.streams_count):
			if stream.get_stream(i).get_length()>stream_length:
				stream_length = stream.get_stream(i).get_length()
	else:
		stream_length = stream.get_length()
	if time+stream_length>longest_time:
		longest_time = time+stream_length
	
func build_groups():
	for s in stream_data:
		var stream = stream_data[s]
		if not (stream.group in self.groups):
			self.groups[stream.group] = {
				"streams": [],
				"vol": 1.0
			}
		groups[stream.group].streams.append(stream)

func build_timeline():
	for s in stream_data:
		if stream_data[s].queueable: continue
		var s_time = stream_data[s].time
		if not (s_time in timeline):
			timeline[s_time] = LdTimelineEvent.new(s_time)
		timeline[s_time].streams.append(stream_data[s])
	
	for bpm in playlist_data.bpm_times:
		if not (bpm.time in timeline):
			timeline[bpm.time] = LdTimelineEvent.new(bpm.time)
		timeline[bpm.time].bpm = bpm
	
	for t in playlist_data.transitions:
		if not (t.time in timeline):
			timeline[t.time] = LdTimelineEvent.new(t.time)
		timeline[t.time].transition = t
	
	for sect in playlist_data.sections:
		if not (sect.time in timeline):
			timeline[sect.time] = LdTimelineEvent.new(sect.time)
		timeline[sect.time].section = sect.section_name
	
	for event in playlist_data.events:
		if not (event.time in timeline):
			timeline[event.time] = LdTimelineEvent.new(event.time)
		timeline[event.time].event = event
		if not event_names.has(event.event_name): event_names.append(event.event_name)
	
	var end: float = 0.0
	if playlist_data.end_time<=0.0:
		end = longest_time
		playlist_data.end_time = longest_time
		var timeline_times: Array = timeline.keys()
		timeline_times.sort()
		if end>timeline_times[-1]:
			timeline[end] = LdTimelineEvent.new(end)
		else:
			playlist_data.end_time = timeline_times[-1]
	else:
		end = playlist_data.end_time
		if not (end in timeline):
			timeline[end] = LdTimelineEvent.new(end)
	#print("end time: ", end, ", ", playlist_data.end_time)

func assign_timers():
	for e in timeline:
		var timer: Timer = Timer.new()
		timer.autostart=false
		timer.one_shot=true
		timeline[e].timer = timer
		timer.timeout.connect(timeline[e].trigger_event.bind(self))
		timers.add_child(timer)

func build_v_states():
	for v in playlist_data.vertical_states:
		v_states[v.state_name] = v

func build_h_sections():
	for h in playlist_data.sections:
		h_sections[h.section_name] = h.time

func build_bpm():
	for bpm in playlist_data.bpm_times:
		bpms[bpm.time] = bpm
		if !bpm_times.has(bpm.time):
			bpm_times.append(bpm.time)
	bpm_times.sort()
	bpm_times.reverse()
	
# Basic song functions
func play(from: float = 0.0):
	if is_playing:
		stop(true)
	is_playing = true
	start_position = from
	total_measures=0
	active_players=0
	active_timers=0
	var time_keys = timeline.keys()
	time_keys.sort()
	for time in time_keys:
		if time>from:
			timeline[time].timer.wait_time = time-from-AudioServer.get_time_to_next_mix()
			if timeline[time].timer.wait_time>=0.05:
				if not tracker_timer or timeline[time].timer.wait_time>tracker_timer.wait_time:
					tracker_timer = timeline[time].timer
				timeline[time].timer.start()
				self.active_timers+=1
			else:
				timeline[time].trigger_event(self, abs(from-time), false)
			continue
		elif (from-time)>=0.0:
			timeline[time].trigger_event(self, abs(from-time), false)

func play_from_sect(sect: String):
	if sect in h_sections:
		if not Engine.is_editor_hint():
			play(h_sections[sect])

func stop(seek_stop: bool = false):
	sec_position = 0
	is_playing = false
	for timer in timers.get_children():
		timer.stop()
	for s in stream_data:
		var stream = stream_data[s]
		if stream.queueable and seek_stop: continue
		if stream.player.playing:
			stream.player.playing = false

func seek(to: float):
	play(to)

# Fade functions
func fade_stream(vol_linear, stream: String, fade_override: float = -1.0):
	if stream in stream_data:
		var stream_tween = create_tween()
		stream_tween.set_parallel(true)
		
		stream_tween.tween_method(interpolate_vol.bind(stream_data[stream], 0), stream_data[stream].vol, vol_linear, playlist_data.fade_length if fade_override<0.0 else fade_override)

func fade_group(vol_linear: float, group: String, fade_override: float = -1.0):
	if group in groups and group!="":
		var group_tween = create_tween()
		group_tween.set_parallel(true)
	
		for stream in groups[group].streams:
			group_tween.tween_method(interpolate_vol.bind(stream, 1), groups[group].vol, vol_linear, playlist_data.fade_length if fade_override<0.0 else fade_override)

func fade_playlist(vol_linear: float, stop_audio: bool = false, fade_override: float = -1.0):
	if stream_data.is_empty(): return
	var playlist_tween = create_tween()
	playlist_tween.set_parallel(true)
	
	for stream in stream_data:
		playlist_tween.tween_method(interpolate_vol.bind(stream_data[stream],2),playlist_vol,vol_linear,playlist_data.fade_length if fade_override<0.0 else fade_override)
	await playlist_tween.finished
	if stop_audio and playlist_vol<=0.0:
		stop()

func interpolate_vol(vol_linear: float, stream: LdStream, type: int):
	match type:
		0:
			stream.vol = vol_linear
		1:
			groups[stream.group].vol = vol_linear
		2: 
			playlist_vol = vol_linear
	var new_vol: float = stream.vol*groups[stream.group].vol*playlist_vol
	stream.player.volume_db = linear_to_db(new_vol)

# Vertical Remixing
func set_v_state(new_state: String, fade_override: float = -1.0):
	if new_state in v_states:
		if not v_states[new_state].add_only:
			for group in groups:
				fade_group(0.0, group, fade_override)
		for group in v_states[new_state].groups:
			fade_group(1.0, group, fade_override)

# may or may not keep this in
func toggle_v_state(state: String, fade_override: float = -1.0):
	if state in v_states:
		if not v_states[state].add_only:
			for group in groups:
				fade_group(0.0, group, fade_override)
		for group in v_states[state].groups:
			var current_group_vol = groups[group].vol
			fade_group(1.0 if current_group_vol<=0.0 else 0.0, group, fade_override)

# Horizontal Remixing
func check_h_transition(transition: LdTransition) -> bool:
	for dest in transition.destinations:
		if h_state == dest:
			if dest in h_sections:
				seek(h_sections[dest])
				return true
	if transition.loop:
		seek(h_sections[transition.destinations[-1]])
		return true
	return false

func set_h_state(new_state: String, auto_play: bool = false):
	h_state = new_state
	if auto_play:
		play_from_sect(h_state)

func get_bpm(time: float) -> float:
	for i in range(bpm_times.size()):
		if time>=bpm_times[i]:
			var c_t: float = bpm_times[i]
			var n_t: float = bpm_times[i-1 if (i-1)>=0 else i]
			var c_b: float = bpms[c_t].bpm
			var n_b: float = bpms[n_t].bpm
			
			var dt: float = n_t-c_t if (n_t!=c_t) else 1.0
			var db_dt: float = (n_b-c_b)/dt
			var x_t: float = time-c_t
			
			var bpm: float = db_dt*x_t + c_b
			return bpm
	return 0

# Interactive Audio
func get_beats_since_sect(time: float) -> float:
	for i in range(bpm_times.size()):
		if time>=bpm_times[i]:
			var c_t: float = bpm_times[i]
			var n_t: float = bpm_times[i-1 if (i-1)>=0 else i]
			var c_b: float = bpms[c_t].bpm
			var n_b: float = bpms[n_t].bpm if not bpms[c_t].constant else bpms[c_t].bpm
			
#			c_b/=(4.0/bpms[c_t].beat_value)
#			n_b/=(4.0/bpms[n_t].beat_value)
			
			var dt: float = n_t-c_t if (n_t!=c_t) else 1.0
			var db_dt: float = (n_b-c_b)/dt
			var x_t: float = time-c_t
			
			var beats_sec: float = (pow(x_t,2)/2)*db_dt + c_b*x_t
			var beats: float = (beats_sec/(60.0/playlist_data.count_subdivision)) + playlist_data.count_subdivision
			return beats
	return 0

func play_queueable(stream: String, wait_for_beat: float = 1.0):
	if stream in stream_data and is_playing:
		var queueable = stream_data[stream]
		
		if queueable.connected == wait_for_beat: return
		match wait_for_beat:
			1.0: 
				queueable.connected = 1.0
				await self.quarter_beat
			0.5: 
				queueable.connected = 0.5
				await self.eighth_beat
			4.0:
				queueable.connected = 4.0
				await self.measure
			_:
				return
		queueable.play(0+AudioServer.get_time_to_next_mix())
		queueable.connected = 0.0
	
func _physics_process(delta):
	if is_playing:
		if tracker_timer and !tracker_timer.is_stopped():
			sec_position = start_position+tracker_timer.wait_time - tracker_timer.time_left
		else:
			sec_position+=delta
		
		beat_position = floor(get_beats_since_sect(sec_position))/playlist_data.count_subdivision
		report_beat()

func report_beat():
	if last_reported_beat!=beat_position:
		debug_label.text = current_section + ", " + str(beat_position)
		
		if fmod(beat_position,current_beats_in_measure)==1.0: # <-- 4 = beats in meaure
			total_measures+=1
			self.measure.emit(beat_position)
		if fmod(beat_position,1)==0.0:
			self.quarter_beat.emit(beat_position)
		if fmod(beat_position,0.5)==0.0 and playlist_data.count_subdivision>=2:
			self.eighth_beat.emit(beat_position) 
		beat_label.text = "Measure, Beat, Time Signature: {msr}, {bt}, {bim}/{bv}".format({"msr": total_measures, "bt": fmod(beat_position-1,current_beats_in_measure)+1, "bim": current_beats_in_measure, "bv":current_beat_value})
		last_reported_beat = beat_position

func wait_for_section(sect: String, fire_in_middle: bool = false) -> bool:
	if sect != "" and sect in h_sections:
		if fire_in_middle and current_section==sect:
			return true
		var reached_section: String = await self.section
		if reached_section == sect:
			return true
		else:
			return await wait_for_section(sect)
	else:
		return false

func wait_for_event(event: String) -> bool:
	if event!="" and event_names.has(event):
		var reached_event: String = await self.event_reached
		if reached_event == event:
			return true
		else:
			return await wait_for_event(event)
	else:
		return false

func check_end(time_check: float):
	if time_check==playlist_data.end_time:
		stop()
		self.playlist_finished.emit()
		if playlist_data.loop:
			play(playlist_data.loop_offset)

func _on_button_pressed():
	play(0.0)

func _on_stop_button_pressed():
	stop()
	
func prepare_debug():
	init_vertical()
	init_horizontal()
	init_queueables()

func init_vertical():
	vertical_btn.clear()
	var i: int = 0
	for v in v_states:
		vertical_btn.add_item(v)
		if v==v_state:
			vertical_btn.select(i)
		i+=1

func init_horizontal():
	horizontal_btn.clear()
	var i: int = 0
	for h in h_sections:
		horizontal_btn.add_item(h)
		if h==h_state:
			horizontal_btn.select(i)
		i+=1

func init_queueables():
	for s in stream_data:
		if stream_data[s].queueable:
			var btn: Button = Button.new()
			btn.text = s
			queueables_list.add_child(btn)
			btn.pressed.connect(play_queueable.bind(s, 1.0))

func _on_vertical_option_item_selected(index):
	set_v_state(vertical_btn.get_item_text(index))

func _on_horizontal_option_item_selected(index):
	set_h_state(horizontal_btn.get_item_text(index))
