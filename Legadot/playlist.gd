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

var is_playing: bool = false
var sec_per_beat: float = 0.0
var start_position: float = 0.0
var sec_position: float = 0.0
var beat_position: float = 0
var last_reported_beat: float = 0
var current_section: String = "":
	set(sect):
		self.section.emit(sect)
		current_section=sect

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

signal measure(beat_pos: float)
signal quarter_beat(beat_pos: float)
signal eighth_beat(beat_pos: float)
signal section(sect: String)

@export_category("Debug")
@export var debug_label: Label
@export var vertical_btn: OptionButton
@export var horizontal_btn: OptionButton
@export var queueables_list: HBoxContainer

func _ready():
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
			v_state = playlist_data.default_v_state
			set_v_state(playlist_data.default_v_state,0.0)
		else:
			fade_playlist(1.0,false,0.0)
		
		if playlist_data.default_h_state!="":
			h_state = playlist_data.default_h_state
			set_h_state(playlist_data.default_h_state, auto_start)
		else:
			if auto_start and OS.get_name()!="Web":
				play(0)
		
		print(get_beats_since_sect(13.459))
		await section_reached("game")
		print("reached game")
		#set_v_state("crates")

func build_data():
	for stream in playlist_data.streams:
		add_stream(stream)

func add_stream(stream: LdStream):
	if stream.name != "":
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			player.stream = stream.audio_stream
			
			stream_data[stream.name] = {
				"time": stream.time,
				"player": player,
				"max_vol": stream.vol,
				"stream_vol": stream.vol,
				"group": stream.group,
				"queueable": stream.queueable,
				"connected": 0.0
			}
			
			stream_players.add_child(player)

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
			timeline[s_time] = LdTimelineEvent.new()
		timeline[s_time].streams.append(stream_data[s])
	
	for bpm in playlist_data.bpm_times:
		if not (bpm.time in timeline):
			timeline[bpm.time] = LdTimelineEvent.new()
		timeline[bpm.time].bpm = bpm.bpm
	
	for t in playlist_data.transitions:
		if not (t.time in timeline):
			timeline[t.time] = LdTimelineEvent.new()
		timeline[t.time].transition = t
	
	for sect in playlist_data.sections:
		if not (sect.time in timeline):
			timeline[sect.time] = LdTimelineEvent.new()
		timeline[sect.time].section = sect.section_name

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
	var time_keys = timeline.keys()
	time_keys.sort()
	for time in time_keys:
		if time>from:
			timeline[time].timer.wait_time = time-from+AudioServer.get_time_to_next_mix()
			if timeline[time].timer.wait_time>=0.05:
				if not tracker_timer or timeline[time].timer.wait_time>tracker_timer.wait_time:
					tracker_timer = timeline[time].timer
				timeline[time].timer.start()
			else:
				timeline[time].trigger_event(self, abs(from-time))
			continue
		if (from-time)>=0.0:
			timeline[time].trigger_event(self, abs(from-time))

func play_from_sect(sect: String):
	if sect in h_sections:
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
		
		stream_tween.tween_method(interpolate_vol.bind(stream_data[stream], 0), stream_data[stream].stream_vol, vol_linear, playlist_data.fade_length if fade_override<0.0 else fade_override)
	pass

func fade_group(vol_linear: float, group: String, fade_override: float = -1.0):
	if group in groups and group!="":
		var group_tween = create_tween()
		group_tween.set_parallel(true)
	
		for stream in groups[group].streams:
			group_tween.tween_method(interpolate_vol.bind(stream, 1), groups[group].vol, vol_linear, playlist_data.fade_length if fade_override<0.0 else fade_override)

func fade_playlist(vol_linear: float, stop_audio: bool = false, fade_override: float = -1.0):
	var playlist_tween = create_tween()
	playlist_tween.set_parallel(true)
	
	for stream in stream_data:
		playlist_tween.tween_method(interpolate_vol.bind(stream_data[stream],2),playlist_vol,vol_linear,playlist_data.fade_length if fade_override<0.0 else fade_override)
	await playlist_tween.finished
	if stop_audio and playlist_vol<=0.0:
		stop()

func interpolate_vol(vol_linear: float, stream: Dictionary, type: int):
	match type:
		0:
			stream.stream_vol = vol_linear
		1:
			groups[stream.group].vol = vol_linear
		2: 
			playlist_vol = vol_linear
	var new_vol: float = stream.stream_vol*groups[stream.group].vol*playlist_vol
	stream.player.volume_db = linear_to_db(new_vol)

# Vertical Remixing
func set_v_state(new_state: String, fade_override: float = -1.0):
	if new_state in v_states:
		if not v_states[new_state].add_only:
			for group in groups:
				fade_group(0.0, group, fade_override)
		for group in v_states[new_state].groups:
			fade_group(1.0, group, fade_override)

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
			
			var dt: float = n_t-c_t if (n_t!=c_t) else 1.0
			var db_dt: float = (n_b-c_b)/dt
			var x_t: float = time-c_t
			
			var beats_sec: float = (pow(x_t,2)/2)*db_dt + c_b*x_t
			var beats: float = (beats_sec/(60.0/playlist_data.count_subdivision)) + playlist_data.count_subdivision
			return beats
	return 0

func play_queueable(stream: String, wait_for_beat: float = 1.0):
	if stream in stream_data:
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
				await self.measure # <-- 4 = beats in measure
			_:
				return
		print("play ", stream)
		queueable.player.play(0+AudioServer.get_time_to_next_mix())
		queueable.connected = 0.0
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if Input.is_action_just_pressed("debug1"):
		play_queueable("win", 1.0)
	if Input.is_action_just_pressed("debug2"):
		play_queueable("collect", 1.0)
	
	if is_playing:
		if tracker_timer and !tracker_timer.is_stopped():
			sec_position = start_position+tracker_timer.wait_time - tracker_timer.time_left
		else:
			sec_position+=delta
		
		beat_position = floor(get_beats_since_sect(sec_position))/playlist_data.count_subdivision
		report_beat()

func report_beat():
	if last_reported_beat!=beat_position:
		#print(beat_position)
		debug_label.text = current_section + ", " + str(beat_position)
		if fmod(beat_position,4)==1.0: # <-- 4 = beats in meaure
			#print("measure")
			self.measure.emit(beat_position)
		if fmod(beat_position,1)==0.0:
			#print("quarter note")
			self.quarter_beat.emit(beat_position)
		if fmod(beat_position,0.5)==0.0 and playlist_data.count_subdivision>=2:
			#print("eighth note")
			self.eighth_beat.emit(beat_position) 
			
		last_reported_beat = beat_position

func section_reached(sect: String) -> bool:
	if sect != "":
		var reached_section: String = await self.section
		if reached_section == sect:
			return true
		else:
			return await section_reached(sect)
	else:
		return false

func _on_button_pressed():
	play(0.0)

func _on_stop_button_pressed():
	stop()
	
func prepare_debug():
	init_vertical()
	init_horizontal()
	init_queueables()
	pass

func init_vertical():
	var i: int = 0
	for v in v_states:
		vertical_btn.add_item(v)
		if v==v_state:
			vertical_btn.select(i)
		i+=1

func init_horizontal():
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
			btn.pressed.connect(play_queueable.bind(s))

func _on_vertical_option_item_selected(index):
	set_v_state(vertical_btn.get_item_text(index))
	pass # Replace with function body.


func _on_horizontal_option_item_selected(index):
	set_h_state(horizontal_btn.get_item_text(index))
	pass # Replace with function body.
