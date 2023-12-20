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
var song_position: float = 0.0

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

func _ready():
	if playlist_data:
		build_data()
		build_groups()
		build_timeline()
		assign_timers()
		build_v_states()
		build_h_sections()
		build_bpm()
		
		if playlist_data.default_v_state!="":
			set_v_state(playlist_data.default_v_state)
		
		if playlist_data.default_h_state!="":
			set_h_state(playlist_data.default_h_state, auto_start)
			print(h_state)
		else:
			if auto_start and OS.get_name()!="Web":
				play(0)
		
		get_bpm(7.5)

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
				"group": stream.group
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
		bpms[bpm.time] = bpm.bpm
		if !bpm_times.has(bpm.time):
			bpm_times.append(bpm.time)
	bpm_times.sort()
	bpm_times.reverse()
	print(bpm_times)
	
# Basic song functions
func play(from: float = 0.0):
	if is_playing:
		stop()
	is_playing = true
	var time_keys = timeline.keys()
	time_keys.sort()
	for time in time_keys:
		if time>from:
			#print(timeline[time].timer)
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

func play_from_sect(section: String):
	if section in h_sections:
		play(h_sections[section])

func stop():
	song_position = 0
	is_playing = false
	for timer in timers.get_children():
		timer.stop()
	for player in stream_players.get_children():
		if player.playing:
			player.playing = false

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
	if group in groups:
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

func get_bpm(time: float):
	for i in range(bpm_times.size()):
		if time>=bpm_times[i]:
			var c_t: float = bpm_times[i]
			var n_t: float = bpm_times[i-1 if (i-1)>=0 else i]
			var c_b: float = bpms[c_t]
			var n_b: float = bpms[n_t]
			
			var dt: float = n_t-c_t if (n_t!=c_t) else 1.0
			var db_dt: float = (n_b-c_b)/dt
			var x_t: float = time-c_t
			
			var bpm: float = db_dt*x_t + c_b
			print(c_t, ": ", bpm)
			return bpm

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("debug1"):
		v_state = "main"
	if Input.is_action_just_pressed("debug2"):
		v_state = "crates"
	
	if is_playing:
		if tracker_timer and !tracker_timer.is_stopped():
			song_position = tracker_timer.wait_time - tracker_timer.time_left
		else:
			song_position+=delta
		get_bpm(song_position)

func _on_button_pressed():
	play(12.799)

func _on_stop_button_pressed():
	stop()
	pass # Replace with function body.
