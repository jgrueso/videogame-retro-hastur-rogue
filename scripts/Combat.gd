extends Node2D

# ── Estado de combate ──────────────────────────────────────────────────────────
var enemies: Array = []
var player_hp: int = 40
var player_max_hp: int = 40
var player_shield: int = 0
var player_energy: int = 3
var player_max_energy: int = 3

var draw_pile: Array = []
var discard_pile: Array = []
var hand: Array = []
var siervo_attack_bonus: int = 0
var is_player_turn: bool = true
var combat_ended: bool = false
var first_card_this_turn: bool = true
var cards_played_this_turn: int = 0
var velo_used: bool = false
var furia_points: int = 0 # Pasiva del Guardián: daño acumulado para el siguiente ataque

# ── UI References ──────────────────────────────────────────────────────────────
var player_panel: Panel
var player_sprite_label: Label
var lbl_player_hp: Label
var hp_bar_player: ProgressBar
var sanity_bar_player: ProgressBar
var lbl_energy: Label
var lbl_furia: Label
var hand_container: Control
var lbl_draw_pile: Label
var lbl_discard_pile: Label
var end_turn_btn: Button
var relics_container: HBoxContainer
var lbl_message: Label
var vignette: ColorRect
var eye_node: Control
var blink_overlay: ColorRect
var targeting_arrow: Line2D

var targeting_active: bool = false
var targeting_card = null
var time_since_mouse_move: float = 0.0
var is_eye_breaking_4th_wall: bool = false
var last_m_pos: Vector2 = Vector2.ZERO

# ── Pools de encuentros ────────────────────────────────────────────────────────
# ── Setup ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	modulate.a = 0.0
	player_hp = GameManager.player_hp
	player_max_hp = GameManager.player_max_hp
	
	# Reliquias y bonus de energia inicial
	player_max_energy = GameManager.player_max_energy
	if GameManager.has_relic("corona_dorada"):
		player_max_energy += 1
		GameManager.sanity = max(0, GameManager.sanity - 5)
	
	# Sinergia Reliquia: Escudo Astillado
	if GameManager.has_relic("escudo_astillado"):
		player_shield = 5
		
	player_energy = player_max_energy
	
	draw_pile = GameManager.player_deck.duplicate()
	draw_pile.shuffle()

	_setup_encounter()
	build_ui()
	update_ui()
	update_intent_labels()
	_start_enemy_idle_bobs()

	create_tween().tween_property(self, "modulate:a", 1.0, 0.45)

	# Despertar del Ojo (si es la primera vez con baja cordura)
	if GameManager.sanity < 55 and not GameManager.sanity_notified:
		GameManager.sanity_notified = true
		await get_tree().create_timer(0.5).timeout
		_trigger_screen_blink()
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
		show_message("EL TABLERO TE OBSERVA", Color(0.8, 0.4, 1.0))
		await get_tree().create_timer(1.5).timeout
		lbl_message.visible = false

	if not enemies.is_empty():
		var is_avatar = "AVATAR" in enemies[0].name.to_upper()
		
		if GameManager.is_hastur_fight:
			_start_hastur_madness_loop()
		elif not is_avatar:
			var thought = LoreData.get_player_thought(enemies[0].name)
			await get_tree().create_timer(0.9).timeout
			lbl_message.modulate = Color(0.6, 0.6, 0.6)
			lbl_message.visible = true
			await _typewrite(lbl_message, thought, 0.03)
			await get_tree().create_timer(2.0).timeout
			var ft = create_tween()
			ft.tween_property(lbl_message, "modulate:a", 0.0, 0.6)
			await ft.finished
			lbl_message.visible = false
			lbl_message.modulate.a = 1.0

	is_player_turn = true
	await draw_hand()
	
	# --- LÓGICA ESPECIAL AVATAR DE HASTUR ---
	if not enemies.is_empty() and "AVATAR" in enemies[0].name.to_upper():
		await _show_avatar_intro()
		GameManager.sanity = max(0, GameManager.sanity - 30)
		flash_small("¡PRESENCIA ATERRADORA! -30 Cordura")
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play_loop("Glith_distorsion_noised_sound")
			_sync_dynamic_audio()
		update_ui()

	# --- LÓGICA ESPECIAL VERDADERO HASTUR ---
	if GameManager.is_hastur_fight:
		# Hastur ES el caos. Drenaje inicial masivo
		GameManager.sanity = max(0, GameManager.sanity - 50)
		flash_small("¡HASTUR HA LLEGADO! -50 Cordura")
		
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play_loop("Glith_distorsion_noised_sound")
			AudioManager.play_loop("Cry_whisper_woman_sound")
			_sync_dynamic_audio()

	end_turn_btn.disabled = false

func _show_avatar_intro() -> void:
	var vp = get_viewport_rect().size
	
	# Silencio absoluto inicial
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_all()
	
	# Usar CanvasLayer para asegurar que está por encima de todo el HUD y efectos
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	
	# Telón de oscuridad total
	var curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.size = vp # Forzar tamaño manual
	layer.add_child(curtain)
	
	var quote_lbl = Label.new()
	quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	quote_lbl.position = Vector2(vp.x * 0.2, vp.y * 0.3)
	quote_lbl.size = Vector2(vp.x * 0.6, vp.y * 0.4)
	quote_lbl.add_theme_font_size_override("font_size", 22)
	quote_lbl.modulate = Color(0.9, 0.8, 0.3)
	layer.add_child(quote_lbl)
	
	var chambers_quote = "Canto de mi alma, se me ha muerto la voz. Muere, sin ser cantada, como las lágrimas no derramadas se secan y mueren en la Perdida Carcosa..."
	
	# Typewriter mucho más lento y solemne
	await _typewrite(quote_lbl, chambers_quote, 0.08)
	await get_tree().create_timer(2.0).timeout
	
	# --- EFECTO ROTOSCOPIA / GLITCH / FLASH ---
	quote_lbl.visible = false
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("Glith_distorsion_noised_sound") # Usar audio externo
	
	# Simulamos rotoscopia con destellos
	for i in range(12):
		curtain.color = [Color.WHITE, Color.BLACK, Color.YELLOW, Color.RED][randi() % 4]
		_trigger_screen_blink()
		await get_tree().create_timer(0.05).timeout
	
	curtain.color = Color.BLACK
	
	# Desvanecer oscuridad con un último flash
	var tw = create_tween()
	tw.tween_property(layer, "offset:y", -vp.y, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(curtain, "modulate:a", 0.0, 1.5)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("player_hit")
	
	await tw.finished
	layer.queue_free()

func _show_avatar_bark() -> void:
	if enemies.is_empty() or not "AVATAR" in enemies[0].name.to_upper(): return
	var msg = CombatData.ENEMY_COMBAT_BANTER["Avatar de Hastur"][randi() % CombatData.ENEMY_COMBAT_BANTER["Avatar de Hastur"].size()]
	
	var bark_lbl = Label.new()
	bark_lbl.text = msg
	bark_lbl.add_theme_font_size_override("font_size", 14)
	bark_lbl.modulate = Color(0.8, 0.7, 0.9, 0.0)
	bark_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Posición sobre el avatar
	bark_lbl.position = enemies[0].panel.global_position + Vector2(0, -40)
	bark_lbl.size = Vector2(200, 40)
	add_child(bark_lbl)
	
	var tw = create_tween()
	tw.tween_property(bark_lbl, "modulate:a", 1.0, 0.5)
	tw.tween_property(bark_lbl, "position:y", bark_lbl.position.y - 30, 3.0)
	tw.parallel().tween_property(bark_lbl, "modulate:a", 0.0, 2.0).set_delay(1.5)
	tw.chain().tween_callback(bark_lbl.queue_free)

func _setup_encounter() -> void:
	var pool = []
	if GameManager.is_hastur_fight:
		pool = [{"name": "EL VERDADERO HASTUR", "hp": 350, "pattern": [
			{"type": "insanity", "value": 15}, 
			{"type": "attack", "value": 20}, 
			{"type": "possession", "value": 0}, 
			{"type": "attack", "value": 15},
			{"type": "ultimate_charge", "value": 0},
			{"type": "ultimate_attack", "value": 45}
		]}]
	elif GameManager.is_final_boss:
		if GameManager.current_world == 1:
			pool = [{"name": "EL REY AMARILLO",   "hp": 180, "pattern": [{"type": "attack", "value": 14}, {"type": "shield", "value": 10}, {"type": "attack", "value": 18}]}]
		else:
			pool = [{"name": "EL REY SIN CORONA", "hp": 120, "pattern": [{"type": "attack", "value": 12}, {"type": "shield", "value": 8},  {"type": "attack", "value": 15}]}]
	elif GameManager.is_boss_fight:
		if GameManager.current_world == 0:
			pool = CombatData.BOSS_POOLS_W1[randi() % CombatData.BOSS_POOLS_W1.size()]
		else:
			pool = [{"name": "EL CARCELERO", "hp": 100, "pattern": [{"type": "attack", "value": 10}, {"type": "shield", "value": 8}]}]
	elif GameManager.is_elite_fight or GameManager.dev_force_avatar:
		# --- PROBABILIDAD ESCALADA DEL AVATAR ---
		var items_count = GameManager.secret_items.size()
		var spawn_chance = 0.0
		if items_count == 1: spawn_chance = 0.15
		elif items_count == 2: spawn_chance = 0.30
		elif items_count >= 3: spawn_chance = 0.50
		
		# Forzar si viene del menu dev
		if GameManager.dev_force_avatar:
			spawn_chance = 1.1
			GameManager.dev_force_avatar = false # Resetear
		
		if randf() < spawn_chance:
			pool = CombatData.ELITE_POOLS[0] # Avatar de Hastur siempre es el 0 en ELITE_POOLS
		else:
			var sub_pool = CombatData.ELITE_POOLS.duplicate()
			sub_pool.remove_at(0) # Quitar Avatar de la seleccion normal
			pool = sub_pool[randi() % sub_pool.size()]
	elif GameManager.dev_force_penitente:
		GameManager.dev_force_penitente = false
		for p in CombatData.NORMAL_POOLS:
			if p[0]["name"] == "El Penitente":
				pool = p
				break
	else:
		pool = CombatData.NORMAL_POOLS[randi() % CombatData.NORMAL_POOLS.size()]

	enemies.clear()
	for e_data in pool:
		var pen_mode = ""
		if e_data["name"] == "El Penitente":
			pen_mode = "silence" if randf() < 0.5 else "mercy"
			if get_node_or_null("/root/AudioManager"):
				AudioManager.play("Cry_whisper_woman_sound")
		
		enemies.append({
			"name":          e_data["name"],
			"hp":            e_data["hp"],
			"max_hp":        e_data["hp"],
			"shield":        0,
			"pattern":       e_data["pattern"].duplicate(true), # Duplicación profunda para poder modificar valores
			"turn_index":    0,
			"peaceful":      e_data.get("peaceful", false),
			"peaceful_turns": e_data.get("peaceful_turns", 0),
			"penitente_mode": pen_mode, # "silence" o "mercy"
			"has_phase_2":   true if (GameManager.is_boss_fight or GameManager.is_final_boss or GameManager.is_hastur_fight) else false,
			"in_phase_2":    false,
			"panel":         null,
			"hp_bar":        null,
			"lbl_hp":        null,
			"lbl_shield":    null,
			"sprite_label":  null,
			"lbl_intent_icon": null,
		})

# ── Build UI ───────────────────────────────────────────────────────────────────
func build_ui() -> void:
	var vp = get_viewport_rect().size
	_build_dynamic_background(vp)

	player_panel = _make_panel(Vector2(20, 280), Vector2(560, 125), Color(0.06, 0.06, 0.1), Color(0.4, 0.4, 0.6))
	add_child(player_panel)

	var char_id = GameManager.selected_character
	var char_info = CombatData.CHAR_DATA.get(char_id, {"symbol": "♟", "color": Color(0.8, 0.8, 0.8)})
	player_sprite_label = Label.new()
	player_sprite_label.text = char_info["symbol"]
	player_sprite_label.modulate = char_info["color"]
	player_sprite_label.add_theme_font_size_override("font_size", 60)
	player_sprite_label.position = Vector2(10, 15)
	player_sprite_label.size = Vector2(80, 90)
	player_sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_panel.add_child(player_sprite_label)
	_start_player_idle_bob()

	hp_bar_player = _make_hp_bar(player_max_hp, 440); hp_bar_player.position = Vector2(100, 40); player_panel.add_child(hp_bar_player)

	sanity_bar_player = _make_hp_bar(100, 440); sanity_bar_player.position = Vector2(100, 58); player_panel.add_child(sanity_bar_player)
	var sb_style = StyleBoxFlat.new(); sb_style.bg_color = Color(0.1, 0.05, 0.2); sb_style.set_corner_radius_all(4)
	var sb_fill = StyleBoxFlat.new(); sb_fill.bg_color = Color(0.5, 0.3, 0.8)
	sanity_bar_player.add_theme_stylebox_override("background", sb_style)
	sanity_bar_player.add_theme_stylebox_override("fill", sb_fill)

	lbl_player_hp = Label.new(); lbl_player_hp.position = Vector2(100, 15); player_panel.add_child(lbl_player_hp)

	lbl_energy = Label.new(); lbl_energy.position = Vector2(100, 78); player_panel.add_child(lbl_energy)

	if char_id == "guardian":
		lbl_furia = Label.new()
		lbl_furia.position = Vector2(300, 78)
		lbl_furia.add_theme_font_size_override("font_size", 14)
		lbl_furia.modulate = Color(0.4, 0.9, 0.4)
		player_panel.add_child(lbl_furia)


	hand_container = Control.new()
	hand_container.position = Vector2(20, 418); hand_container.size = Vector2(1112, 195)
	add_child(hand_container)

	lbl_draw_pile    = _make_pile_label(Vector2(950, 540), Color(0.7, 0.7, 0.9))
	lbl_discard_pile = _make_pile_label(Vector2(950, 575), Color(0.6, 0.5, 0.4))
	add_child(lbl_draw_pile); add_child(lbl_discard_pile)

	end_turn_btn = Button.new(); end_turn_btn.text = "TERMINAR TURNO"
	end_turn_btn.position = Vector2(900, 480); end_turn_btn.size = Vector2(230, 50)
	end_turn_btn.pressed.connect(_on_end_turn_button_pressed); add_child(end_turn_btn)

	lbl_message = Label.new(); lbl_message.position = Vector2(100, 180); lbl_message.size = Vector2(952, 200)
	lbl_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_message.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_message.z_index = 10; lbl_message.visible = false; add_child(lbl_message)

	# Paneles enemigos
	for i in range(enemies.size()):
		var is_peaceful = enemies[i].peaceful
		var border_col = Color(0.2, 0.5, 0.2) if is_peaceful else Color(0.6, 0.2, 0.2)
		var bg_col     = Color(0.04, 0.1, 0.04) if is_peaceful else Color(0.1, 0.05, 0.05)
		var ep = _make_panel(Vector2(650 + i*220, 80), Vector2(200, 230), bg_col, border_col)
		ep.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(ep); enemies[i].panel = ep
		
		# Conectar señales para Tooltips de Intencion
		var idx = i
		ep.mouse_entered.connect(func(): _show_enemy_intent_tooltip(idx))
		ep.mouse_exited.connect(func(): _hide_enemy_intent_tooltip(idx))

		var en = Label.new(); en.text = enemies[i].name
		en.position = Vector2(0, 8); en.size = Vector2(200, 30)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en.add_theme_font_size_override("font_size", 11)
		en.modulate = Color(0.5, 1.0, 0.5) if is_peaceful else Color.WHITE
		ep.add_child(en); enemies[i].lbl_name = en

		var esl = Label.new(); esl.text = _get_enemy_symbol(enemies[i].name)
		esl.add_theme_font_size_override("font_size", 60)
		esl.position = Vector2(0, 38); esl.size = Vector2(200, 90)
		esl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ep.add_child(esl); enemies[i].sprite_label = esl

		var elh = Label.new(); elh.position = Vector2(10, 135); elh.size = Vector2(180, 20); ep.add_child(elh); enemies[i].lbl_hp = elh
		var ebl = Label.new(); ebl.position = Vector2(10, 155); ebl.size = Vector2(180, 20)
		ebl.modulate = Color(0.4, 0.7, 1.0); ep.add_child(ebl); enemies[i].lbl_shield = ebl
		var eh = _make_hp_bar(enemies[i].max_hp, 180); eh.position = Vector2(10, 178); ep.add_child(eh); enemies[i].hp_bar = eh

		var lin = Label.new(); lin.position = Vector2(0, 205); lin.size = Vector2(200, 22)
		lin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lin.add_theme_font_size_override("font_size", 11)
		ep.add_child(lin); enemies[i].lbl_intent_icon = lin

	targeting_arrow = Line2D.new(); targeting_arrow.width = 4
	targeting_arrow.default_color = Color(1, 0.8, 0.2); targeting_arrow.visible = false; add_child(targeting_arrow)

	relics_container = HBoxContainer.new()
	relics_container.position = Vector2(10, 10)
	relics_container.add_theme_constant_override("separation", 6)
	add_child(relics_container)
	_populate_relics()

	# Viñeta de Cordura
	vignette = ColorRect.new()
	vignette.size = vp
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0, 0, 0, 0) # Empieza invisible
	vignette.z_index = 40 # Encima de todo menos mensajes criticos
	add_child(vignette)

	blink_overlay = ColorRect.new()
	blink_overlay.size = vp
	blink_overlay.color = Color.BLACK
	blink_overlay.visible = false
	blink_overlay.z_index = 60 # El parpadeo tapa todo
	add_child(blink_overlay)

	var dev_toggle = Button.new(); dev_toggle.text = "[DEV]"
	dev_toggle.position = Vector2(vp.x - 80, vp.y - 36); dev_toggle.size = Vector2(75, 30)
	dev_toggle.modulate = Color(0.5, 0.5, 0.5, 0.45)
	add_child(dev_toggle)

	# Botón Visor de Mazo
	var deck_btn = Button.new()
	deck_btn.text = " ▣ VER MAZO "
	deck_btn.position = Vector2(vp.x - 160, 10); deck_btn.size = Vector2(150, 40)
	deck_btn.add_theme_font_size_override("font_size", 14)
	add_child(deck_btn)
	deck_btn.pressed.connect(_show_deck_viewer)

	var dev_panel = _build_dev_panel(vp)
	dev_panel.visible = false
	add_child(dev_panel)
	dev_toggle.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)

func _get_enemy_symbol(e_name: String) -> String:
	match e_name:
		"EL VERDADERO HASTUR": return "♆"
		"EL CARCELERO":        return "♔"
		"EL REY SIN CORONA":   return "♚"
		"EL REY AMARILLO":     return "♛"
		"Torre Rota":          return "♖"
		"Caballero Roto":      return "♘"
		"Inquisidor Ciego":    return "♗"
		"Alfil Caido":         return "♝"
		"Espectro":            return "👁"
		"Peon Maldito":        return "♟"
		"El Penitente":        return "✝"
		_:                     return "☠"

func _build_dynamic_background(vp: Vector2) -> void:
	var is_w2 = GameManager.current_world == 1
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02) if not is_w2 else Color(0.04, 0.03, 0.01)
	bg.size = vp; bg.z_index = -10; add_child(bg)
	var sz = 450.0 if not is_w2 else 650.0
	var sun = Panel.new(); sun.size = Vector2(sz, sz); sun.position = Vector2(vp.x/2 - sz/2, -100)
	var sun_st = StyleBoxFlat.new(); sun_st.bg_color = Color(0,0,0)
	sun_st.set_corner_radius_all(sz/2); sun_st.border_width_left = 4
	sun_st.border_color = Color(0.9, 0.6, 0.1, 0.3)
	sun.add_theme_stylebox_override("panel", sun_st); sun.z_index = -9; add_child(sun)

	# El Ojo del Vacio (REDISEÑO GIGANTE)
	eye_node = Control.new()
	eye_node.position = sun.position + sun.size/2
	eye_node.z_index = -8; eye_node.modulate.a = 0.0 
	add_child(eye_node)

	var eye_w = 320.0
	var eye_h = 160.0

	var eye_bg = Panel.new() # Esclerotica (Almendra simetrica)
	eye_bg.size = Vector2(eye_w, eye_h); eye_bg.position = -eye_bg.size/2
	var es = StyleBoxFlat.new(); es.bg_color = Color(0.85, 0.8, 0.6)
	# Forma de almendra: esquinas superior e inferior redondeadas, laterales afilados
	es.set_corner_radius(CORNER_TOP_LEFT, 160)
	es.set_corner_radius(CORNER_TOP_RIGHT, 160)
	es.set_corner_radius(CORNER_BOTTOM_RIGHT, 160)
	es.set_corner_radius(CORNER_BOTTOM_LEFT, 160)
	# Para afilar los lados en Godot Panel, lo mejor es usar un radio que no llegue a ser un circulo perfecto
	es.border_width_left = 2; es.border_width_right = 2
	es.border_color = Color(0.2, 0.1, 0.0)
	eye_bg.add_theme_stylebox_override("panel", es); eye_node.add_child(eye_bg)

	var iris = Panel.new() # Iris Ambar
	iris.size = Vector2(140, 140); iris.position = -iris.size/2
	var is_style = StyleBoxFlat.new(); is_style.bg_color = Color(0.7, 0.4, 0.1); is_style.set_corner_radius_all(70)
	is_style.border_width_left = 10; is_style.border_color = Color(0.4, 0.2, 0.0)
	iris.add_theme_stylebox_override("panel", is_style); eye_node.add_child(iris); iris.name = "Iris"

	var pupil = Panel.new() # Pupila Rasgada (como gato/reptil)
	pupil.size = Vector2(45, 110); pupil.position = -pupil.size/2
	var ps = StyleBoxFlat.new(); ps.bg_color = Color(0,0,0); ps.set_corner_radius_all(22)
	pupil.add_theme_stylebox_override("panel", ps); iris.add_child(pupil); pupil.name = "Pupil"

	var lid_top = ColorRect.new() # Parpado superior mas grueso
	lid_top.size = Vector2(eye_w + 40, eye_h); lid_top.position = Vector2(-eye_w/2 - 20, -eye_h - 20); lid_top.color = Color.BLACK
	eye_node.add_child(lid_top); lid_top.name = "LidTop"

	var lid_bot = ColorRect.new() # Parpado inferior mas grueso
	lid_bot.size = Vector2(eye_w + 40, eye_h); lid_bot.position = Vector2(-eye_w/2 - 20, eye_h/2 + 10); lid_bot.color = Color.BLACK
	eye_node.add_child(lid_bot); lid_bot.name = "LidBot"

	_start_eye_blink_loop()
	# Lluvia de fondo
	var is_avatar = not enemies.is_empty() and "AVATAR" in enemies[0].name.to_upper()
	
	for i in range(60):
		var p = ColorRect.new(); p.size = Vector2(1, 15)
		# Si es el Avatar, la lluvia es ROJA (Sangre)
		p.color = Color(0.8, 0.1, 0.1, 0.4) if is_avatar else Color(0.5, 0.5, 0.7, 0.15)
		p.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y)); p.z_index = -8; add_child(p)
		create_tween().set_loops().tween_property(p, "position:y", vp.y + 20, randf_range(0.8, 1.2)).from(-20)

# ── Cartas ─────────────────────────────────────────────────────────────────────
func draw_hand() -> void:
	for c in hand_container.get_children(): c.queue_free()
	for h in hand: discard_pile.append(h)
	hand.clear()
	
	# Efecto Cordura Alta: Claridad (+1 carta)
	var to_draw = 3
	if GameManager.sanity >= 80: to_draw += 1
	# Pasiva Estratega: Mayor robo
	if GameManager.selected_character == "estratega": to_draw += 1
	
	var deck_pos = lbl_draw_pile.global_position
	for i in range(to_draw):
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate(); discard_pile.clear(); draw_pile.shuffle()
		if draw_pile.is_empty(): break
		var c_data = draw_pile.pop_front()
		hand.append(c_data)
		_spawn_card_node(c_data, deck_pos, i * 0.1)
		
	update_card_states()
	if get_node_or_null("/root/AudioManager"): AudioManager.play("card_draw")
	
	reorganize_hand()

func reorganize_hand() -> void:
	# Filtrar solo las cartas que no se están borrando
	var all_children = hand_container.get_children()
	var cards = []
	for c in all_children:
		if not c.is_queued_for_deletion():
			cards.append(c)
			
	var n = cards.size()
	if n == 0: return
	
	var sep = 10 # Un poco menos de separación para que quepan bien a la izquierda
	var card_w = 130
	var start_x = 10 # Margen izquierdo fijo
	
	for i in range(n):
		var card = cards[i]
		var target_x = start_x + i * (card_w + sep)
		var target_pos = Vector2(target_x, 0)
		
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(card, "position", target_pos, 0.3)

func _spawn_card_node(data_in: Dictionary, start_pos: Vector2 = Vector2.ZERO, delay: float = 0.0) -> void:
	var data = data_in.duplicate(true)
	var card_scene = preload("res://scenes/combat/Card.tscn")
	var card = card_scene.instantiate()
	
	hand_container.add_child(card)
	card.setup(data)
	
	if start_pos != Vector2.ZERO:
		card.animate_draw(start_pos, delay)
	
	# Pasiva Estratega: Inquisidores mas baratos (Visual y Logica)
	if GameManager.selected_character == "estratega" and "INQUISIDOR" in data.get("name", "").to_upper():
		card.set_cost_modifier(-1)
		
	card.connect("card_selected", _on_card_selected)
	card.connect("card_played",   _on_card_played)

func _on_card_selected(card) -> void:
	targeting_active = true; targeting_card = card; targeting_arrow.visible = true

func _on_card_played(card) -> void:
	_resolve_card(card, -1)

# ── Targeting ──────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	# Deteccion de movimiento de raton para inactividad
	var m_pos = get_global_mouse_position()
	if m_pos.distance_to(last_m_pos) > 1.0:
		time_since_mouse_move = 0.0
		is_eye_breaking_4th_wall = false
	else:
		time_since_mouse_move += _delta
		if time_since_mouse_move > 8.0:
			is_eye_breaking_4th_wall = true
	last_m_pos = m_pos

	# Actualizar Vignette y Tinte de Locura
	var sanity_factor = clamp((60.0 - GameManager.sanity) / 60.0, 0.0, 1.0)
	if vignette:
		if GameManager.sanity < 60:
			vignette.visible = true
			if not vignette.material:
				var sh = Shader.new()
				sh.code = "shader_type canvas_item; uniform float intensity; uniform vec3 tint; void fragment() { float d = distance(UV, vec2(0.5)); vec4 color = vec4(tint, smoothstep(0.2, 0.6, d) * intensity); COLOR = color; }"
				var mat = ShaderMaterial.new(); mat.shader = sh
				vignette.material = mat
			
			var t_col = Vector3(0, 0, 0)
			if GameManager.sanity < 30: t_col = Vector3(0.2, 0.15, 0.0)
			
			vignette.material.set_shader_parameter("intensity", sanity_factor * 0.8)
			vignette.material.set_shader_parameter("tint", t_col)
		else:
			vignette.visible = false

	# Actualizar Ojo del Vacio
	if is_instance_valid(eye_node):
		var eye_intensity = clamp((55.0 - GameManager.sanity) / 55.0, 0.0, 1.0)
		eye_node.modulate.a = eye_intensity * 0.95
		eye_node.scale = Vector2(1, 1) * (0.6 + eye_intensity * 0.4)
		
		# Movimiento de pupila e iris
		var iris_node = eye_node.get_node("Iris")
		var pupil_node = iris_node.get_node("Pupil")
		var m_dir = (get_global_mouse_position() - iris_node.global_position).normalized()
		
		if is_eye_breaking_4th_wall:
			m_dir = Vector2.ZERO # Mirar directo al frente (al jugador)
			iris_node.modulate = Color(1.5, 1.2, 1.2) # Brillo sutil de interes
		else:
			iris_node.modulate = Color.WHITE
			
		iris_node.position = (m_dir * 25.0) - iris_node.size/2
		
		# Temblor de pupila en baja cordura
		var p_pos = (m_dir * 10.0) - pupil_node.size/2
		if GameManager.sanity < 30:
			var p_shake = (30.0 - GameManager.sanity) * 0.4
			p_pos += Vector2(randf_range(-p_shake, p_shake), randf_range(-p_shake, p_shake))
			# Dilatacion erratica
			pupil_node.scale.x = 1.0 + randf_range(-0.2, 0.5)
		else:
			pupil_node.scale.x = 1.0
			
		pupil_node.position = p_pos

	# Efecto de temblor sutil (solo en baja cordura)
	if not combat_ended and GameManager.sanity < 40:
		var shake = (40.0 - GameManager.sanity) * 0.08
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		position = Vector2.ZERO

	# Logica de Parpadeo (Blinks)
	if not combat_ended and GameManager.sanity < 35:
		if randf() < 0.005: 
			_trigger_screen_blink()
			if GameManager.sanity < 25 and randf() < 0.3:
				if get_node_or_null("/root/AudioManager"): AudioManager.play("agony_shriek")

	# Oscilacion suave de nombres (Efecto de agua/eco)
	if not combat_ended and GameManager.sanity < 50:
		var t = Time.get_ticks_msec() / 1000.0
		for e in enemies:
			if e.hp > 0 and e.lbl_name:
				e.lbl_name.position.x = sin(t * 2.0 + e.hp) * 5.0
				e.lbl_name.modulate.a = 0.6 + sin(t * 3.0) * 0.4

	if targeting_active and targeting_card:
		targeting_arrow.clear_points()
		targeting_arrow.add_point(targeting_card.global_position + Vector2(65, 0))
		targeting_arrow.add_point(get_global_mouse_position())

func _input(event: InputEvent) -> void:
	if targeting_active and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_check_targeting()

func _check_targeting() -> void:
	var m_pos = get_global_mouse_position()
	var target = -1
	for i in range(enemies.size()):
		if enemies[i].hp > 0 and enemies[i].panel.get_global_rect().has_point(m_pos):
			target = i; break
	if target >= 0:
		_resolve_card(targeting_card, target)
	else:
		targeting_card.set_disabled(false)
	targeting_active = false; targeting_arrow.visible = false; targeting_card = null

var _is_resolving_extra_mirror_card: bool = false

# ── Resolver carta ─────────────────────────────────────────────────────────────
func _resolve_card(card, enemy_idx: int) -> void:
	# Lógica del Espejo Fragmentado: Jugar la primera carta dos veces
	if first_card_this_turn and GameManager.has_relic("espejo_fragmentado") and not _is_resolving_extra_mirror_card:
		_is_resolving_extra_mirror_card = true
		_resolve_card(card, enemy_idx)
		_is_resolving_extra_mirror_card = false
		flash_small("¡ESPEJO FRAGMENTADO! Movimiento duplicado.")

	var effective_cost = card.get_effective_cost()
	if player_energy < effective_cost: return
	player_energy -= effective_cost
	
	# Efecto Cordura Baja: Desobediencia
	if GameManager.sanity < 40 and "SIERVO QUEBRADO" in card.card_name and randf() < 0.20:
		flash_small("Tus manos no te obedecen...")
		card.queue_free()
		update_ui(); update_card_states(); check_combat_end()
		return

	for i in range(hand.size()):
		if hand[i].get("name", "").to_upper() == card.card_name:
			hand.remove_at(i); break
	discard_pile.append({"name": card.card_name, "attack": card.attack, "defense": card.defense, "cost": card.cost})

	if get_node_or_null("/root/AudioManager"): AudioManager.play("card_play")

	# ── LÓGICA DE CARTAS ESPECIALES (Independientes de ataque base) ──
	
	# ECO DEL VACIO (AOE)
	if "ECO DEL VACIO" in card.card_name or "ECO DEL VACÍO" in card.card_name:
		flash_small("¡ECO DEL VACIO! Todos los enemigos sufren.")
		for e_aoe in enemies:
			if e_aoe.hp > 0:
				# Daño base 4 + bono de mejora (guardado en attack)
				var a_dmg = 4 + card.attack + (GameManager.siervo_atk_bonus_perm if GameManager.selected_character == "conquistador" else 0)
				e_aoe.hp -= a_dmg
				_spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), a_dmg, Color(0.7, 0.7, 1.0))
				_animate_enemy_hit(e_aoe)
		check_combat_end(); update_ui(); update_intent_labels()

	# SUSURRO DEBILITANTE (Debuff AOE)
	elif "SUSURRO DEBILITANTE" in card.card_name:
		var is_last = hand.is_empty()
		# Debilitamiento base 6 + bono de mejora (guardado en attack)
		var base_red = 6 + card.attack
		var reduction = base_red * 2 if is_last else base_red
		
		for e_deb in enemies:
			if e_deb.hp > 0:
				e_deb["atk_reduction"] = e_deb.get("atk_reduction", 0) + reduction
		
		if is_last:
			flash_small("¡SUSURRO FINAL! Todos debilitados: -" + str(reduction))
			_trigger_screen_blink()
		else:
			flash_small("Susurro: Todos -" + str(reduction) + " ATK")
			
		update_intent_labels(); update_ui()

	# ── LÓGICA DE CARTAS CON OBJETIVO Y ATAQUE ──
	elif enemy_idx >= 0:
		var e = enemies[enemy_idx]
		
		# El Penitente: atacarle lo hace agresivo
		if e.peaceful and card.attack > 0:
			e.peaceful = false
			e.peaceful_turns = 0
			_show_enemy_banter(e.panel, "...Asi lo quieres. Bien.", Color(0.9, 0.4, 0.4))
			_set_enemy_aggressive(e)

		var dmg = card.attack
		
		# --- VULNERABILIDAD A LA LOCURA (Solo contra Avatar) ---
		if "AVATAR" in e.name.to_upper():
			var lost_sanity = 100 - GameManager.sanity
			var multiplier = 1.0 + (lost_sanity * 0.015) # +1.5% por punto perdido
			var old_dmg = dmg
			dmg = int(dmg * multiplier)
			if dmg > old_dmg:
				flash_small("¡CONEXIÓN ABISAL! Daño aumentado por tu locura.")

		# Lógica especial para JAQUE ETERNO (Canaliza tu dolor)
		if "JAQUE ETERNO" in card.card_name:
			dmg = player_max_hp - player_hp
			flash_small("¡JAQUE ETERNO! Dolor canalizado: " + str(dmg))
			_trigger_screen_blink()
			if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")

		# Pasiva Conquistador: Bono permanente
		if card.card_name.begins_with("SIERVO"): 
			dmg += GameManager.siervo_atk_bonus_perm
		
		# Pasiva Guardian: Furia (Daño x2)
		if GameManager.selected_character == "guardian" and furia_points >= 3:
			dmg = dmg * 2
			furia_points = 0 # Furia consumida
			flash_small("¡RESILIENCIA! Daño duplicado.")
			_trigger_screen_blink()
			update_ui()

		var absorbed = min(e.shield, dmg)
		if absorbed > 0:
			e.shield -= absorbed; dmg -= absorbed
			_animate_shield_block(e)
			if get_node_or_null("/root/AudioManager"): AudioManager.play("shield_block")
		if dmg > 0:
			e.hp -= dmg
			_spawn_damage_number(e.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
			_animate_enemy_hit(e)
			if get_node_or_null("/root/AudioManager"): AudioManager.play("enemy_hit")
			
			# Lógica de Fase 2
			if e.has_phase_2 and not e.in_phase_2 and e.hp > 0 and e.hp <= (e.max_hp * 0.5):
				_trigger_boss_phase_2(e)
		
		# Muerte de enemigo
		if e.hp <= 0:
			e.hp = 0
			
			# BOTÓN MISTERIOSO (15%): Fragmento Eterno
			if "AVATAR" in e.name.to_upper():
				if randf() < 0.15:
					GameManager.has_eternal_fragment = true
					flash_small("✦ ¡HAS OBTENIDO UN FRAGMENTO DE ETERNIDAD! ✦")
					flash_small("Tus cartas ahora pueden trascender el tiempo.")
					GameManager.save_meta_progress()
					if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
			
			# Recuperación de Cordura al matar (Alivio en peligro)
			if GameManager.sanity < 30:
				GameManager.sanity = min(100, GameManager.sanity + 5)
				flash_small("¡CLARIDAD! +5 Cordura")
			
			if GameManager.selected_character == "conquistador":
				GameManager.siervo_atk_bonus_perm += 1
				GameManager.heal(3)
				player_hp = GameManager.player_hp # Sincronizar vida local
				flash_small("¡CONQUISTA! Siervos: +1 ATK | +3 HP")
				refresh_hand_visuals()
			
			# Sinergia Reliquia: Sangre del Caido
			if GameManager.has_relic("sangre_caido"):
				GameManager.siervo_atk_bonus_perm += 1
				flash_small("Sangre del Caido: +1 ATK extra!")
				refresh_hand_visuals()
				
			_kill_enemy(e) # async

	if card.defense > 0:
		player_shield += card.defense
		_spawn_damage_number(player_panel.global_position + Vector2(200, 30), card.defense, Color(0.4, 0.7, 1.0))

	# Animación de gasto/ataque
	var target_pos = Vector2.ZERO
	if enemy_idx >= 0:
		target_pos = enemies[enemy_idx].panel.global_position + Vector2(100, 100)
	
	await card.play_attack_animation(target_pos)

	first_card_this_turn = false
	card.queue_free()
	
	# Reorganizar la mano inmediatamente después de eliminar la carta
	reorganize_hand()
	# Logica Reloj de Arena Negra
	cards_played_this_turn += 1
	if GameManager.has_relic("reloj_negro") and cards_played_this_turn % 3 == 0:
		player_energy = min(player_energy + 1, player_max_energy)
		flash_small("Reloj: +1 Energia!")

	update_ui(); update_intent_labels(); check_combat_end()

func _set_enemy_aggressive(e: Dictionary) -> void:
	# Cambiar panel a rojo
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.05, 0.05)
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.border_color = Color(0.6, 0.2, 0.2)
	e.panel.add_theme_stylebox_override("panel", s)
	if e.lbl_name: e.lbl_name.modulate = Color.WHITE
	# Flash rojo corregido (sin chain)
	var tw = create_tween()
	tw.tween_property(e.panel, "modulate", Color(1.5, 0.3, 0.3), 0.1)
	tw.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.3)

# ── Sistema de Descifrado de Pensamientos ─────────────────────────────────────
func _get_deciphered_thought(original: String) -> String:
	var sanity = GameManager.sanity
	var legibility = (100.0 - sanity) / 100.0 # 0.0 a 1.0
	
	if sanity <= 0: return original # Claridad total
	
	var result = ""
	var symbols = ["@", "#", "$", "%", "&", "*", "§", "Δ", "Ω", "▓", "░", "▒", "†", "‡"]
	
	for i in range(original.length()):
		var c = original[i]
		if c == " " or c == "\n":
			result += c
			continue
		
		# Decidir si este caracter es legible
		if randf() < legibility:
			result += c
		else:
			result += symbols[randi() % symbols.size()]
	
	return result

func _get_penitente_thought() -> String:
	var thoughts = [
		"AYUDAME A SALIR DEL CICLO",
		"EL JUGADOR NOS ESTA MIRANDO",
		"HEMOS MUERTO MIL VECES AQUI",
		"EL TABLERO ES UNA PRISION DE CARNE",
		"NO ERES EL PRIMERO EN LLEGAR",
		"EL REY TIENE SED DE MEMORIAS"
	]
	return thoughts[GameManager.total_runs % thoughts.size()]

# ── Animaciones ────────────────────────────────────────────────────────────────
func _animate_enemy_attack_unique(e: Dictionary) -> void:
	if not e.panel: return
	var orig = e.panel.position
	var t = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	match e.name:
		"EL CARCELERO":
			# Salto y caida pesada
			t.tween_property(e.panel, "position:y", orig.y - 40, 0.2)
			t.tween_property(e.panel, "position:y", orig.y + 20, 0.1)
			t.parallel().tween_property(e.panel, "scale", Vector2(1.2, 0.8), 0.1) # Impacto
			t.tween_property(e.panel, "position", orig, 0.2)
			t.parallel().tween_property(e.panel, "scale", Vector2(1, 1), 0.2)
			await t.finished
			# Temblor de pantalla sutil
			var st = create_tween().set_loops(4)
			st.tween_property(self, "position", Vector2(randf_range(-5,5), randf_range(-5,5)), 0.05)
			st.tween_property(self, "position", Vector2.ZERO, 0.05)
		
		"LA DAMA DE CENIZA":
			# Brillo incandescente
			t.tween_property(e.panel, "modulate", Color(2.5, 0.8, 0.2), 0.15)
			t.tween_property(e.panel, "position:x", orig.x - 30, 0.1)
			# Particulas de ceniza hacia el jugador
			_spawn_death_particles(e.panel.global_position + Vector2(0, 100))
			t.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.3)
			t.parallel().tween_property(e.panel, "position", orig, 0.3)
			await t.finished
			
		"EL MARISCAL":
			# Carga rapida
			t.tween_property(e.panel, "position:x", orig.x - 150, 0.15).set_trans(Tween.TRANS_EXPO)
			t.tween_property(e.panel, "position:x", orig.x + 20, 0.05)
			t.tween_property(e.panel, "position", orig, 0.2)
			await t.finished
			
		"EL VERDADERO HASTUR":
			# Glitch total
			is_eye_breaking_4th_wall = true
			t.tween_property(e.panel, "scale", Vector2(1.5, 1.5), 0.1)
			t.parallel().tween_property(e.panel, "modulate", Color(0,0,0), 0.1)
			if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
			await get_tree().create_timer(0.15).timeout
			e.panel.scale = Vector2(1,1); e.panel.modulate = Color.WHITE
			is_eye_breaking_4th_wall = false
			
		_:
			# Ataque generico
			var is_weak = e.get("atk_reduction", 0) > 0
			var dist = -40 if not is_weak else -15
			
			t.tween_property(e.panel, "position:x", orig.x + dist, 0.15)
			t.tween_property(e.panel, "position", orig, 0.2)
			
			if is_weak:
				var st = create_tween().set_loops(3)
				st.tween_property(e.panel, "position:y", orig.y - 4, 0.05)
				st.tween_property(e.panel, "position:y", orig.y, 0.05)
				
			await t.finished

func _animate_enemy_hit(e: Dictionary) -> void:
	if not e.panel: return
	var orig = e.panel.position
	var t = create_tween()
	t.tween_property(e.panel, "modulate", Color(1.4, 0.3, 0.3), 0.05)
	t.tween_property(e.panel, "position", orig + Vector2(-8, 0), 0.04)
	t.tween_property(e.panel, "position", orig + Vector2(8, 0), 0.04)
	t.tween_property(e.panel, "position", orig + Vector2(-5, 0), 0.04)
	t.tween_property(e.panel, "position", orig, 0.04)
	t.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.1)

func _animate_shield_block(e: Dictionary) -> void:
	if not e.panel: return
	var t = create_tween()
	t.tween_property(e.panel, "modulate", Color(0.4, 0.6, 1.4), 0.06)
	t.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.2)

func _animate_player_hit() -> void:
	var orig = player_panel.position
	var t = create_tween()
	t.tween_property(player_panel, "modulate", Color(1.4, 0.3, 0.3), 0.05)
	t.tween_property(player_panel, "position", orig + Vector2(-6, 0), 0.04)
	t.tween_property(player_panel, "position", orig + Vector2(6, 0), 0.04)
	t.tween_property(player_panel, "position", orig, 0.05)
	t.tween_property(player_panel, "modulate", Color(1, 1, 1), 0.15)

func _kill_enemy(e: Dictionary) -> void:
	_spawn_death_particles(e.panel.global_position + Vector2(100, 110))
	var t = create_tween()
	t.tween_property(e.panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): e.panel.visible = false)
	await _show_death_dialogue(e.name)  # esperar a que el jugador haga clic
	check_combat_end()

func _spawn_damage_number(pos: Vector2, amount: int, col: Color) -> void:
	var lbl = Label.new()
	
	# Detectar si es un ataque enemigo fallido (daño 0)
	if amount <= 0 and col.r > 0.7:
		lbl.text = "FALLÓ"
		lbl.modulate = Color(0.6, 0.6, 0.65)
	else:
		lbl.text = "-%d" % amount if col.r > 0.7 else "+%d" % amount
		lbl.modulate = col
		
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = pos; lbl.z_index = 20; add_child(lbl)
	var t = create_tween().set_parallel(true)
	t.tween_property(lbl, "position", pos + Vector2(randf_range(-20, 20), -55), 0.7)
	t.tween_property(lbl, "modulate:a", 0.0, 0.7)
	t.chain().tween_callback(lbl.queue_free)

func _spawn_death_particles(pos: Vector2) -> void:
	for _i in range(14):
		var p = ColorRect.new()
		p.size = Vector2(randf_range(4, 10), randf_range(4, 10))
		p.color = Color(randf_range(0.7, 1.0), randf_range(0.1, 0.4), 0.1)
		p.position = pos; p.z_index = 15; add_child(p)
		var angle = randf() * TAU
		var dist  = randf_range(40, 100)
		var t = create_tween().set_parallel(true)
		t.tween_property(p, "position", pos + Vector2(cos(angle), sin(angle)) * dist, 0.5)
		t.tween_property(p, "modulate:a", 0.0, 0.5)
		t.chain().tween_callback(p.queue_free)

func _start_enemy_idle_bobs() -> void:
	for e in enemies:
		if e.sprite_label: _idle_bob(e.sprite_label)

func _idle_bob(lbl: Label) -> void:
	var base_y = lbl.position.y
	create_tween().set_loops().tween_property(lbl, "position:y", base_y - 6, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_player_idle_bob() -> void:
	var base_y = player_sprite_label.position.y
	create_tween().set_loops().tween_property(player_sprite_label, "position:y", base_y - 4, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ── Update UI ──────────────────────────────────────────────────────────────────
func update_ui() -> void:
	lbl_player_hp.text = "HP: %d/%d  |  CORDURA: %d%%" % [player_hp, player_max_hp, GameManager.sanity]
	if player_shield > 0: lbl_player_hp.text += "  [+%d esc]" % player_shield
	hp_bar_player.value = player_hp
	
	if sanity_bar_player:
		sanity_bar_player.value = GameManager.sanity
	
	# Sincronización centralizada de audio dinámico
	_sync_dynamic_audio()
	
	lbl_energy.text = "Energia: %d/%d" % [player_energy, player_max_energy]
	
	if lbl_furia:
		lbl_furia.text = "FURIA: %d/3" % furia_points
		lbl_furia.visible = GameManager.selected_character == "guardian"
		if furia_points >= 3:
			lbl_furia.modulate = Color(1, 0.2, 0.2) # Rojo cuando esta listo
			lbl_furia.text += " [LISTO]"
		else:
			lbl_furia.modulate = Color(0.4, 0.9, 0.4)
	
	lbl_draw_pile.text    = "Mazo: %d"        % draw_pile.size()
	lbl_discard_pile.text = "Cementerio: %d"  % discard_pile.size()
	for e in enemies:
		if e.lbl_hp:     e.lbl_hp.text = "HP: %d/%d" % [e.hp, e.max_hp]
		if e.lbl_shield: e.lbl_shield.text = "Escudo: %d" % e.shield if e.shield > 0 else ""
		if e.hp_bar:     e.hp_bar.value = e.hp
	
	_check_sanity_myths()
	update_intent_labels()

func _trigger_screen_blink() -> void:
	if not blink_overlay: return
	blink_overlay.visible = true
	blink_overlay.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_property(blink_overlay, "modulate:a", 0.0, randf_range(0.15, 0.3))
	tw.tween_callback(func(): blink_overlay.visible = false)

func update_intent_labels() -> void:
	for e in enemies:
		if e.hp <= 0 or not e.lbl_intent_icon: continue
		
		# Logica de Intenciones Corruptas por Locura
		if GameManager.sanity < 20:
			var creepy = ["TE OBSERVA", "ACECHANDO", "...", "INEVITABLE"]
			e.lbl_intent_icon.text = creepy[randi() % creepy.size()]
			e.lbl_intent_icon.modulate = Color(0.8, 0.2, 0.2)
			continue
		
		if e.peaceful:
			if e.name == "El Penitente":
				var thought = _get_penitente_thought()
				var display_text = _get_deciphered_thought(thought)
				
				e.lbl_intent_icon.text = display_text + " (" + str(e.peaceful_turns) + ")"
				e.lbl_intent_icon.modulate = Color(0.9, 0.8, 0.2) # Amarillo
				
				# Temblor de texto en cordura baja
				if GameManager.sanity < 60:
					var shake = (60.0 - GameManager.sanity) * 0.15
					e.lbl_intent_icon.position.x = randf_range(-shake, shake)
				else:
					e.lbl_intent_icon.position.x = 0
			else:
				var msg = ["Rezando al Vacio...", "Lamentandose...", "Buscando perdon...", "En trance..."][GameManager.total_runs % 4]
				e.lbl_intent_icon.text = msg
				e.lbl_intent_icon.modulate = Color(0.6, 0.6, 0.8)
		else:
			var action = e.pattern[e.turn_index % e.pattern.size()]
			
			if action.type == "attack":
				var final_dmg = max(0, action.value - e.get("atk_reduction", 0))
				var val_txt = str(final_dmg)
				
				if GameManager.sanity < 40:
					val_txt = "???" if randf() < 0.5 else "▓"
				
				e.lbl_intent_icon.text = "⚔ Atacar " + val_txt
				if e.get("atk_reduction", 0) > 0:
					e.lbl_intent_icon.modulate = Color(0.4, 1.0, 0.4) # Verde si esta debilitado
				else:
					e.lbl_intent_icon.modulate = Color(1, 0.5, 0.4)
			elif action.type == "shield":
				var val_txt = str(action.value)
				if GameManager.sanity < 40:
					val_txt = "???" if randf() < 0.5 else "▓"
				e.lbl_intent_icon.text = "🛡 Escudo " + val_txt
				e.lbl_intent_icon.modulate = Color(0.4, 0.7, 1.0)
			elif action.type == "insanity":
				var val_txt = str(action.value)
				if GameManager.sanity < 40:
					val_txt = "???" if randf() < 0.5 else "▓"
				e.lbl_intent_icon.text = "👁 Corromper " + val_txt
				e.lbl_intent_icon.modulate = Color(0.7, 0.4, 0.9) # Purpura

func _trigger_boss_phase_2(e: Dictionary) -> void:
	e.in_phase_2 = true
	var heal = int(e.max_hp * 0.25)
	e.hp = min(e.hp + heal, e.max_hp)
	
	# Potenciar patron
	for action in e.pattern:
		action["value"] = int(action["value"] * 1.4) + 2
	
	if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
	show_message(e.name + ": SEGUNDA FASE", Color(1.0, 0.2, 0.2))
	
	# Flash visual
	var flash = ColorRect.new()
	flash.size = get_viewport_rect().size; flash.color = Color(0.8, 0.1, 0.1, 0.3); flash.z_index = 45
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6)
	tw.tween_callback(flash.queue_free)
	
	await get_tree().create_timer(1.5).timeout
	lbl_message.visible = false
	update_ui(); update_intent_labels()

func update_card_states() -> void:
	for card in hand_container.get_children():
		card.set_disabled(not is_player_turn or card.get_effective_cost() > player_energy)

func refresh_hand_visuals() -> void:
	for card in hand_container.get_children():
		if card.has_method("update_display"):
			card.update_display("+" in card.card_name or card.is_upgraded if "is_upgraded" in card else "+" in card.card_name)

# --- Mensajes Míticos de Cordura ---
var sanity_60_triggered: bool = false
var sanity_40_triggered: bool = false
var sanity_20_triggered: bool = false

func _check_sanity_myths() -> void:
	var s = GameManager.sanity
	if s < 60 and not sanity_60_triggered:
		sanity_60_triggered = true
		_show_mythical_text(CombatData.MYTH_60[randi() % CombatData.MYTH_60.size()], Color(0.6, 0.4, 0.8))
	elif s < 40 and not sanity_40_triggered:
		sanity_40_triggered = true
		_show_mythical_text(CombatData.MYTH_40[randi() % CombatData.MYTH_40.size()], Color(0.8, 0.3, 0.3))
	elif s < 20 and not sanity_20_triggered:
		sanity_20_triggered = true
		_show_mythical_text(CombatData.MYTH_20[randi() % CombatData.MYTH_20.size()], Color(1.0, 0.1, 0.1))

func _show_mythical_text(txt: String, col: Color) -> void:
	_trigger_screen_blink()
	if get_node_or_null("/root/AudioManager"):
		if GameManager.sanity < 30:
			AudioManager.play("Glith_distorsion_noised_sound")
		else:
			AudioManager.play("menu_glitch")
	
	var vp = get_viewport_rect().size
	var myth_lbl = Label.new()
	myth_lbl.text = txt
	myth_lbl.add_theme_font_size_override("font_size", 48)
	myth_lbl.modulate = col
	myth_lbl.modulate.a = 0.0
	myth_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	myth_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	myth_lbl.size = Vector2(vp.x, 200)
	myth_lbl.position = Vector2(0, vp.y / 2 - 100)
	myth_lbl.z_index = 150
	add_child(myth_lbl)
	
	var tw = create_tween()
	tw.tween_property(myth_lbl, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.8)
	tw.tween_property(myth_lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(myth_lbl.queue_free)
	
	# Efecto de sacudida (shake)
	var stw = create_tween().set_loops(15)
	stw.tween_property(myth_lbl, "position", myth_lbl.position + Vector2(randf_range(-10, 10), randf_range(-5, 5)), 0.05)
	stw.tween_property(myth_lbl, "position", Vector2(0, vp.y / 2 - 100), 0.05)

func _start_eye_blink_loop() -> void:
	while true:
		if not is_instance_valid(eye_node) or combat_ended: break
		var wait = randf_range(2.0, 6.0)
		if GameManager.sanity < 30: wait = randf_range(0.5, 2.5)
		await get_tree().create_timer(wait).timeout
		if not is_instance_valid(eye_node): break
		var top = eye_node.get_node("LidTop")
		var bot = eye_node.get_node("LidBot")
		var tw = create_tween().set_parallel(true)
		tw.tween_property(top, "position:y", -80, 0.12) # cerrar mas abajo
		tw.tween_property(bot, "position:y", -10, 0.12) # cerrar mas arriba
		await tw.finished
		await get_tree().create_timer(0.08).timeout
		var tw2 = create_tween().set_parallel(true)
		tw2.tween_property(top, "position:y", -180, 0.18) # abrir mas arriba
		tw2.tween_property(bot, "position:y", 90, 0.18) # abrir mas abajo

var _is_ending: bool = false

func _sync_dynamic_audio() -> void:
	if not get_node_or_null("/root/AudioManager"): return

	var lost_sanity = 100.0 - GameManager.sanity
	var is_avatar = not enemies.is_empty() and "AVATAR" in enemies[0].name.to_upper()

	# 1. Lógica para Hastur (Prioridad máxima)
	if GameManager.is_hastur_fight and not enemies.is_empty():
		var h = enemies[0]
		var hp_perc = float(h.hp) / float(h.max_hp)
		var intensity = 1.0 - hp_perc
		
		# Glitch (Hastur) - Empezar en -5dB y subir a +2dB
		var g_vol = -5.0 + (intensity * 7.0)
		var g_pitch = 1.0 + (intensity * 0.6)
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", g_vol, g_pitch)

		# Susurro (Hastur)
		var s_vol = -20.0 + (intensity * 18.0)
		var s_pitch = 1.0 - (intensity * 0.4)
		AudioManager.update_loop_params("Cry_whisper_woman_sound", s_vol, s_pitch)

	# 2. Lógica para Avatar o Cordura baja (Solo Glitch)
	elif is_avatar or GameManager.sanity < 40:
		var vol = -20.0 + (lost_sanity * 0.25)
		var pitch = 1.0 + (lost_sanity * 0.01)
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", vol, pitch)

# ── Fin de combate ─────────────────────────────────────────────────────────────

func check_combat_end() -> void:
	if combat_ended or _is_ending: return
	var all_dead = true
	for e in enemies:
		if e.hp > 0: all_dead = false
	if not all_dead: return

	_is_ending = true
	combat_ended = true
	
	# Detener distorsiones
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Glith_distorsion_noised_sound")
		AudioManager.stop_loop("Cry_whisper_woman_sound")
	
	# Recuperación de Cordura al Ganar
	GameManager.sanity = min(100, GameManager.sanity + 10)
	
	GameManager.player_hp = player_hp
	
	if GameManager.is_elite_fight and GameManager.has_relic("caliz_olvido"):
		GameManager.player_max_energy += 1
		flash_small("Caliz: +1 Energia Max!")

	GameManager.combat_count += 1
	GameManager.lore_progress += 1
	
	if get_node_or_null("/root/AudioManager"): AudioManager.play("victory")
	
	var victory_phrases = CombatData.VICTORY_PHRASES
	show_message(victory_phrases[randi() % victory_phrases.size()], Color(0.85, 0.7, 0.2))
	await get_tree().create_timer(1.2).timeout

	if GameManager.is_hastur_fight:
		# Final secreto — Hastur derrotado: victoria real
		GameManager.player_won = true
		_show_victory_cinematic(true)
		get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
	elif GameManager.is_final_boss:
		if GameManager.current_world == 0:
			# REY SIN CORONA caído → Mundo 2 (con reliquia, aún hay juego)
			_show_relic_reward("__world2__")
		else:
			# REY AMARILLO caído
			if GameManager.has_all_secret_items():
				# Los 3 fragmentos reunidos → Carcosa se abre → Hastur
				await _show_carcosa_transition()
				GameManager.is_final_boss = false
				GameManager.is_hastur_fight = true
				get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")
			else:
				# Victoria normal sin secreto
				GameManager.player_won = true
				await _show_victory_cinematic(false)
				get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
	elif GameManager.is_boss_fight:
		# EL CARCELERO → reliquia → mapa
		_show_relic_reward("res://scenes/ui/Map.tscn")
	else:
		_show_loot_screen()

func _show_loot_screen() -> void:
	var vp = get_viewport_rect().size
	# Panel de despojos con estetica Carcosa
	var loot_panel = _make_panel(Vector2(vp.x/2 - 300, 120), Vector2(600, 380), Color(0.04, 0.04, 0.06, 0.96), Color(0.85, 0.75, 0.2))
	add_child(loot_panel)
	loot_panel.z_index = 100

	var title = Label.new()
	title.text = "RECOLECTAR RESTOS"
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(0.7, 0.65, 0.4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 25); title.size = Vector2(600, 40)
	loot_panel.add_child(title)

	var reward_vbox = VBoxContainer.new()
	reward_vbox.position = Vector2(60, 90); reward_vbox.size = Vector2(480, 220)
	reward_vbox.add_theme_constant_override("separation", 15)
	loot_panel.add_child(reward_vbox)

	# Recompensas
	var frag_count = randi_range(12, 22)
	_add_loot_button(reward_vbox, "◈ Tomar " + str(frag_count) + " Fragmentos de Tablero", func():
		GameManager.add_coins(frag_count)
	)

	_add_loot_button(reward_vbox, "✦ Recolectar Ecos de los Caidos (Carta)", func():
		get_tree().change_scene_to_file("res://scenes/ui/CardDraft.tscn")
	)

	if randf() < 0.35:
		_add_loot_button(reward_vbox, "☤ Beber Esencia de Olvido (+15 SAN)", func():
			GameManager.sanity = min(100, GameManager.sanity + 15)
		)

	var cont_btn = Button.new()
	cont_btn.text = "CONTINUAR EL VIAJE"
	cont_btn.position = Vector2(200, 315); cont_btn.size = Vector2(200, 45)
	cont_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/Map.tscn"))
	loot_panel.add_child(cont_btn)

func _add_loot_button(container: Control, txt: String, action: Callable) -> void:
	var btn = Button.new()
	btn.text = txt; btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func():
		action.call()
		btn.disabled = true; btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
		# Llamada directa al Autoload
		AudioManager.play("button_click")
	)
	container.add_child(btn)

# ── Transición a Carcosa (secreto) ─────────────────────────────────────────────
func _show_carcosa_transition() -> void:
	var vp = get_viewport_rect().size

	# Overlay que toma la pantalla
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.z_index = 55
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var t = create_tween()
	t.tween_property(overlay, "color:a", 1.0, 1.2)
	await t.finished

	# Lineas — sugieren sin revelar
	var lines = [
		["...", Color(0.5, 0.5, 0.5), 20, false],
		["Los fragmentos vibran.", Color(0.75, 0.68, 0.3), 22, false],
		["Algo al otro lado\nreconoce el signo.", Color(0.7, 0.6, 0.25), 22, false],
		["No es un lugar.\nEs una promesa rota.", Color(0.65, 0.55, 0.2), 20, false],
		["C̴̡A̵̢R̴C̷O̴S̸A̷", Color(0.82, 0.72, 0.05), 42, true],
		["Él recuerda tu nombre.", Color(0.45, 0.15, 0.65), 22, false],
	]

	for pair in lines:
		var full_text: String = pair[0]
		var col: Color = pair[1]
		var fsize: int = pair[2]
		var do_shake: bool = pair[3]

		var lbl = Label.new()
		lbl.text = ""
		lbl.modulate = col
		lbl.add_theme_font_size_override("font_size", fsize)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, vp.y * 0.38)
		lbl.size = Vector2(vp.x, 110)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 56
		add_child(lbl)

		var char_delay = 0.09 if do_shake else 0.05
		for i in range(full_text.length()):
			lbl.text = full_text.substr(0, i + 1)
			await get_tree().create_timer(char_delay).timeout

		if do_shake:
			# La ciudad sacude la realidad
			var base_pos = lbl.position
			for _s in range(35):
				lbl.position = base_pos + Vector2(randf_range(-7, 7), randf_range(-4, 4))
				overlay.color = Color(
					randf_range(0.0, 0.08),
					randf_range(0.0, 0.04),
					randf_range(0.0, 0.12),
					1.0
				)
				await get_tree().create_timer(0.04).timeout
			lbl.position = base_pos
			overlay.color = Color(0, 0, 0, 1.0)

		await get_tree().create_timer(1.8).timeout

		var t3 = create_tween()
		t3.tween_property(lbl, "modulate:a", 0.0, 0.5)
		await t3.finished
		lbl.queue_free()

	# Destello purpura antes del combate
	var flash = ColorRect.new()
	flash.color = Color(0.35, 0.05, 0.55, 0.0)
	flash.position = Vector2.ZERO
	flash.size = vp
	flash.z_index = 57
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tf = create_tween()
	tf.tween_property(flash, "color:a", 0.9, 0.3)
	await tf.finished
	# El overlay se queda negro para la transición de escena

# ── Cinemática de victoria final ───────────────────────────────────────────────
func _show_victory_cinematic(is_hastur: bool) -> void:
	var vp = get_viewport_rect().size
	var runs = str(GameManager.total_runs + 1)

	# Lines: [text, color, font_size, shake]
	var lines: Array
	if is_hastur:
		lines = [
			["H̷A̵S̷T̷U̵R̷  H̷A̵  C̷A̵I̷D̵O̷", Color(0.65, 0.1, 0.95), 38, true],
			["Pero el tablero sigue moviendose.", Color(0.6, 0.5, 0.85), 24, false],
			["¿Que clase de pieza puede matar al jugador?\nUna que ya no cree en el juego.", Color(0.55, 0.45, 0.78), 22, false],
			["El silencio pesa mas que antes.\nEres libre. Quizas.", Color(0.45, 0.38, 0.65), 20, false],
		]
	else:
		lines = [
			["EL REY AMARILLO HA CAIDO", Color(0.98, 0.88, 0.05), 38, true],
			["El tablero se congela.\nNinguna pieza se mueve.", Color(0.82, 0.74, 0.42), 24, false],
			["Llevas " + runs + " intentos llegando aqui.\nEsta vez, recuerdas cada uno.", Color(0.72, 0.65, 0.48), 22, false],
			["¿Ganar era la trampa?\n¿O era el tablero entero?", Color(0.58, 0.52, 0.42), 20, false],
		]

	# Flash de impacto inicial
	var flash = ColorRect.new()
	flash.color = Color(0.9, 0.8, 0.05, 0.9) if not is_hastur else Color(0.5, 0.05, 0.9, 0.9)
	flash.position = Vector2.ZERO
	flash.size = vp
	flash.z_index = 55
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tf = create_tween()
	tf.tween_property(flash, "color:a", 0.0, 0.55)
	await tf.finished
	flash.queue_free()

	# Overlay oscuro
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.z_index = 50
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var t = create_tween()
	t.tween_property(overlay, "color:a", 0.95, 0.65)
	await t.finished

	for pair in lines:
		var full_text: String = pair[0]
		var col: Color = pair[1]
		var fsize: int = pair[2]
		var do_shake: bool = pair[3]

		var lbl = Label.new()
		lbl.text = ""
		lbl.modulate = col
		lbl.add_theme_font_size_override("font_size", fsize)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, vp.y * 0.37)
		lbl.size = Vector2(vp.x, 110)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 52
		add_child(lbl)

		# Typewriter letra por letra
		var char_delay = 0.07 if do_shake else 0.04
		for i in range(full_text.length()):
			lbl.text = full_text.substr(0, i + 1)
			await get_tree().create_timer(char_delay).timeout

		# Sacudida en lineas dramaticas
		if do_shake:
			var base_pos = lbl.position
			for _s in range(28):
				lbl.position = base_pos + Vector2(randf_range(-5, 5), randf_range(-3, 3))
				await get_tree().create_timer(0.04).timeout
			lbl.position = base_pos

		await get_tree().create_timer(2.2).timeout

		var t3 = create_tween()
		t3.tween_property(lbl, "modulate:a", 0.0, 0.55)
		await t3.finished
		lbl.queue_free()

	# Boton continuar
	var cont_btn = Button.new()
	cont_btn.text = "Continuar"
	cont_btn.add_theme_font_size_override("font_size", 16)
	cont_btn.modulate = Color(1, 1, 1, 0.0)
	cont_btn.position = Vector2(vp.x / 2.0 - 100, vp.y * 0.65)
	cont_btn.size = Vector2(200, 44)
	cont_btn.z_index = 52
	add_child(cont_btn)

	var t4 = create_tween()
	t4.tween_property(cont_btn, "modulate:a", 1.0, 0.5)
	await t4.finished

	await cont_btn.pressed

	cont_btn.queue_free()
	var t5 = create_tween()
	t5.tween_property(overlay, "color:a", 0.0, 0.5)
	await t5.finished
	overlay.queue_free()

# ── Recompensa de reliquia (boss / jefe final) ─────────────────────────────────
func _show_relic_reward(next_scene: String = "res://scenes/ui/Map.tscn") -> void:
	var vp = get_viewport_rect().size

	var available = []
	for rid in GameManager.RELIC_DATA.keys():
		if not GameManager.has_relic(rid):
			available.append(rid)
	available.shuffle()
	var choices = available.slice(0, min(3, available.size()))
	if choices.is_empty(): return

	# Fondo oscuro bloqueante
	var dim = ColorRect.new(); dim.color = Color(0, 0, 0, 0.88)
	dim.position = Vector2.ZERO; dim.size = vp
	dim.z_index = 25; dim.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(dim)

	var title = Label.new(); title.text = "RELIQUIA DE RECOMPENSA"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.9, 0.75, 0.1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 44); title.z_index = 26
	add_child(title)

	var picked = false  # evita doble clic
	var panel_w = 260; var panel_h = 260; var gap = 24
	var total_w = choices.size() * panel_w + (choices.size() - 1) * gap
	var start_x = (vp.x - total_w) / 2.0
	var relic_icon_scene = load("res://scenes/ui/RelicIcon.tscn")
	var panels_root = Node2D.new(); panels_root.z_index = 26; add_child(panels_root)

	for i in range(choices.size()):
		var rid = choices[i]
		var rdata = GameManager.RELIC_DATA[rid]
		var px = start_x + i * (panel_w + gap)
		var rpanel = _make_panel(Vector2(px, 100), Vector2(panel_w, panel_h),
			Color(0.08, 0.07, 0.04), Color(0.7, 0.55, 0.1))
		panels_root.add_child(rpanel)

		# Icono de reliquia centrado en la parte superior
		if relic_icon_scene:
			var icon = relic_icon_scene.instantiate()
			icon.position = Vector2(panel_w / 2.0 - 22, 10)
			rpanel.add_child(icon)
			icon.setup(rid)

		var rname = Label.new(); rname.text = rdata["name"]
		rname.add_theme_font_size_override("font_size", 15)
		rname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rname.modulate = Color(0.95, 0.85, 0.3)
		rname.position = Vector2(8, 62); rname.size = Vector2(panel_w - 16, 36)
		rname.autowrap_mode = TextServer.AUTOWRAP_WORD; rpanel.add_child(rname)

		var rdesc = Label.new(); rdesc.text = rdata["desc"]
		rdesc.add_theme_font_size_override("font_size", 12)
		rdesc.modulate = Color(0.75, 0.75, 0.8)
		rdesc.position = Vector2(8, 104); rdesc.size = Vector2(panel_w - 16, 100)
		rdesc.autowrap_mode = TextServer.AUTOWRAP_WORD; rpanel.add_child(rdesc)

		var rbtn = Button.new(); rbtn.text = "Tomar"
		rbtn.position = Vector2(80, 216); rbtn.size = Vector2(100, 34)
		rbtn.tooltip_text = rdata["name"] + ": " + rdata["desc"]
		if "maldicion" in rdata["desc"].to_lower() or "pierdes" in rdata["desc"].to_lower() or "cuesta" in rdata["desc"].to_lower():
			rbtn.tooltip_text += "\n[!] ADVERTENCIA: Esta reliquia conlleva una maldición o coste."
		rpanel.add_child(rbtn)

		var relic_id = rid
		rbtn.pressed.connect(func():
			if picked: return
			picked = true
			GameManager.add_relic(relic_id)
			dim.queue_free(); title.queue_free(); panels_root.queue_free()
			if next_scene == "__world2__":
				GameManager.current_world = 1
				GameManager.map_graph = []
				GameManager.current_map_floor = 0
				GameManager.current_map_col = -1
				get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
			else:
				get_tree().change_scene_to_file(next_scene)
		)

# ── Recompensa del Penitente ───────────────────────────────────────────────────
func _penitente_reward() -> void:
	combat_ended = true
	GameManager.player_hp = player_hp
	GameManager.combat_count += 1
	GameManager.lore_progress += 1

	var vp = get_viewport_rect().size
	show_message("El Penitente asiente y desaparece.", Color(0.5, 1.0, 0.5))
	if get_node_or_null("/root/AudioManager"): AudioManager.play("relic_get")
	await get_tree().create_timer(1.5).timeout
	lbl_message.visible = false

	# Recompensa: curar + un fragmento de lore
	var heal_amount = int(player_max_hp * 0.25)
	player_hp = min(player_hp + heal_amount, player_max_hp)
	GameManager.player_hp = player_hp
	# Logica Reloj
	cards_played_this_turn += 1
	if GameManager.has_relic("reloj_negro") and cards_played_this_turn % 3 == 0:
		player_energy = min(player_energy + 1, player_max_energy)
		flash_small("Reloj: +1 Energia!")

	update_ui()
	show_message("Te curas %d HP y recibes una vision." % heal_amount, Color(0.4, 1.0, 0.6))
	await get_tree().create_timer(2.0).timeout

	# Mostrar fragmento de lore del Penitente
	var texts = [
		"'Llevas mas tiempo en el tablero de lo que crees.\nCada run es un turno. El Rey lleva siglos jugando.'",
		"'El idioma que no entiendes... es el tuyo propio.\nDe hace muchas vidas.'",
		"'Hay tres fragmentos dispersos. Si los juntas todos...\ntal vez puedas ver al jugador detras del tablero.'",
	]
	var lore_text = texts[GameManager.lore_progress % texts.size()]
	await _show_lore_panel(lore_text)
	get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")

func _show_lore_panel(text: String) -> void:
	var vp = get_viewport_rect().size

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.position = Vector2.ZERO; overlay.size = vp
	overlay.z_index = 20; overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var ot = create_tween()
	ot.tween_property(overlay, "color:a", 0.84, 0.4)
	await ot.finished

	var lbl = Label.new()
	lbl.text = ""
	lbl.modulate = Color(0.62, 0.96, 0.62)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.position = Vector2(vp.x * 0.12, vp.y * 0.34)
	lbl.size = Vector2(vp.x * 0.76, 160)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 21
	add_child(lbl)

	await _typewrite(lbl, text, 0.032)

	var btn = Button.new()
	btn.text = "Continuar"
	btn.modulate = Color(1, 1, 1, 0.0)
	btn.position = Vector2(vp.x / 2.0 - 60, vp.y * 0.34 + 175)
	btn.size = Vector2(120, 32)
	btn.z_index = 22
	add_child(btn)
	var bt = create_tween()
	bt.tween_property(btn, "modulate:a", 1.0, 0.4)
	await bt.finished

	await btn.pressed

	btn.queue_free(); lbl.queue_free()
	var ot2 = create_tween()
	ot2.tween_property(overlay, "color:a", 0.0, 0.3)
	await ot2.finished
	overlay.queue_free()

# ── Turno enemigo ──────────────────────────────────────────────────────────────
func _on_end_turn_button_pressed() -> void:
	is_player_turn = false; end_turn_btn.disabled = true
	first_card_this_turn = true
	update_card_states()
	await get_tree().create_timer(0.4).timeout

	for e in enemies:
		if e.hp <= 0: continue
		
		# Probabilidad de soltar un diálogo de lore (bark) al iniciar turno
		if "AVATAR" in e.name.to_upper() and randf() < 0.4:
			_show_avatar_bark()

		# RESUMEN: Escudo enemigo se resetea al inicio de su turno
		e.shield = 0
		update_ui()

		# El Penitente en modo pacífico: contar turnos
		if e.peaceful:
			e.peaceful_turns -= 1
			
			if e.penitente_mode == "silence":
				# Efecto Silencio: Glitch y oscuridad
				_trigger_screen_blink()
				if is_instance_valid(eye_node):
					var tw_eye = create_tween()
					tw_eye.tween_property(eye_node, "modulate", Color(0.2, 0.2, 0.3, 0.9), 0.2)
					tw_eye.tween_property(eye_node, "modulate", Color(1, 1, 1, 1), 0.2)
				if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
			else:
				# Efecto Misericordia: Luz y particulas
				var tw_glow = create_tween()
				tw_glow.tween_property(e.panel, "modulate", Color(1.5, 1.5, 2.0), 0.2)
				tw_glow.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.4)
				_spawn_death_particles(e.panel.global_position + Vector2(100, 100)) # Reutilizo particulas con otro color si pudiera, pero esto ya es visual

			if e.peaceful_turns <= 0:
				await _penitente_reward()
				return
			update_intent_labels()
			continue

		# Enemigo agresivo: ejecutar acción
		var action = e.pattern[e.turn_index % e.pattern.size()]
		e.turn_index += 1

		if action.type == "attack":
			var banter = _get_enemy_banter(e.name)
			if not banter.is_empty():
				_show_enemy_banter(e.panel, banter, _get_banter_color(e.name, banter))
			
			# Ejecutar animacion de ataque segun el enemigo
			await _animate_enemy_attack_unique(e)
			
			var dmg = max(0, action.value - e.get("atk_reduction", 0))
			
			var absorbed = min(player_shield, dmg)
			if absorbed > 0:
				player_shield -= absorbed; dmg -= absorbed
				if get_node_or_null("/root/AudioManager"): AudioManager.play("shield_block")
				_spawn_damage_number(player_panel.global_position + Vector2(200, 30), absorbed, Color(0.4, 0.7, 1.0))
			
			# Mostrar siempre el daño o el fallo si es un ataque
			if dmg > 0:
				player_hp -= dmg
				_animate_player_hit()
				_spawn_damage_number(player_panel.global_position + Vector2(200, 30), dmg, Color(1, 0.3, 0.3))
				if get_node_or_null("/root/AudioManager"): AudioManager.play("player_hit")
				
				# Pasiva Guardian: Furia (1 por cada 5 de daño)
				if GameManager.selected_character == "guardian":
					var gained = int(dmg / 5.0)
					if gained > 0:
						furia_points = min(3, furia_points + gained)
						flash_small("¡RESILIENCIA! Furia acumulada: " + str(furia_points) + "/3")
						update_ui()
			else:
				# Es un FALLO (daño 0)
				_spawn_damage_number(player_panel.global_position + Vector2(200, 30), 0, Color(1, 0.3, 0.3))
		elif action.type == "shield":
			e.shield += action.value
		elif action.type == "insanity":
			GameManager.sanity = max(0, GameManager.sanity - action.value)
			_spawn_damage_number(player_panel.global_position + Vector2(200, 30), action.value, Color(0.7, 0.3, 1.0))
			flash_small(e.name + ": Ataca tu cordura! (-" + str(action.value) + ")")
			update_ui()
		
		# --- NUEVAS MECÁNICAS DE HASTUR ---
		elif action.type == "possession":
			var cards = hand_container.get_children()
			if not cards.is_empty():
				var target_card = cards[randi() % cards.size()]
				flash_small("¡HASTUR TOMA EL CONTROL!")
				flash_small("Usas " + target_card.card_name + " contra ti mismo.")
				
				# Aplicar daño al jugador basado en el ataque de la carta
				var self_dmg = target_card.attack
				if "SIERVO" in target_card.card_name: self_dmg += GameManager.siervo_atk_bonus_perm
				
				player_hp -= self_dmg
				_spawn_damage_number(player_panel.global_position + Vector2(200, 30), self_dmg, Color(1, 0.2, 0.2))
				_animate_player_hit()
				
				# Animación de la carta volando hacia el jugador
				await target_card.play_attack_animation(player_panel.global_position + Vector2(200, 30))
				target_card.queue_free()
				reorganize_hand()
				
				flash_small("Tu turno ha sido arrebatado.")
				# Forzar fin de turno (pero como ya estamos en turno enemigo, esto solo salta las acciones restantes si las hubiera)
				break 
		
		elif action.type == "ultimate_charge":
			flash_small("¡EL CIELO SE RASGA! Hastur prepara su juicio...")
			_trigger_screen_blink()
			if get_node_or_null("/root/AudioManager"): AudioManager.play("agony_shriek")
			
		elif action.type == "ultimate_attack":
			flash_small("¡EL JUICIO DE CARCOSA!")
			player_hp -= action.value
			_spawn_damage_number(player_panel.global_position + Vector2(200, 30), action.value, Color(1, 0, 0))
			_trigger_screen_blink()
			_animate_player_hit()

		await get_tree().create_timer(0.35).timeout

	# ── FIN DEL TURNO ENEMIGO ──
	# Drenaje de cordura por turno si el Avatar o Hastur están presentes
	if not enemies.is_empty():
		var e0 = enemies[0]
		if "HASTUR" in e0.name.to_upper():
			GameManager.sanity = max(0, GameManager.sanity - 10) # Hastur drena más
			_spawn_damage_number(player_panel.global_position + Vector2(200, 30), 10, Color(0.7, 0.3, 1.0))
			flash_small("LA CANCIÓN DE CARCOSA TE PERSIGUE (-10)")
			update_ui()
		elif "AVATAR" in e0.name.to_upper():
			GameManager.sanity = max(0, GameManager.sanity - 5)
			_spawn_damage_number(player_panel.global_position + Vector2(200, 30), 5, Color(0.7, 0.3, 1.0))
			flash_small("LA PRESENCIA DEL AVATAR TE CORROMPE (-5)")
			
			# --- REFLEJO DE LA LOCURA ---
			if GameManager.sanity < 20:
				var cards_in_hand = hand_container.get_children()
				if not cards_in_hand.is_empty():
					var target_card = cards_in_hand[randi() % cards_in_hand.size()]
					flash_small("¡REFLEJO DE LA LOCURA! Una pieza ha sido corrompida.")
					target_card.setup({"name": "Maldición de Ceniza", "attack": 0, "defense": 0, "cost": 1, "curse": true})
					target_card.modulate = Color(0.4, 0.1, 0.5) # Color corrupto
					if get_node_or_null("/root/AudioManager"):
						AudioManager.play("Cry_whisper_woman_sound")
			
			update_ui()

	# Limpiar debuffs y escudos de TODOS los enemigos antes de que empiece el turno del jugador
	for e_final in enemies:
		e_final["atk_reduction"] = 0
		e_final.shield = 0 

	player_energy = player_max_energy; player_shield = 0

	# Sinergia Reliquia: Velo de la Dama (Negar la muerte una vez)
	if player_hp <= 0 and GameManager.has_relic("velo_dama") and not velo_used:
		player_hp = 1
		velo_used = true
		flash_small("¡VELO DE LA DAMA! La muerte ha sido negada.")
		_trigger_screen_blink()
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")

	if player_hp <= 0:
		GameManager.player_hp = 0
		is_eye_breaking_4th_wall = true # El ojo te observa caer
		update_ui()
		if get_node_or_null("/root/AudioManager"): AudioManager.play("defeat")
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
		return

	GameManager.player_hp = player_hp
	cards_played_this_turn = 0
	update_ui(); update_intent_labels()
	await draw_hand()
	is_player_turn = true; end_turn_btn.disabled = false
	update_card_states()

# ── Dev ────────────────────────────────────────────────────────────────────────
func _build_dev_panel(vp: Vector2) -> Panel:
	var p = Panel.new()
	p.position = Vector2(vp.x - 230, vp.y - 400)
	p.size = Vector2(225, 380)
	p.z_index = 60
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	st.set_corner_radius_all(6)
	st.border_width_left = 1; st.border_width_right = 1
	st.border_width_top = 1; st.border_width_bottom = 1
	st.border_color = Color(0.4, 0.4, 0.1)
	p.add_theme_stylebox_override("panel", st)

	var title_lbl = Label.new(); title_lbl.text = "DEV PANEL"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.modulate = Color(0.7, 0.7, 0.3)
	title_lbl.position = Vector2(8, 6); title_lbl.size = Vector2(209, 20)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(title_lbl)

	# Contenedor de Scroll
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 30); scroll.size = Vector2(205, 340)
	p.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(vbox)

	var btns = [
		["Ganar combate", func(): _dev_force_win()],
		["FORZAR AVATAR", func():
			GameManager.dev_force_avatar = true
			get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")],
		["FORZAR PENITENTE", func():
			GameManager.dev_force_penitente = true
			get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")],
		["+ Fragmentos x3", func():
			GameManager.add_secret_item("simbolo_amarillo")
			GameManager.add_secret_item("cancion_amarilla")
			GameManager.add_secret_item("carta_carcosa")
			show_message("Fragmentos: 3/3 — Hastur activado", Color(0.7, 0.3, 0.9))],
		["Final: REY SIN CORONA", func():
			GameManager.is_hastur_fight = false
			GameManager.is_final_boss = true
			GameManager.current_world = 0
			_dev_force_win()],
		["Final: REY AMARILLO", func():
			GameManager.is_hastur_fight = false
			GameManager.is_final_boss = true
			GameManager.current_world = 1
			_dev_force_win()],
		["Final: HASTUR", func():
			GameManager.add_secret_item("simbolo_amarillo")
			GameManager.add_secret_item("cancion_amarilla")
			GameManager.add_secret_item("carta_carcosa")
			GameManager.is_hastur_fight = true
			_dev_force_win()],
		["BOSS: MUNDO I", func():
			GameManager.is_boss_fight = true
			GameManager.current_world = 0
			get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")],
		["ACTIVA FASE 2", func():
			if not enemies.is_empty(): _trigger_boss_phase_2(enemies[0])],
		["CURAR TODO", func():
			player_hp = player_max_hp; update_ui()],
		["DAÑO ENEMIGOS -40", func():
			for e in enemies:
				if e.hp > 0:
					e.hp = max(0, e.hp - 40)
					_spawn_damage_number(e.panel.global_position + Vector2(100, 60), 40, Color(1, 1, 1))
					if e.hp <= 0: await _kill_enemy(e)
			update_ui()],
		["SAN: 100 (Claro)", func(): GameManager.sanity = 100; update_ui()],
		["SAN: 55 (Viñeta)", func(): GameManager.sanity = 55; update_ui()],
		["SAN: 35 (Parpadeo)", func(): GameManager.sanity = 35; update_ui()],
		["SAN: 15 (Ceguera)", func(): GameManager.sanity = 15; update_ui()],
		["SAN: 0 (Muerte)", func(): GameManager.sanity = 0; check_combat_end()],
		["HOGUERA (Rest)", func(): get_tree().change_scene_to_file("res://scenes/ui/Rest.tscn")],
	]

	for i in range(btns.size()):
		var b = Button.new()
		b.text = btns[i][0]
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(185, 32)
		b.pressed.connect(btns[i][1])
		vbox.add_child(b)

	return p

func _dev_force_win() -> void:
	for e in enemies:
		if e.hp > 0:
			e.hp = 0
			await _kill_enemy(e)

# ── Diálogos y banter ─────────────────────────────────────────────────────────
const ENEMY_COMBAT_BANTER = {
	"Siervo Rebelde":   ["...muere...", "no... escapes...", "el tablero... te reclama..."],
	"Peon Maldito":     ["maldito seas...", "nadie sale...", "somos todos lo mismo..."],
	"Alfil Caido":      ["hereje...", "tu fe es falsa...", "el Rey te vera caer..."],
	"Espectro":         ["sientes... el frio...", "ya... eres... uno de nosotros..."],
	"Torre Rota":       ["resistire... siglos...", "soy... lo que queda..."],
	"Caballero Roto":   ["falle... una vez... no... dos..."],
	"Inquisidor Ciego": ["la verdad... duele...", "no... puedes... saberlo..."],
	"EL CARCELERO":     ["NADIE ESCAPA DEL TABLERO.", "ERES UNA PIEZA. NADA MAS.", "EL REY... TE ESPERA."],
	"EL REY SIN CORONA":["campeon... mio...", "el tablero... te reclama...", "esto es... necesario..."],
	"EL REY AMARILLO":  ["JUEGA BIEN.", "SIEMPRE VUELVES.", "SOY EL TABLERO. SOY EL JUEGO."],
	"El Penitente": [
		"Escucha. Solo escucha un momento.",
		"No eres el heroe. Nunca lo fuiste.",
		"El tablero nos mueve a los dos.",
		"Ya estuviste aqui. No lo recuerdas, pero yo si.",
	],
}

func _get_enemy_banter(enemy_name: String) -> String:
	var stage = LoreData.get_lore_stage()
	var has_translator = GameManager.has_relic("lengua_tablero")

	# Enemigos que hablan en idioma garbled (sin traductor en etapas tempranas)
	if enemy_name in LoreData.GARBLED and not has_translator and stage <= 1:
		if randf() < 0.55:
			return LoreData.GARBLED[enemy_name]

	var threshold = 0.7 if enemy_name == "El Penitente" else 0.35
	if randf() > threshold: return ""
	var pool = ENEMY_COMBAT_BANTER.get(enemy_name, [])
	if pool.is_empty(): return ""
	return pool[randi() % pool.size()]

func _get_banter_color(enemy_name: String, text: String) -> Color:
	if LoreData.is_garbled(text):
		return Color(0.3, 0.9, 0.9)  # cian para texto garbled
	if enemy_name == "El Penitente":
		return Color(0.5, 1.0, 0.5)
	if enemy_name in ["EL CARCELERO", "EL REY AMARILLO", "EL REY SIN CORONA"]:
		return Color(0.95, 0.7, 0.1)
	return Color(0.9, 0.8, 0.5)

func _show_enemy_banter(enemy_panel: Panel, text: String, col: Color = Color(0.9, 0.8, 0.5)) -> void:
	if text.is_empty(): return
	var lbl = Label.new()
	lbl.text = "\"%s\"" % text
	lbl.modulate = col; lbl.modulate.a = 0.0
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size = Vector2(220, 65)
	lbl.position = enemy_panel.global_position + Vector2(-10, -70)
	lbl.z_index = 12; add_child(lbl)
	var t = create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.8)
	t.tween_property(lbl, "modulate:a", 0.0, 0.5)
	t.tween_callback(lbl.queue_free)

func _typewrite(lbl: Label, text: String, base_delay: float = 0.04) -> void:
	lbl.text = ""
	for i in range(text.length()):
		lbl.text = text.substr(0, i + 1)
		var c = text[i]
		var wait = base_delay
		if c in [".", "!", "?"]:  wait = base_delay * 7.0
		elif c in [",", ";"]:     wait = base_delay * 3.0
		elif c == "\n":           wait = base_delay * 5.0
		await get_tree().create_timer(wait).timeout

func _show_death_dialogue(enemy_name: String) -> void:
	var text = LoreData.get_death_dialogue(enemy_name)
	if text.is_empty(): return

	var vp = get_viewport_rect().size
	var is_boss = enemy_name.begins_with("EL ") or enemy_name == "El Penitente"
	var is_cipher = LoreData.is_garbled(text)

	var text_color: Color
	if is_boss:           text_color = Color(0.92, 0.80, 0.28)
	elif is_cipher:       text_color = Color(0.35, 0.85, 0.85)
	elif enemy_name == "El Penitente": text_color = Color(0.55, 0.95, 0.55)
	else:                 text_color = Color(0.82, 0.78, 0.70)

	# Overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.position = Vector2.ZERO; overlay.size = vp
	overlay.z_index = 15; overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var ot = create_tween()
	ot.tween_property(overlay, "color:a", 0.78, 0.35)
	await ot.finished

	# Nombre del enemigo como pie pequeño
	var caption = Label.new()
	caption.text = enemy_name if not is_cipher else "???"
	caption.add_theme_font_size_override("font_size", 11)
	caption.modulate = Color(0.45, 0.45, 0.45)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, vp.y * 0.36 - 22)
	caption.size = Vector2(vp.x, 20)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 16
	add_child(caption)

	# Texto
	var lbl = Label.new()
	lbl.text = ""
	lbl.modulate = text_color
	lbl.add_theme_font_size_override("font_size", 17 if is_boss else 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.position = Vector2(vp.x * 0.15, vp.y * 0.36)
	lbl.size = Vector2(vp.x * 0.70, 130)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 16
	add_child(lbl)

	if is_cipher:
		# Texto cifrado: aparece de golpe con parpadeo
		lbl.text = text
		for _f in range(6):
			lbl.modulate.a = randf_range(0.3, 1.0)
			await get_tree().create_timer(0.07).timeout
		lbl.modulate.a = 1.0
	else:
		await _typewrite(lbl, text, 0.055 if is_boss else 0.038)

	# Boton aparece después del texto
	var btn = Button.new()
	btn.text = "Continuar"
	btn.modulate = Color(1, 1, 1, 0.0)
	btn.position = Vector2(vp.x / 2.0 - 60, vp.y * 0.36 + 148)
	btn.size = Vector2(120, 32)
	btn.z_index = 17
	add_child(btn)
	var bt = create_tween()
	bt.tween_property(btn, "modulate:a", 1.0, 0.4)
	await bt.finished

	await btn.pressed

	btn.queue_free(); lbl.queue_free(); caption.queue_free()
	var ot2 = create_tween()
	ot2.tween_property(overlay, "color:a", 0.0, 0.3)
	await ot2.finished
	overlay.queue_free()

# ── Reliquias ──────────────────────────────────────────────────────────────────
func _show_deck_viewer() -> void:
	var vp = get_viewport_rect().size
	var overlay = ColorRect.new()
	overlay.size = vp; overlay.color = Color(0, 0, 0, 0.9); overlay.z_index = 200
	add_child(overlay)
	
	var title = Label.new()
	title.text = "TU COLECCION DE PIEZAS"; title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40); title.size = Vector2(vp.x, 50); overlay.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(100, 120); scroll.size = Vector2(vp.x - 200, vp.y - 250)
	overlay.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)
	
	var card_scene = preload("res://scenes/combat/Card.tscn")
	for c_data in GameManager.player_deck:
		var card = card_scene.instantiate()
		grid.add_child(card)
		card.setup(c_data)
		# En el visor las cartas no se juegan
		card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var close_btn = Button.new()
	close_btn.text = "CERRAR"; close_btn.position = Vector2(vp.x/2 - 100, vp.y - 100); close_btn.size = Vector2(200, 50)
	overlay.add_child(close_btn)
	close_btn.pressed.connect(overlay.queue_free)
	if get_node_or_null("/root/AudioManager"): AudioManager.play("button_click")

func _show_enemy_intent_tooltip(idx: int) -> void:
	if idx >= enemies.size() or enemies[idx].hp <= 0: return
	var e = enemies[idx]
	var txt = ""
	
	if e.peaceful:
		txt = "ESTADO: PACIFICO\nNo atacara mientras no sea provocado.\n\n\"" + _get_enemy_banter(e.name) + "\""
	else:
		var action = e.pattern[e.turn_index % e.pattern.size()]
		if action.type == "attack":
			var reduction = e.get("atk_reduction", 0)
			var final_dmg = max(0, action.value - reduction)
			txt = "INTENCION: ATACAR\nInfligira " + str(final_dmg) + " de daño."
			if reduction > 0:
				txt += "\n(Debilitado: -" + str(reduction) + " ATK)"
			txt += "\n\n[El escudo puede absorber este golpe]"
		elif action.type == "shield":
			txt = "INTENCION: ESCUDO\nGanara " + str(action.value) + " de proteccion.\n\n[El escudo enemigo se resetea al inicio de su turno]"
		elif action.type == "insanity":
			txt = "INTENCION: CORROMPER\nDrenara " + str(action.value) + " de tu Cordura.\n\n[La cordura baja distorsiona la realidad]"
		elif action.type == "possession":
			txt = "INTENCION: POSESIÓN\nHastur tomara una de tus piezas y la usara contra ti.\n\n[Pierdes la carta y recibes su daño]"
		elif action.type == "ultimate_charge":
			txt = "INTENCION: PREPARACIÓN\nHastur acumula energía del vacío para un golpe devastador el próximo turno."
		elif action.type == "ultimate_attack":
			txt = "INTENCION: JUICIO DE CARCOSA\nInfligira " + str(action.value) + " de daño masivo.\n\n[No puede ser evadido]"
	
	# Añadir estado de debuffs si existen
	if e.get("atk_reduction", 0) > 0:
		txt += "\n\n--- ESTADO ---\nDEBILIDAD: -" + str(e["atk_reduction"]) + " ATK\n(Dura 1 turno)"

	# Mostrar el tooltip debajo del panel
	var tip = Label.new()
	tip.name = "EnemyIntentTooltip"
	tip.text = txt
	tip.add_theme_font_size_override("font_size", 12)
	tip.modulate = Color(0.9, 0.9, 0.6)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	# Posicion Y=240 para que aparezca debajo del panel (que mide 230)
	var p = _make_panel(Vector2(-10, 240), Vector2(220, 140), Color(0,0,0,0.95), Color(0.5, 0.5, 0.2))
	p.name = "TooltipPanel"
	p.z_index = 100
	p.add_child(tip); tip.position = Vector2(10, 10); tip.size = Vector2(200, 120)
	e.panel.add_child(p)

func _hide_enemy_intent_tooltip(idx: int) -> void:
	if idx < enemies.size() and is_instance_valid(enemies[idx].panel):
		var p = enemies[idx].panel.get_node_or_null("TooltipPanel")
		if p: p.queue_free()

func _populate_relics() -> void:
	if not relics_container: return
	var relic_scene = load("res://scenes/ui/RelicIcon.tscn")
	for relic_id in GameManager.relics:
		if not GameManager.RELIC_DATA.has(relic_id): continue
		if relic_scene:
			var icon = relic_scene.instantiate()
			relics_container.add_child(icon)
			icon.setup(relic_id)
		else:
			var lbl = Label.new()
			lbl.text = GameManager.RELIC_DATA[relic_id].get("name", relic_id)
			lbl.add_theme_font_size_override("font_size", 11)
			relics_container.add_child(lbl)

# ── Helpers UI ─────────────────────────────────────────────────────────────────
func _make_panel(pos, sz, bg, border) -> Panel:
	var p = Panel.new(); p.position = pos; p.size = sz
	var s = StyleBoxFlat.new(); s.bg_color = bg
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.border_color = border
	p.add_theme_stylebox_override("panel", s); return p

func _make_hp_bar(max_v, w) -> ProgressBar:
	var b = ProgressBar.new(); b.max_value = max_v; b.value = max_v
	b.custom_minimum_size = Vector2(w, 12); b.show_percentage = false; return b

func _make_pile_label(pos: Vector2, col: Color) -> Label:
	var lbl = Label.new(); lbl.position = pos; lbl.size = Vector2(140, 28)
	lbl.add_theme_font_size_override("font_size", 13); lbl.modulate = col; return lbl

func show_message(txt, col: Color) -> void:
	lbl_message.text = txt; lbl_message.modulate = col
	lbl_message.visible = true
	
	if GameManager.sanity < 30:
		# Efecto de sacudida de texto
		var orig_pos = lbl_message.position
		var tw = create_tween().set_loops(10)
		tw.tween_property(lbl_message, "position", orig_pos + Vector2(randf_range(-5,5), randf_range(-3,3)), 0.05)
		tw.tween_property(lbl_message, "position", orig_pos, 0.05)
	
	create_tween().tween_property(lbl_message, "modulate:a", 1.0, 0.5).from(0.0)

var active_flashes: Array = []

func flash_small(text: String) -> void:
	var f = Label.new()
	f.text = text
	f.add_theme_font_size_override("font_size", 17)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.modulate = Color(1.0, 0.85, 0.2) # Amarillo dorado
	f.add_theme_constant_override("outline_size", 4)
	f.add_theme_color_override("font_outline_color", Color(0,0,0,0.8))
	
	# Posición base con desplazamiento según cuántos hay activos
	var offset = active_flashes.size() * 25
	f.position = Vector2(300, 250 + offset)
	f.size = Vector2(552, 30) # Centrado relativo al panel
	f.z_index = 100
	add_child(f)
	
	active_flashes.append(f)
	
	var t = create_tween()
	# Subir mientras desaparece
	t.tween_property(f, "position:y", f.position.y - 60, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(f, "modulate:a", 0.0, 2.0)
	t.chain().tween_callback(func(): 
		active_flashes.erase(f)
		f.queue_free()
	)

# ── Hastur ─────────────────────────────────────────────────────────────────────
func _start_hastur_madness_loop() -> void:
	while not combat_ended:
		await get_tree().create_timer(randf_range(3, 6)).timeout
		if combat_ended: break
		var f = Label.new(); f.text = "H A S T U R"
		f.add_theme_font_size_override("font_size", 100)
		f.modulate = Color(0.8, 0.1, 0.1, 0.5)
		f.position = Vector2(0, 200); f.size = Vector2(1152, 200)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; f.z_index = 5; add_child(f)
		await get_tree().create_timer(0.12).timeout; f.queue_free()
