class_name FestivalAudio
extends Node
## Presentation only: audio never drives simulation or sends network traffic.

const DIRECTORY := "res://assets/audio/"
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var settings: Dictionary = {}
var pitch_rng := RandomNumberGenerator.new()


## Index of the audio bus `bus_name`, creating it (routed to Master) when missing.
static func ensure_bus(bus_name: StringName) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	return index


func _ready() -> void:
	settings = DataFile.load_json("res://data/audio.json")
	for bus_name in ["Music", "SFX"]:
		ensure_bus(bus_name)
	SessionState.load_settings()
	pitch_rng.randomize()
	music = AudioStreamPlayer.new()
	music.bus = &"Music"
	add_child(music)
	for i in 16:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		voices.append(voice)
	get_tree().node_added.connect(_on_node_added)
	play_music("music_festival_loop", true)


func stream_for(cue: String) -> AudioStream:
	if not streams.has(cue):
		var cue_settings: Dictionary = settings.get("cues", {}).get(cue, {})
		var asset: String = cue_settings.get("stream", cue)
		var extension := ".ogg" if asset.begins_with("music_") else ".wav"
		var path := DIRECTORY + asset + extension
		if not ResourceLoader.exists(path):
			return null
		streams[cue] = load(path)
	return streams[cue] as AudioStream


func play_sfx(cue: String) -> AudioStreamPlayer:
	var stream := stream_for(cue)
	if stream == null:
		return null
	for voice in voices:
		if not voice.playing and not voice.stream_paused:
			voice.stream = stream
			var cue_settings: Dictionary = settings.get("cues", {}).get(cue, {})
			voice.volume_db = float(cue_settings.get("db", settings.get("sfx_db", -8.0)))
			var jitter := float(cue_settings.get("pitch_jitter", 0.0))
			voice.pitch_scale = float(cue_settings.get("pitch", 1.0)) + pitch_rng.randf_range(-jitter, jitter)
			voice.play()
			_update_music_volume()
			return voice
	return null


func play_music(cue: String, looped := false) -> void:
	var stream := stream_for(cue)
	if stream == null:
		return
	if music.stream == stream and music.playing:
		return
	# Duplicate before changing loop flags: never mutate a shared imported resource.
	var playback := stream.duplicate() as AudioStreamOggVorbis
	playback.loop = looped
	music.stream = playback
	music.volume_db = float(settings.get("music_db", -14.0))
	music.play()
	_update_music_volume()


func _process(_delta: float) -> void:
	_update_music_volume()


func _update_music_volume() -> void:
	var speaking := false
	for voice in voices:
		if voice.stream == streams.get("announcer_intro_vi") and voice.playing and not voice.stream_paused:
			speaking = true
			break
	music.volume_db = float(settings.get("music_db", -14.0)) + (float(settings.get("announcer_music_duck_db", 0.0)) if speaking else 0.0)


func _on_node_added(node: Node) -> void:
	if node is Button and not node is CheckButton:
		var back: bool = node.text.to_upper().contains("QUAY LẠI") or node.text.to_upper().contains("ĐÓNG") or node.text.to_upper().contains("TRỞ VỀ")
		node.pressed.connect(play_sfx.bind("ui_back" if back else "ui_confirm"))
