extends Node

# Genera audio sintetizado proceduralmente — no necesita archivos externos
# Los sonidos se pre-generan al inicio y se cachean

var _players: Array = []
var _sounds: Dictionary = {}
var _player_index: int = 0
const POOL_SIZE = 8

func _ready() -> void:
	# Pool de AudioStreamPlayers para sonidos simultaneos
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)

	# Pre-genera todos los sonidos
	_sounds["card_play"]    = _tone(440.0, 0.12, 0.6)
	_sounds["card_hover"]   = _tone(600.0, 0.05, 0.25)
	_sounds["enemy_hit"]    = _tone_with_noise(100.0, 0.18, 0.7)
	_sounds["player_hit"]   = _tone_with_noise(150.0, 0.22, 0.65)
	_sounds["shield_block"] = _tone(800.0, 0.10, 0.4)
	_sounds["relic_get"]    = _arpeggio([880.0, 1100.0, 1320.0], 0.08, 0.5)
	_sounds["victory"]      = _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.14, 0.7)
	_sounds["defeat"]       = _descend(300.0, 120.0, 0.6, 0.6)
	_sounds["enemy_attack"] = _tone_with_noise(80.0, 0.15, 0.6)
	_sounds["button_click"] = _tone(500.0, 0.07, 0.35)
	_sounds["lore_reveal"]  = _arpeggio([220.0, 277.0, 330.0], 0.2, 0.3)
	_sounds["curse_card"]   = _descend(200.0, 100.0, 0.3, 0.5)
	_sounds["card_draw"]    = _ascend_noise(200.0, 480.0, 0.22, 0.38)
	_sounds["card_discard"] = _descend_noise(420.0, 160.0, 0.2, 0.35)
	_sounds["menu_hover"]   = _tone(300.0, 0.05, 0.15)
	_sounds["menu_glitch"]  = _descend_noise(120.0, 40.0, 0.25, 0.5)
	_sounds["ambient_hum"]  = _tone_with_noise(60.0, 2.0, 0.1)
	_sounds["thunder"]      = _tone_with_noise(40.0, 1.5, 0.8) # Sonido de trueno

func play(sound_name: String) -> void:
	if not _sounds.has(sound_name):
		return
	var p = _players[_player_index % POOL_SIZE]
	_player_index += 1
	p.stream = _sounds[sound_name]
	p.play()

# ─── Generadores de onda ──────────────────────────────────────────────────────

func _make_stream(data: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	return stream

func _tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate = 22050
	var count = int(rate * duration)
	var data = PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t = float(i) / float(rate)
		var env = pow(1.0 - t / duration, 0.4)
		var s = int(clamp(sin(TAU * freq * t) * env * volume * 32767, -32768, 32767))
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_stream(data)

func _tone_with_noise(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate = 22050
	var count = int(rate * duration)
	var data = PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t = float(i) / float(rate)
		var env = pow(1.0 - t / duration, 0.3)
		var tone = sin(TAU * freq * t)
		var noise = (randf() * 2.0 - 1.0) * 0.3
		var s = int(clamp((tone + noise) * env * volume * 32767, -32768, 32767))
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_stream(data)

func _arpeggio(freqs: Array, note_dur: float, volume: float) -> AudioStreamWAV:
	var rate = 22050
	var total = int(rate * note_dur * freqs.size())
	var data = PackedByteArray()
	data.resize(total * 2)
	for n in range(freqs.size()):
		var freq = freqs[n]
		var start = int(rate * note_dur * n)
		var count = int(rate * note_dur)
		for i in range(count):
			var t = float(i) / float(rate)
			var env = pow(1.0 - t / note_dur, 0.4)
			var s = int(clamp(sin(TAU * freq * t) * env * volume * 32767, -32768, 32767))
			var idx = (start + i) * 2
			if idx + 1 < data.size():
				data[idx]     = s & 0xFF
				data[idx + 1] = (s >> 8) & 0xFF
	return _make_stream(data)

func _ascend_noise(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate = 22050
	var count = int(rate * duration)
	var data = PackedByteArray()
	data.resize(count * 2)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		var progress = t / duration
		var freq = lerp(freq_start, freq_end, progress)
		var env = sin(progress * PI)  # sube y baja suavemente
		var noise = (randf() * 2.0 - 1.0) * 0.25
		phase += TAU * freq / float(rate)
		var s = int(clamp((sin(phase) + noise) * env * volume * 32767, -32768, 32767))
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_stream(data)

func _descend_noise(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate = 22050
	var count = int(rate * duration)
	var data = PackedByteArray()
	data.resize(count * 2)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		var progress = t / duration
		var freq = lerp(freq_start, freq_end, progress)
		var env = pow(1.0 - progress, 0.2)
		var noise = (randf() * 2.0 - 1.0) * 0.3
		phase += TAU * freq / float(rate)
		var s = int(clamp((sin(phase) + noise) * env * volume * 32767, -32768, 32767))
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_stream(data)

func _descend(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate = 22050
	var count = int(rate * duration)
	var data = PackedByteArray()
	data.resize(count * 2)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		var progress = t / duration
		var freq = lerp(freq_start, freq_end, progress)
		var env = pow(1.0 - progress, 0.3)
		phase += TAU * freq / float(rate)
		var s = int(clamp(sin(phase) * env * volume * 32767, -32768, 32767))
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_stream(data)
