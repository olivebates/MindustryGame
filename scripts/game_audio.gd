extends Node2D
## Pooled, rate-limited one-shots. This RNG never touches wave generation.
const EFFECTS := ["ui_hover", "ui_click", "build", "demolish", "error", "shot", "cannon", "explosion", "heal", "research", "wave", "gate", "defeat", "collect", "rewind"]
const COOLDOWNS := {"ui_hover": 0.045, "ui_click": 0.04, "build": 0.055, "demolish": 0.07, "error": 0.25, "shot": 0.065, "cannon": 0.12, "explosion": 0.09, "heal": 0.25, "collect": 0.07}
var streams: Dictionary = {}
var cooldowns: Dictionary = {}
var ui_voices: Array[AudioStreamPlayer] = []
var world_voices: Array[AudioStreamPlayer2D] = []
var ui_index := 0
var world_index := 0
var muted := false
@export_range(0.0, 1.0) var volume := 0.7
func _ready() -> void:
	muted = DisplayServer.get_name() == "headless"
	for id in EFFECTS: streams[id] = load("res://assets/audio/%s.wav" % id)
	for index in 6:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		ui_voices.append(voice)
	for index in 12:
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = 1200
		voice.attenuation = 1.3
		add_child(voice)
		world_voices.append(voice)
func _process(dt: float) -> void:
	for id in cooldowns: cooldowns[id] = maxf(0, cooldowns[id] - dt)
func play(id: String, position_in_world: Vector2 = Vector2.INF) -> void:
	if muted or volume <= 0 or not streams.has(id) or cooldowns.get(id, 0.0) > 0: return
	cooldowns[id] = COOLDOWNS.get(id, 0.0)
	var gain := linear_to_db(volume) + (-23.0 if id == "ui_hover" else -8.0)
	if position_in_world == Vector2.INF:
		var voice := ui_voices[ui_index]
		ui_index = (ui_index + 1) % ui_voices.size()
		voice.stream = streams[id]
		voice.volume_db = gain
		voice.play()
	else:
		var voice := world_voices[world_index]
		world_index = (world_index + 1) % world_voices.size()
		voice.position = position_in_world
		voice.stream = streams[id]
		voice.volume_db = gain
		voice.play()
func toggle_mute() -> void:
	muted = not muted
	if muted:
		for voice in ui_voices: voice.stop()
		for voice in world_voices: voice.stop()

