class_name FestivalAudio
extends Node
## Presentation only: audio never drives simulation or sends network traffic.

const DIRECTORY := "res://assets/audio/"
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var settings: Dictionary = {}


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
		var extension := ".ogg" if cue.begins_with("music_") else ".wav"
		var path := DIRECTORY + cue + extension
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
			voice.volume_db = float(settings.get("sfx_db", -8.0))
			voice.play()
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


func _on_node_added(node: Node) -> void:
	if node is Button:
		var back: bool = node.text.to_upper().contains("QUAY LẠI") or node.text.to_upper().contains("ĐÓNG") or node.text.to_upper().contains("TRỞ VỀ")
		node.pressed.connect(play_sfx.bind("ui_back" if back else "ui_confirm"))
