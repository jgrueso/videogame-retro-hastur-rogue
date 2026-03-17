extends Node

# Genera audio sintetizado proceduralmente — no necesita archivos externos
# Los sonidos se pre-generan al inicio y se cachean

var _players: Array = []
var _sounds: Dictionary = {}
var _external_cache: Dictionary = {}
var _player_index: int = 0
var _active_loops: Dictionary = {} # {sound_name: AudioStreamPlayer}
const POOL_SIZE = 12

func _ready() -> void:
	# Crear buses Music y SFX si no existen
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

	# Pool de AudioStreamPlayers para sonidos simultaneos
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
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
	
	# Victoria Tétrica: Acorde disminuido lento y bajo
	_sounds["victory"]      = _arpeggio([110.0, 130.81, 155.56, 110.0], 0.4, 0.8)
	
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
	_sounds["thunder"]      = _tone_with_noise(40.0, 1.5, 0.8)
	
	# Grito de Agonía: Más complejo y aterrador
	_sounds["agony_shriek"] = _descend_noise(800.0, 100.0, 0.8, 0.7) # Un lamento que cae en el ruido
	_sounds["whisper_madness"] = _tone_with_noise(200.0, 0.5, 0.4) # Susurro sintético

func play(sound_name: String) -> void:
	var stream: AudioStream = null
	
	# 1. Buscar en sonidos procedurales
	if _sounds.has(sound_name):
		stream = _sounds[sound_name]
	
	# 2. Si no es procedural, buscar en archivos externos
	else:
		if not _external_cache.has(sound_name):
			var paths = [
				"res://assets/audio/" + sound_name,
				"res://assets/" + sound_name
			]
			
			var found_stream: AudioStream = null
			for p in paths:
				for ext in [".wav", ".mp3", ".ogg"]:
					var full_path = p + ext
					if FileAccess.file_exists(full_path):
						found_stream = load(full_path)
						if found_stream: break
				if found_stream: break
			
			# Guardar (incluso si es null para no re-intentar carga fallida)
			_external_cache[sound_name] = found_stream
			
			if not found_stream:
				print("AudioManager ERROR: No se pudo cargar o encontrar: ", sound_name)
				return
				
		stream = _external_cache[sound_name]

	if stream:
		var p = _players[_player_index % POOL_SIZE]
		_player_index += 1
		p.stream = stream
		p.play()

func stop_all() -> void:
	for p in _players:
		p.stop()
	# Copiar llaves para evitar error de modificación durante iteración
	var keys = _active_loops.keys()
	for s_name in keys:
		stop_loop(s_name)

func play_loop(sound_name: String) -> void:
	if _active_loops.has(sound_name): return
	var stream = _get_stream(sound_name)
	if stream:
		# Si es una canción nueva, a veces queremos detener las otras
		if "song" in sound_name:
			# Opcional: detener otras canciones si es necesario
			pass
			
		# Forzar loop según el formato ANTES de reproducir
		if stream is AudioStreamMP3: 
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif stream is AudioStreamOggVorbis:
			stream.loop = true
			
		print("AudioManager: Iniciando loop de: ", sound_name)
		var p = AudioStreamPlayer.new()
		p.stream = stream
		p.bus = "Music"
		p.volume_db = -10.0 # Empezar un poco más fuerte
		add_child(p)
		p.play()
		_active_loops[sound_name] = p

func update_loop_params(sound_name: String, vol: float, pitch: float) -> void:
	if _active_loops.has(sound_name):
		var p = _active_loops[sound_name]
		p.volume_db = vol
		p.pitch_scale = pitch

func crossfade_loop(from_name: String, to_name: String, duration: float = 1.0) -> void:
	var stream = _get_stream(to_name)
	if not stream:
		stop_loop(from_name)
		return

	if _active_loops.has(to_name): return

	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		stream.loop = true

	var new_player = AudioStreamPlayer.new()
	new_player.stream = stream
	new_player.bus = "Music"
	new_player.volume_db = -80.0
	add_child(new_player)
	new_player.play()
	_active_loops[to_name] = new_player

	var tween = create_tween().set_parallel(true)
	tween.tween_property(new_player, "volume_db", -10.0, duration)

	if _active_loops.has(from_name):
		var old_player = _active_loops[from_name]
		_active_loops.erase(from_name)
		tween.tween_property(old_player, "volume_db", -80.0, duration)
		tween.chain().tween_callback(func():
			if is_instance_valid(old_player):
				old_player.stop()
				old_player.queue_free()
		)

func stop_loop(sound_name: String) -> void:
	if _active_loops.has(sound_name):
		var p = _active_loops[sound_name]
		p.stop()
		p.queue_free()
		_active_loops.erase(sound_name)

func _get_stream(sound_name: String) -> AudioStream:
	if _sounds.has(sound_name): return _sounds[sound_name]
	if not _external_cache.has(sound_name):
		var paths = ["res://assets/audio/" + sound_name, "res://assets/" + sound_name]
		var found: AudioStream = null
		for p in paths:
			for ext in [".wav", ".mp3", ".ogg"]:
				var full_path = p + ext
				if ResourceLoader.exists(full_path):
					found = load(full_path)
					if found: break
			if found: break
		
		_external_cache[sound_name] = found
		if not found:
			print("AudioManager: No se pudo cargar: ", sound_name)
			
	return _external_cache.get(sound_name)

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

func set_music_volume(db: float) -> void:
	var idx = AudioServer.get_bus_index("Music")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)

func set_sfx_volume(db: float) -> void:
	var idx = AudioServer.get_bus_index("SFX")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)

func set_master_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(0, db)  # índice 0 = Master

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
