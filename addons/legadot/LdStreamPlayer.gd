extends Node
class_name LdStreamPlayer

@export var playlist_data: LdPlaylistData

var stream_players: Node
var timers: Node

var stream_data: Dictionary = {}
var groups: Dictionary = {}
var timeline: Dictionary = {}
var v_states: Dictionary = {}
var h_sections: Dictionary = {}
var bpms: Dictionary = {}
var bpm_times: Array
var event_names: Array
var action_sets: Dictionary = {}

var is_playing: bool = false
var start_position: float = 0.0
var sec_position: float = 0.0
var raw_beat_position: float
var beat_position: float = 0
var last_reported_beat: float = 0
var current_section: String = "":
	set(sect):
		self.section.emit(sect)
		current_section=sect
var current_beats_in_measure: int = 4
var current_beat_value: int = 4
var total_measures: int = 0
var coroutine_password: float = 0.0

var p_tween: Tween

var playlist_vol: float = 1.0

@export var auto_start: bool = false

@export var v_state: String
@export var h_state: String

var tracker_timer: Timer
var longest_time: float = 0.0

var unmuted_streams: Array[String]
var unmuted_groups: Array[String]
var unmuted_playlist: bool = false

signal measure(beat_pos: float)
signal quarter_beat(beat_pos: float)
signal eighth_beat(beat_pos: float)
signal section(sect: String)
signal event_reached(event: String)
signal playlist_finished()

signal stream_muted(stream_name: String)
signal group_muted(group_name: String)
signal playlist_muted()

signal stream_unmuted(stream_name: String)
signal group_unmuted(group_name: String)
signal playlist_unmuted()

@export_category("Debug")
@export var show_debug_menu: bool = false
@onready var debug_menu: LdDebugMenu = get_node_or_null("DebugMenu")

func _ready():
	if Legadot and playlist_data:
		if playlist_data.playlist_name!="":
			Legadot.add_playlist(playlist_data.playlist_name, self)
		else:
			Legadot.add_playlist(self.name, self)
		self.tree_exiting.connect(remove_self)
	init_debug()
	init_stream_players_node()
	init_timers_node()
	init_playlist()

func init_debug():
	if show_debug_menu:
		if not debug_menu:
			var debug_scene = load("res://addons/legadot/scenes/debug_menu.tscn")
			debug_menu = debug_scene.instantiate()
			add_child(debug_menu)
	else:
		if debug_menu:
			debug_menu.queue_free()
		debug_menu = null

func init_stream_players_node():
	var stream_players_node: Node = Node.new()
	stream_players_node.name = "StreamPlayers"
	self.add_child(stream_players_node)
	self.stream_players = stream_players_node

func init_timers_node():
	var timers_node: Node = Node.new()
	timers_node.name = "Timers"
	self.add_child(timers_node)
	self.timers = timers_node

func init_playlist():
	if playlist_data:
		build_data()
		build_groups()
		build_timeline()
		assign_timers()
		build_v_states()
		build_h_sections()
		build_bpm()
		build_action_sets()

		if debug_menu:
			debug_menu.init_debug_menu()
		
		if playlist_data.default_v_state!="":
			set_v_state(playlist_data.default_v_state,0.0)
		else:
			for group in groups:
				update_group_mute(groups[group].vol, group)
			for stream in stream_data:
				update_stream_mute(stream_data[stream].vol, stream)
			fade_playlist(1.0,false,0.0)
		
		if playlist_data.default_h_state!="":
			if debug_menu:
				debug_menu.h_select(h_state)
			await get_tree().create_timer(0.25).timeout
			set_h_state(playlist_data.default_h_state, auto_start)
		else:
			if not Engine.is_editor_hint():
				if auto_start and OS.get_name()!="Web":
					play(-0.25)
			else:
				stop()

func build_data():
	for stream in playlist_data.streams:
		add_stream(stream)

func add_stream(stream: LdStream):
	var player_template = get_player_template()
	if stream.name != "":
		var player = player_template.duplicate()
		player.stream = AudioStreamPolyphonic.new() if stream.allow_dupes else stream.audio_stream
		
		stream.player = player
		stream.max_vol = stream.vol
		stream_data[stream.name] = stream
		check_longest_time(stream.time, stream.audio_stream)
		
		stream_players.add_child(player)

func get_player_template():
	var player_node: AudioStreamPlayer = AudioStreamPlayer.new()
	for child in self.get_children():
		if child is AudioStreamPlayer:
			player_node = child.duplicate()
			child.queue_free()
			break
	return player_node

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
				"vol": 1.0,
				"g_tween": null
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
	if debug_menu:
		debug_menu.song_progress.max_value = end

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
	
func build_action_sets():
	for action_set in playlist_data.action_sets:
		action_sets[action_set.action_set_name] = action_set

# Basic song functions
func play(from: float = 0.0):
	if is_playing:
		stop(true)
	if from>=playlist_data.end_time:
		return
	is_playing = true
	start_position = from
	total_measures=0
	var time_keys = timeline.keys()
	time_keys.sort()
	for time in time_keys:
		if time>from:
			timeline[time].timer.wait_time = time-from-AudioServer.get_time_to_next_mix()
			if timeline[time].timer.wait_time>=0.05:
				if not tracker_timer or timeline[time].timer.wait_time>tracker_timer.wait_time:
					tracker_timer = timeline[time].timer
				timeline[time].timer.start()
			else:
				timeline[time].trigger_event(self, abs(from-time), false)
			continue
		elif (from-time)>=0.0:
			timeline[time].trigger_event(self, abs(from-time), false)

func play_from_sect(sect: String):
	if sect in h_sections:
		if not Engine.is_editor_hint():
			play(h_sections[sect])

func stop(seek_stop: bool = false, reset_pos: bool = true):
	if reset_pos: 
		sec_position = 0
		last_reported_beat = 0
	is_playing = false
	for timer in timers.get_children():
		timer.stop()
	for s in stream_data:
		var stream = stream_data[s]
		if stream.queueable and seek_stop: continue
		if stream.player.playing:
			stream.player.playing = false

func pause():
	stop(false, false)

func resume():
	play(sec_position)

func seek(to: float):
	play(to)

# Fade functions
func fade_stream(vol_linear: float, stream: String, fade_override: float = -1.0):
	if stream in stream_data:
		update_stream_mute(vol_linear, stream)
		var song: LdStream = stream_data[stream]
		if song.s_tween: song.s_tween.kill()
		song.s_tween = create_tween()
		song.s_tween.set_parallel(true)
		if vol_linear>stream_data[stream].max_vol:
			vol_linear = stream_data[stream].max_vol
		song.s_tween.tween_method(interpolate_vol.bind(stream_data[stream], 0), stream_data[stream].vol, vol_linear, playlist_data.fade_length if fade_override<0.0 else fade_override)
		await song.s_tween.finished
	return

func fade_group(vol_linear: float, group: String, fade_override: float = -1.0):
	if group in groups and group!="":
		update_group_mute(vol_linear, group)
		var group_data: Dictionary = groups[group]
		if group_data.g_tween: group_data.g_tween.kill()
		group_data.g_tween = create_tween()
		group_data.g_tween.set_parallel(true)
	
		for stream in groups[group].streams:
			#update_stream_mute(vol_linear, stream.name)
			group_data.g_tween.tween_method(interpolate_vol.bind(stream, 1), groups[group].vol, vol_linear, playlist_data.fade_length if fade_override<0.0 else fade_override)
		await group_data.g_tween.finished
	return

func fade_playlist(vol_linear: float, stop_audio: bool = false, fade_override: float = -1.0):
	if stream_data.is_empty(): return
	update_playlist_mute(vol_linear)
	if p_tween: p_tween.kill()
	p_tween = create_tween()
	p_tween.set_parallel(true)
	
	for stream in stream_data:
		p_tween.tween_method(interpolate_vol.bind(stream_data[stream],2),playlist_vol,vol_linear,playlist_data.fade_length if fade_override<0.0 else fade_override)
	await p_tween.finished
	if stop_audio and playlist_vol<=0.0:
		stop()
	return

func interpolate_vol(vol_linear: float, stream: LdStream, type: int):
	match type:
		0:
			stream.vol = vol_linear
		1:
			groups[stream.group].vol = vol_linear
		2: 
			playlist_vol = vol_linear
	var new_vol: float = stream.vol*groups[stream.group].vol*playlist_vol*playlist_data.max_playlist_vol
	stream.player.volume_db = linear_to_db(new_vol)

func update_stream_mute(vol_linear: float, stream_name: String):
	if vol_linear==0.0:
		unmuted_streams.erase(stream_name)
		self.stream_muted.emit(stream_name)
		if debug_menu and stream_name in debug_menu.stream_toggles:
			debug_menu.stream_toggles[stream_name].set_pressed_no_signal(false)
	elif vol_linear>0.0 and not unmuted_streams.has(stream_name):
		unmuted_streams.append(stream_name)
		self.stream_unmuted.emit(stream_name)
		if debug_menu and stream_name in debug_menu.stream_toggles:
			debug_menu.stream_toggles[stream_name].set_pressed_no_signal(true)
		
func update_group_mute(vol_linear: float, group_name: String):
	if vol_linear==0.0:
		unmuted_groups.erase(group_name)
		self.group_muted.emit(group_name)
		if debug_menu and group_name in debug_menu.group_toggles:
			debug_menu.group_toggles[group_name].set_pressed_no_signal(false)
	elif vol_linear>0.0 and not unmuted_groups.has(group_name):
		unmuted_groups.append(group_name)
		self.group_unmuted.emit(group_name)
		if debug_menu and group_name in debug_menu.group_toggles:
			debug_menu.group_toggles[group_name].set_pressed_no_signal(true)

func update_playlist_mute(vol_linear: float):
	if vol_linear==0.0:
		if unmuted_playlist:
			unmuted_playlist = false
			self.playlist_muted.emit()
	elif vol_linear>0.0 and playlist_vol<=0.0:
		if not unmuted_playlist:
			unmuted_playlist = true
			self.playlist_unmuted.emit()

# Vertical Remixing
func set_v_state(new_state: String, fade_override: float = -1.0):
	if new_state in v_states:
		v_state = new_state
		if debug_menu:
			debug_menu.v_select(new_state)
		if not v_states[new_state].add_only:
			for group in groups:
				fade_group(0.0, group, fade_override)
		for group in v_states[new_state].groups:
			if group in groups:
				fade_group(1.0, group, fade_override)
		await get_tree().create_timer(playlist_data.fade_length if fade_override<0.0 else fade_override).timeout
	return

# may or may not keep this in
func toggle_v_state(state: String, fade_override: float = -1.0):
	if state in v_states:
		if not v_states[state].add_only:
			for group in groups:
				fade_group(0.0, group, fade_override)
		for group in v_states[state].groups:
			var current_group_vol = groups[group].vol
			fade_group(1.0 if current_group_vol<=0.0 else 0.0, group, fade_override)
		await get_tree().create_timer(playlist_data.fade_length if fade_override<0.0 else fade_override).timeout
	return

# Horizontal Remixing
func check_h_transition(transition: LdTransition) -> bool:
	for dest in transition.destinations:
		if h_state == dest:
			if dest in h_sections:
				seek(h_sections[dest])
				return true
		elif h_state == dest.get_slice("=", 0):
			var cnd_dest: String = dest.get_slice("=", 1)
			if cnd_dest in h_sections:
				seek(h_sections[cnd_dest])
				return true
	if transition.loop:
		seek(h_sections[transition.destinations[-1]])
		return true
	return false

func set_h_state(new_state: String, auto_play: bool = false):
	h_state = new_state
	if debug_menu:
		debug_menu.h_select(new_state)
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
			
			var dt: float = n_t-c_t if (n_t!=c_t) else 1.0
			var db_dt: float = (n_b-c_b)/dt
			var x_t: float = time-c_t
			
			var beats_sec: float = (pow(x_t,2)/2)*db_dt + c_b*x_t
			var beats: float = (beats_sec/(60.0/playlist_data.count_subdivision)) + playlist_data.count_subdivision
			return beats
	return 0.0

func play_queueable(stream: String, wait_beat: float = 1.0):
	if stream in stream_data and is_playing:
		var queueable = stream_data[stream]
		
		if queueable.connected == wait_beat: return
		match wait_beat:
			0.0:
				pass
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
		queueable.connected = -1.0
	
func _physics_process(delta):
	if is_playing:
		if tracker_timer and !tracker_timer.is_stopped():
			sec_position = start_position+tracker_timer.wait_time - tracker_timer.time_left
		else:
			sec_position+=delta
		
		raw_beat_position = get_beats_since_sect(sec_position)/playlist_data.count_subdivision
		beat_position = floor(get_beats_since_sect(sec_position))/playlist_data.count_subdivision
		report_beat()

func report_beat():
	if last_reported_beat!=beat_position:
		if debug_menu:
			debug_menu.set_debug_label(current_section, beat_position)
		
		if fmod(beat_position,current_beats_in_measure)==1.0: # <-- 4 = beats in meaure
			total_measures+=1
			self.measure.emit(beat_position)
		if fmod(beat_position,1)==0.0:
			self.quarter_beat.emit(beat_position)
		if fmod(beat_position,0.5)==0.0 and playlist_data.count_subdivision>=2:
			self.eighth_beat.emit(beat_position) 
		
		if debug_menu:
			debug_menu.set_beat_label(total_measures, fmod(beat_position-1,current_beats_in_measure)+1, current_beats_in_measure, current_beat_value)
		last_reported_beat = beat_position

func wait_for_beat(beat: float = 1.0):
	match beat:
		1.0: 
			await self.quarter_beat
		0.5: 
			await self.eighth_beat
		4.0:
			await self.measure
		_:
			return

func wait_for_section(sections: String, fire_in_middle: bool = false) -> bool:
	if sections != "":
		var sect_array := sections.split(",", false)
		if fire_in_middle and sect_array.has(current_section):
			return true
		var reached_section: String = await self.section
		if sect_array.has(reached_section):
			return true
		else:
			return await wait_for_section(sections)
	else:
		return false

func wait_for_event(events: String) -> bool:
	if events!="":
		var event_array := events.split(",", false)
		var reached_event: String = await self.event_reached
		if event_array.has(reached_event):
			return true
		else:
			return await wait_for_event(events)
	else:
		return false

func check_end(time_check: float):
	if time_check==playlist_data.end_time:
		stop()
		self.playlist_finished.emit()
		if playlist_data.loop:
			play(playlist_data.loop_offset)

func start_action_set(action_set_name: String):
	action_sets[action_set_name].trigger_actions(self)

func remove_self():
	if Legadot:
		if playlist_data and playlist_data.playlist_name:
			Legadot.remove_playlist(playlist_data.playlist_name)
		else:
			Legadot.remove_playlist(self.name)
