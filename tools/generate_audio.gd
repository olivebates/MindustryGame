extends SceneTree
## Rebuild the original sound pack: Godot --headless --script tools/generate_audio.gd
const RATE := 22050
const DEFINITIONS := {
 "ui_hover": [0.035, 1300.0, 900.0, 0.02, 0.10],
 "ui_click": [0.075, 720.0, 420.0, 0.16, 0.25],
 "build": [0.16, 440.0, 210.0, 0.22, 0.35],
 "demolish": [0.12, 1100.0, 280.0, 0.35, 0.38],
 "error": [0.23, 155.0, 130.0, 0.06, 0.28],
 "shot": [0.11, 240.0, 70.0, 0.55, 0.32],
 "cannon": [0.35, 95.0, 35.0, 0.45, 0.45],
 "explosion": [0.40, 130.0, 28.0, 0.78, 0.43],
 "heal": [0.50, 660.0, 880.0, 0.0, 0.18],
 "research": [0.65, 523.25, 1046.5, 0.0, 0.24],
 "wave": [0.85, 220.0, 330.0, 0.03, 0.28],
 "gate": [1.0, 392.0, 784.0, 0.02, 0.25],
 "defeat": [0.85, 220.0, 55.0, 0.08, 0.25],
 "collect": [0.075, 1100.0, 1650.0, 0.04, 0.18],
 "rewind": [0.48, 1250.0, 110.0, 0.12, 0.28],
 "core_capture": [2.3, 98.0, 98.0, 0.01, 0.48]
}
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio")
	var random := RandomNumberGenerator.new()
	random.seed = 141192
	for id in DEFINITIONS:
		if not OS.get_cmdline_user_args().is_empty() and not OS.get_cmdline_user_args().has(id): continue
		var spec: Array = DEFINITIONS[id]
		var duration: float = spec[0]
		var samples := int(duration * RATE)
		var pcm := PackedByteArray()
		pcm.resize(samples * 2)
		var phase := 0.0
		var filtered_noise := 0.0
		for index in samples:
			var time := float(index) / RATE
			var progress := time / duration
			var frequency := lerpf(spec[1], spec[2], progress)
			if id == "research": frequency = [523.25, 659.25, 783.99, 1046.5][mini(3, int(progress * 4))]
			if id == "wave": frequency = 220.0 if progress < 0.48 else 330.0
			phase += TAU * frequency / RATE
			var tone := sin(phase)
			if id in ["build", "demolish", "shot", "cannon"]: tone = tone * 0.75 + sin(phase * 2.73) * 0.25
			if id == "heal": tone = (tone + sin(phase * 1.5) * 0.5 + sin(phase * 2) * 0.3) / 1.8
			if id == "gate": tone = (tone + sin(phase * 1.25) * 0.4 + sin(phase * 1.5) * 0.4) / 1.8
			if id == "core_capture": tone = sin(phase * 0.5) * 0.45 + tone * 0.3 + sin(phase * 1.5) * 0.15 + sin(phase * 3.01) * exp(-time * 2.5) * 0.1
			if id == "error": tone *= 0.4 + 0.6 * float(sin(time * TAU * 12) > 0)
			filtered_noise = lerpf(filtered_noise, random.randf_range(-1, 1), 0.32)
			var envelope := minf(1.0, time / 0.005) * pow(maxf(0, 1.0 - progress), 1.8)
			if id in ["heal", "research", "gate"]: envelope = minf(1, time / 0.018) * pow(maxf(0, 1 - progress), 0.9)
			var value: float = (tone * (1.0 - spec[3]) + filtered_noise * spec[3]) * envelope * spec[4]
			pcm.encode_s16(index * 2, roundi(clampf(value, -0.95, 0.95) * 32767))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = RATE
		stream.stereo = false
		stream.data = pcm
		var error := stream.save_to_wav("res://assets/audio/%s.wav" % id)
		if error != OK:
			push_error("Could not save " + id)
			quit(1)
			return
	print("GENERATED %d ORIGINAL WAV EFFECTS" % DEFINITIONS.size())
	quit()



