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
var turn_counter: int = 1 # Contador para Reloj Circular
var furia_points: int = 0
var damage_received_pool: int = 0 # Acumulador para la pasiva del Guardián
 # Pasiva del Guardián: daño acumulado para el siguiente ataque

# ── UI & Visuals ──────────────────────────────────────────────────────────────
var ui: Node # Instancia de CombatUI.gd

# Atajos para evitar cambiar todo el código (Proxies con sintaxis correcta)
var player_panel: Panel:
	get: return ui.player_panel
var player_sprite_label: Label:
	get: return ui.player_sprite_label
var lbl_player_hp: Label:
	get: return ui.lbl_player_hp
var hp_bar_player: ProgressBar:
	get: return ui.hp_bar_player
var sanity_bar_player: ProgressBar:
	get: return ui.sanity_bar_player
var lbl_energy: Label:
	get: return ui.lbl_energy
var lbl_furia: Label:
	get: return ui.lbl_furia
var hand_container: Control:
	get: return ui.hand_container
var lbl_draw_pile: Label:
	get: return ui.lbl_draw_pile
var lbl_discard_pile: Label:
	get: return ui.lbl_discard_pile
var end_turn_btn: Button:
	get: return ui.end_turn_btn
var relics_container: HBoxContainer:
	get: return ui.relics_container
var log_panel: Panel:
	get: return ui.log_panel
var log_vbox: VBoxContainer:
	get: return ui.log_vbox
var lbl_message: Label:
	get: return ui.lbl_message
var panel_message: Panel:
	get: return ui.panel_message
var vignette: ColorRect:
	get: return ui.vignette
var eye_node: Control:
	get: return ui.eye_node
var blink_overlay: ColorRect:
	get: return ui.blink_overlay
var targeting_arrow: Line2D:
	get: return ui.targeting_arrow

var targeting_active: bool = false
var targeting_card = null
var time_since_mouse_move: float = 0.0
var is_eye_breaking_4th_wall: bool = false
var last_m_pos: Vector2 = Vector2.ZERO
var rey_music_triggered: bool = false  # Si ya se activó la música al recibir el primer golpe

# ── Pools de encuentros ────────────────────────────────────────────────────────
# ── Setup ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Cargar e instanciar CombatUI
	var ui_script = load("res://scripts/CombatUI.gd")
	ui = Node.new()
	ui.set_script(ui_script)
	add_child(ui)
	ui.setup(self)

	var vp = get_viewport_rect().size
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("resting_song")
		# Boss del mundo: intro_title_song, excepto Rey Sin Corona (tiene su propio lamento)
		var is_rey_sin_corona = GameManager.is_final_boss and GameManager.current_world == 0
		if (GameManager.is_boss_fight or GameManager.is_final_boss) and not is_rey_sin_corona:
			AudioManager.stop_loop("map_ambient_song")
			AudioManager.play_loop("intro_title_song")
		elif is_rey_sin_corona:
			AudioManager.stop_loop("map_ambient_song")
			AudioManager.play_loop("king_intro_sound") # Lamento inicial
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

	# Sinergia Reliquia: Ojo del Grito
	if GameManager.has_relic("ojo_grito") and GameManager.sanity < 40:
		for e_g in enemies:
			e_g["atk_reduction"] = e_g.get("atk_reduction", 0) + 999
		flash_small("Ojo del Grito: el miedo inmoviliza a los enemigos 1 turno.", Color(0.8, 0.2, 0.3))
		_flash_relic("ojo_grito")
		await get_tree().create_timer(0.1).timeout
		# Se limpia al finalizar el primer turno enemigo (atk_reduction se resetea en _on_end_turn)

	# Sinergia Reliquia: Manual del Anatomista — intenciones visibles desde el primer turno
	if GameManager.has_relic("manual_anatomista"):
		for e_m in enemies:
			e_m["intent_visible"] = true
		flash_small("Manual del Anatomista: intenciones enemigas reveladas.", Color(0.55, 0.75, 0.55))

	create_tween().tween_property(self, "modulate:a", 1.0, 0.45)

	# Despertar del Ojo (si es la primera vez con baja cordura)
	if GameManager.sanity < 55 and not GameManager.sanity_notified:
		GameManager.sanity_notified = true
		await get_tree().create_timer(0.5).timeout
		_trigger_screen_blink()
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
		show_message("EL TABLERO TE OBSERVA", Color(0.8, 0.4, 1.0))
		await get_tree().create_timer(1.5).timeout
		panel_message.visible = false

	if not enemies.is_empty():
		var is_avatar = "AVATAR" in enemies[0].name.to_upper()
		
		if GameManager.is_hastur_fight:
			_start_hastur_madness_loop()
		elif not is_avatar:
			var char_id = GameManager.selected_character
			var char_info = CombatData.CHAR_DATA.get(char_id, {"symbol": "♟", "color": Color.WHITE})
			var thought = LoreData.get_player_thought(char_id, GameManager.sanity, enemies[0].name)

			# Sobrescribir pensamiento si es el Rey Sin Corona
			if enemies[0].name == "EL REY SIN CORONA":
				match char_id:
					"conquistador": thought = "He servido a tronos de oro... pero este solo huele a muerte y polvo."
					"estratega": thought = "Las crónicas hablaban de un soberano, no de esta aberración esquelética."
					"guardian": thought = "Juré proteger la corona... pero no queda cabeza donde ponerla."
					"prince": thought = "Padre... ¿qué te han hecho los susurros de Carcosa?"

			await get_tree().create_timer(0.9).timeout
			# Mostrar pensamiento flotante sobre el personaje (Alineado a la izquierda)
			var thought_with_name = "[" + char_id.to_upper() + "]: " + thought
			_show_floating_dialogue(thought_with_name, char_info["color"], Vector2(50, 180))


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
	
	var chambers_quote = "Canto de mi alma, se me ha muerto la voz. Muere, sin ser cantada, como las lágrimas no derramadas se secan y mueren en la Perdida Carcosa..."

	# Panel clip para revelar de arriba hacia abajo
	var clip_lbl = Panel.new()
	clip_lbl.clip_contents = true
	clip_lbl.position = Vector2(vp.x * 0.2, vp.y * 0.3)
	clip_lbl.size = Vector2(vp.x * 0.6, 0)
	var empty_s = StyleBoxEmpty.new()
	clip_lbl.add_theme_stylebox_override("panel", empty_s)
	layer.add_child(clip_lbl)

	var quote_lbl = Label.new()
	quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	quote_lbl.text = chambers_quote
	quote_lbl.position = Vector2(0, 0)
	quote_lbl.size = Vector2(vp.x * 0.6, vp.y * 0.4)
	quote_lbl.add_theme_font_size_override("font_size", 22)
	quote_lbl.modulate = Color(0.9, 0.8, 0.3)
	clip_lbl.add_child(quote_lbl)

	# Revelar de arriba hacia abajo
	var reveal_tw = create_tween()
	reveal_tw.tween_property(clip_lbl, "size:y", vp.y * 0.4, 1.8)
	await reveal_tw.finished
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
	log_message("AVATAR", msg, Color(0.8, 0.4, 1.0))
	
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
			pool = [{"name": "EL REY AMARILLO",   "hp": 220, "pattern": [
				{"type": "attack", "value": 16}, 
				{"type": "anular_energia", "value": 0},
				{"type": "shield", "value": 15}, 
				{"type": "attack", "value": 22},
				{"type": "curse_hand", "value": 0}
			]}]
		else:
			pool = [{"name": "EL REY SIN CORONA", "hp": 150, "pattern": [
				{"type": "attack", "value": 12}, 
				{"type": "shield", "value": 10},  
				{"type": "attack", "value": 18}
			]}]
	elif GameManager.is_boss_fight:
		if GameManager.current_world == 0:
			pool = CombatData.BOSS_POOLS_W1[randi() % CombatData.BOSS_POOLS_W1.size()]
		else:
			pool = CombatData.BOSS_POOLS_W2[randi() % CombatData.BOSS_POOLS_W2.size()]
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
	elif GameManager.is_in_void_path:
		# Enemigos de la Grieta (Mucho más fuertes y exclusivos)
		if GameManager.void_path_step == 2:
			# Sala 3: El Centinela Abisal (Jefe Secreto)
			pool = [{"name": "EL CENTINELA ABISAL", "hp": 130, "pattern": [
				{"type": "attack", "value": 15}, 
				{"type": "shield", "value": 20}, 
				{"type": "ultimate_charge", "value": 0},
				{"type": "ultimate_attack", "value": 35}
			]}]
		else:
			# Salas 1 y 2: Enemigos élite del vacío
			var void_enemies = [
				[{"name": "Espectro del Vacío", "hp": 50, "pattern": [{"type": "attack", "value": 14}, {"type": "debuff_sanity", "value": 12}]}],
				[{"name": "Caballero de Carcosa", "hp": 70, "pattern": [{"type": "shield", "value": 12}, {"type": "attack", "value": 16}]}]
			]
			pool = void_enemies[randi() % void_enemies.size()]
	else:
		pool = CombatData.NORMAL_POOLS[randi() % CombatData.NORMAL_POOLS.size()]

	enemies.clear()
	for e_data in pool:
		var pen_mode = ""
		if e_data["name"] == "El Penitente":
			pen_mode = "silence" if randf() < 0.5 else "mercy"
			if get_node_or_null("/root/AudioManager"):
				AudioManager.play_loop("Cry_whisper_woman_sound")
				AudioManager.update_loop_params("Cry_whisper_woman_sound", -15.0, 0.8)
		
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
	ui.build_ui(get_viewport_rect().size)

func update_ui() -> void:
	ui.update_ui()

# ── Cartas ─────────────────────────────────────────────────────────────────────
func draw_hand(count: int = -1) -> void:
	if count == -1:
		# Lógica de inicio de turno
		var keep_hand = GameManager.has_relic("reloj_circular") and turn_counter % 3 == 0
		
		if not keep_hand:
			for c in hand_container.get_children(): c.queue_free()
			for h in hand: discard_pile.append(h)
			hand.clear()
		else:
			flash_small("RELOJ CIRCULAR: Mantienes tu mano.")
			_flash_relic("reloj_circular")

		# Calcular robo base
		count = 3
		if GameManager.sanity >= 80: count += 1
		if GameManager.selected_character == "estratega": count += 1
		
		# Efecto Cáliz del Olvido (Solo Turno 1)
		if GameManager.has_relic("caliz_olvido") and turn_counter == 1:
			if not draw_pile.is_empty():
				draw_pile.shuffle()
				var lost = draw_pile.pop_front()
				log_message("CÁLIZ", "El olvido consume: " + lost["name"], Color(0.5, 0.2, 0.8))
				player_energy += 1
				count += 2
				_flash_relic("caliz_olvido")
				flash_small("Cáliz del Olvido: +1 Energía, +2 Robo.")

	var deck_pos = lbl_draw_pile.global_position
	# Límite de mano: 10 cartas
	var actual_to_draw = min(count, 10 - hand.size())
	
	for i in range(actual_to_draw):
		if draw_pile.is_empty() and not discard_pile.is_empty():
			draw_pile = discard_pile.duplicate(); discard_pile.clear(); draw_pile.shuffle()

		if draw_pile.is_empty(): 
			# Si el jugador se quedó sin cartas literalmente en toda la run
			if hand.is_empty() and i == 0:
				flash_small("EL VACÍO TE RECLAMA. No quedan piezas.")
				var desperate_card = {"name": "Maldición de Ceniza", "attack": 0, "defense": 0, "cost": 0, "curse": true}
				hand.append(desperate_card)
				_spawn_card_node(desperate_card, deck_pos, 0)
			break

		var c_data = draw_pile.pop_front()
		hand.append(c_data)
		_spawn_card_node(c_data, deck_pos, i * 0.1)

	update_card_states()
	reorganize_hand()

	if get_node_or_null("/root/AudioManager"): AudioManager.play("card_draw")

func reorganize_hand() -> void:
	var all_children = hand_container.get_children()
	var cards = []
	for c in all_children:
		if not c.is_queued_for_deletion():
			cards.append(c)

	var n = cards.size()
	if n == 0: return

	var container_w = hand_container.size.x
	var card_w = 130.0
	var max_w = container_w - card_w

	# Espaciado dinámico: más cartas = más solapamiento (abanico)
	var spacing = min(145.0, max_w / float(max(1, n - 1)))
	var total_w = spacing * (n - 1)
	
	# ALINEAR A LA IZQUIERDA: Margen fijo en lugar de centrado
	var start_x = 20.0 

	for i in range(n):
		var card = cards[i]
		var target_x = start_x + (i * spacing)

		# Efecto de arco (abanico)
		var offset_center = float(i) - (float(n - 1) / 2.0)
		var target_y = abs(offset_center) * 8.0 # Bajan un poco a los lados
		var target_rot = offset_center * 0.04 # Rotan un poco

		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "position", Vector2(target_x, target_y), 0.3)
		tw.tween_property(card, "rotation", target_rot, 0.3)
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
	targeting_active = true; targeting_card = card; targeting_arrow.visible = true; card.set_disabled(true)

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

	# Logica de Parpadeo (Blinks) sutil en baja cordura
	if not combat_ended and GameManager.sanity < 35:
		if randf() < 0.008:
			_trigger_screen_blink()
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

func _flash_relic(relic_id: String) -> void:
	if not relics_container: return
	var r_name = GameManager.RELIC_DATA.get(relic_id, {"name": relic_id})["name"]
	log_message("RELIQUIA", "Se activa: " + r_name, Color(0.9, 0.8, 0.2))
	
	for icon in relics_container.get_children():
		if icon.get("relic_id") == relic_id:
			# Efecto de pulso
			var tw = create_tween().set_parallel(true)
			tw.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.1)
			tw.tween_property(icon, "modulate", Color(2, 2, 2), 0.1)
			tw.chain().set_parallel(true)
			tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.2)
			tw.tween_property(icon, "modulate", Color(1, 1, 1), 0.2)
			
			# Partículas rápidas (ColorRects temporales)
			for i in range(8):
				var p = ColorRect.new()
				p.size = Vector2(4, 4)
				p.position = icon.global_position + Vector2(20, 20)
				add_child(p)
				var pt = create_tween().set_parallel(true)
				var dest = p.position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
				pt.tween_property(p, "position", dest, 0.4)
				pt.tween_property(p, "modulate:a", 0.0, 0.4)
				pt.tween_callback(p.queue_free).set_delay(0.4)
			break

# ── Resolver carta ─────────────────────────────────────────────────────────────
func _resolve_card(card, enemy_idx: int) -> void:
	var effective_cost = card.get_effective_cost()
	
	if player_energy < effective_cost: 
		card.set_disabled(false); return
	
	player_energy -= effective_cost
	
	# 1. Quitar de la mano lógica
	for i in range(hand.size()):
		if hand[i].get("name", "").to_upper() == card.card_name:
			hand.remove_at(i); break

	if get_node_or_null("/root/AudioManager"): AudioManager.play("card_play")
	log_message("TU", "Juegas " + card.card_name, Color(0.4, 0.8, 1.0))

	var card_handled = false
	var target_e = null
	if enemy_idx >= 0 and enemy_idx < enemies.size(): target_e = enemies[enemy_idx]
	var c_upper = card.card_name.to_upper()

	# ── LÓGICA DE CARTAS ESPECIALES ──
	if "APOCALIPSIS" in c_upper:
		card_handled = true
		for e_aoe in enemies:
			if e_aoe.hp > 0:
				e_aoe.hp -= 30
				_spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), 30, Color(1, 0, 0))
				if e_aoe.hp <= 0: await _kill_enemy(e_aoe)
		
	elif "SIGNO AMARILLO" in c_upper:
		card_handled = true
		GameManager.sanity = min(100, GameManager.sanity + 50)
		GameManager.mark_level += 1
		GameManager.player_max_energy += 1
		player_max_energy = GameManager.player_max_energy
		player_energy += 1 
		
	elif "INCISION PRECISA" in c_upper:
		card_handled = true
		if target_e:
			var dmg = int(target_e.max_hp * 0.25)
			target_e.hp -= dmg
			flash_small("Incisión: " + str(dmg))
			_spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(0.5, 1, 0.5))
			_animate_enemy_hit(target_e)
			if target_e.hp <= 0: await _kill_enemy(target_e)
		else:
			flash_small("Selecciona un objetivo")
			# Devolver energia si falla el objetivo
			player_energy += effective_cost
			card.set_disabled(false)
			return

	elif "MIRADA QUE DEVORA" in c_upper:
		card_handled = true
		if target_e:
			target_e["bleed"] = target_e.get("bleed", 0) + 3
			_animate_enemy_hit(target_e)
			# Feedback visual directo de estado en lugar de un numero
			var lbl = Label.new()
			lbl.text = "🩸 SANGRADO"
			lbl.modulate = Color(0.8, 0.1, 0.3)
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.position = target_e.panel.global_position + Vector2(100, 60)
			lbl.z_index = 20; add_child(lbl)
			var t = create_tween().set_parallel(true)
			t.tween_property(lbl, "position:y", lbl.position.y - 60, 0.8)
			t.tween_property(lbl, "modulate:a", 0.0, 0.8)
			t.chain().tween_callback(lbl.queue_free)
			update_intent_labels() # ACTUALIZACIÓN EN TIEMPO REAL
		else:

			flash_small("Selecciona un objetivo")
			player_energy += effective_cost
			card.set_disabled(false)
			return

	elif "CENIZA PREVENTIVA" in c_upper:
		card_handled = true
		var discarded_count = hand.size()
		if discarded_count > 0:
			for c_rem in hand_container.get_children():
				if c_rem != card: c_rem.queue_free()
			for h_rem in hand: discard_pile.append(h_rem)
			hand.clear()
			
			var shield_gain = discarded_count * 3
			player_shield += shield_gain
			# Feedback visual: Número azul flotante
			_spawn_damage_number(player_panel.global_position + Vector2(200, 30), shield_gain, Color(0.4, 0.7, 1.0))
			flash_small("Ceniza Preventiva: +" + str(shield_gain) + " Escudo")
		else:
			flash_small("Mano vacía: No hay piezas que quemar.")
		update_ui()

	elif "ANALISIS" in c_upper:
		card_handled = true
		await draw_hand(2)

	elif "FORMACION" in c_upper:
		card_handled = true
		player_shield += card.defense

	elif "ECO" in c_upper:
		card_handled = true
		flash_small("¡ECO DEL VACÍO!")
		for e_aoe in enemies:
			if e_aoe.hp > 0:
				e_aoe.hp -= 4
				_spawn_damage_number(e_aoe.panel.global_position + Vector2(100, 60), 4, Color(0.7, 0.7, 1.0))
				_animate_enemy_hit(e_aoe)
				if e_aoe.hp <= 0: await _kill_enemy(e_aoe)
		update_ui()

	elif "SUSURRO DEBILITANTE" in c_upper:
		card_handled = true
		var is_last = hand.is_empty()
		var base_red = 6 + card.attack
		var reduction = base_red * 2 if is_last else base_red
		for e_deb in enemies:
			if e_deb.hp > 0:
				e_deb["atk_reduction"] = e_deb.get("atk_reduction", 0) + reduction
				# Feedback visual: Destello verde de debilidad
				var tw = create_tween()
				tw.tween_property(e_deb.panel, "modulate", Color(0.4, 1.2, 0.4), 0.1)
				tw.tween_property(e_deb.panel, "modulate", Color(1, 1, 1), 0.3)
		if is_last:
			flash_small("¡SUSURRO FINAL! Todos debilitados: -" + str(reduction))
			_trigger_screen_blink()
		else:
			flash_small("Susurro: Todos -" + str(reduction) + " ATK")
			var candidates = []
			for c_node in hand_container.get_children():
				if not c_node.is_queued_for_deletion() and c_node != card:
					candidates.append(c_node)
			if not candidates.is_empty():
				var to_discard = candidates[randi() % candidates.size()]
				for j in range(hand.size()):
					if hand[j]["name"].to_upper() == to_discard.card_name:
						discard_pile.append(hand[j]); hand.remove_at(j); break
				to_discard.queue_free()
		update_intent_labels()

	# ── LÓGICA DE ATAQUE Y DEFENSA GENÉRICA ──
	if not card_handled:
		if target_e:
			if target_e.peaceful and card.attack > 0: target_e.peaceful = false; _set_enemy_aggressive(target_e)
			var dmg = card.attack
			if "AVATAR" in target_e.name.to_upper(): dmg = int(dmg * (1.0 + (100 - GameManager.sanity) * 0.015))
			if "JAQUE ETERNO" in c_upper: dmg = clamp(15 + int((player_max_hp - player_hp) * 0.4), 15, 40)
			if GameManager.velo_broken: dmg += 2
			if GameManager.selected_character == "guardian" and furia_points >= 3:
				dmg *= 2; furia_points = 0; flash_small("¡RESILIENCIA!"); _trigger_screen_blink()

			var absorbed = min(target_e.shield, dmg)
			if absorbed > 0: target_e.shield -= absorbed; dmg -= absorbed; _animate_shield_block(target_e)
			if dmg > 0:
				target_e.hp -= dmg
				
				# MECÁNICA: La música del Rey Sin Corona cambia al recibir el primer golpe
				if "REY SIN CORONA" in target_e.name.to_upper() and not rey_music_triggered:
					rey_music_triggered = true
					if get_node_or_null("/root/AudioManager"):
						# No detener el lamento, sino hacerlo más grave y añadir la música de batalla
						AudioManager.update_loop_params("king_intro_sound", -12.0, 0.8) # Bajar mucho el pitch
						AudioManager.play_loop("intro_title_song")
						AudioManager.update_loop_params("intro_title_song", -6.0, 1.0) # Volumen moderado
						
				_spawn_damage_number(target_e.panel.global_position + Vector2(100, 60), dmg, Color(1, 0.3, 0.3))
				_animate_enemy_hit(target_e)
				if target_e.hp <= 0: await _kill_enemy(target_e)

		if card.defense > 0:
			player_shield += card.defense
			_spawn_damage_number(player_panel.global_position + Vector2(200, 30), card.defense, Color(0.4, 0.7, 1))

	# ── COSTES Y LIMPIEZA ──
	if "OFRENDA DE CARNE" in c_upper: player_hp -= 4
	elif "PESO DE LA VERDAD" in c_upper: player_hp -= 6
	if player_hp <= 0: _check_player_death(); return

	var target_pos = Vector2.ZERO
	if target_e: target_pos = target_e.panel.global_position + Vector2(100, 100)
	await card.play_attack_animation(target_pos)

	if not card.exhaust:
		discard_pile.append({"name": card.card_name, "attack": card.attack, "defense": card.defense, "cost": card.cost})
	else:
		flash_small(card.card_name + " se agota.")

	first_card_this_turn = false
	card.queue_free()
	reorganize_hand()
	cards_played_this_turn += 1
	if GameManager.has_relic("reloj_negro") and cards_played_this_turn % 3 == 0:
		player_energy = min(player_energy + 1, player_max_energy); _flash_relic("reloj_negro")
	
	update_ui(); update_intent_labels(); check_combat_end()


func _set_enemy_aggressive(e: Dictionary) -> void:
	if e.get("sprite_label") and e.sprite_label.has_method("set_aggressive"):
		e.sprite_label.set_aggressive(true)
	if e.name == "El Penitente" and get_node_or_null("/root/AudioManager"):
		# No detener el loop, sino distorsionarlo para que suene monstruoso
		AudioManager.update_loop_params("Cry_whisper_woman_sound", -2.0, 0.45) # Más fuerte y MUCHO más grave
		AudioManager.play_loop("Glith_distorsion_noised_sound") # Añadir estática abisal
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", -8.0, 0.7)
		
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
	# La reliquia Lengua del Tablero descifra todo automáticamente
	if GameManager.has_relic("lengua_tablero"):
		return original
		
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
	if e.name == "El Penitente" and get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Cry_whisper_woman_sound")

	if e.sprite_label: e.sprite_label.play_death()
	_spawn_death_particles(e.panel.global_position + Vector2(100, 110))
	var t = create_tween()
	t.tween_interval(0.2)
	t.tween_property(e.panel, "modulate:a", 0.0, 0.35)
	t.tween_callback(func(): e.panel.visible = false)
	
	_is_showing_death_dialogue = true
	await _show_death_dialogue(e.name)  # esperar a que el jugador haga clic
	_is_showing_death_dialogue = false
	
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

func _idle_bob(lbl: Control) -> void:
	var base_y = lbl.position.y
	create_tween().set_loops().tween_property(lbl, "position:y", base_y - 6, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_player_idle_bob() -> void:
	var base_y = player_sprite_label.position.y
	create_tween().set_loops().tween_property(player_sprite_label, "position:y", base_y - 4, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _trigger_screen_blink() -> void:
	if not blink_overlay: return
	blink_overlay.visible = true
	blink_overlay.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_property(blink_overlay, "modulate:a", 0.0, randf_range(0.15, 0.3))
	tw.tween_callback(func(): blink_overlay.visible = false)

func update_intent_labels() -> void:
	# Esta función ahora debería ser manejada por la UI o delegada
	if ui.has_method("update_intent_labels"):
		ui.update_intent_labels()

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
	panel_message.visible = false
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
		# Restaurar distorsión abisal (Glith) en lugar de beeps
		AudioManager.play("Glith_distorsion_noised_sound")
	
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

var is_sanity_loop_active: bool = false

func _sync_dynamic_audio() -> void:
	if not get_node_or_null("/root/AudioManager"): return
	
	# 1. Lógica para Hastur (Prioridad máxima)
	if GameManager.is_hastur_fight and not enemies.is_empty():
		var h = enemies[0]
		var hp_perc = float(h.hp) / float(h.max_hp)
		var intensity = 1.0 - hp_perc
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", -5.0 + (intensity * 7.0), 1.0 + (intensity * 0.6))
		return # En Hastur no aplicamos la lógica de cordura normal

	# 2. Lógica de Cordura Normal (Estado Sólido)
	if GameManager.sanity < 40:
		if not is_sanity_loop_active:
			is_sanity_loop_active = true
			AudioManager.play_loop("Glith_distorsion_noised_sound")
			AudioManager.update_loop_params("Glith_distorsion_noised_sound", -15.0, 0.9)
	else:
		if is_sanity_loop_active:
			is_sanity_loop_active = false
			AudioManager.stop_loop("Glith_distorsion_noised_sound")
var _is_showing_death_dialogue: bool = false

# ── Fin de combate ─────────────────────────────────────────────────────────────
func check_combat_end() -> void:
	# No terminar el combate si hay un dialogo de muerte activo o si ya se esta procesando el final
	if combat_ended or _is_ending or _is_showing_death_dialogue: 
		print("DEBUG: check_combat_end skipped. Dialogue: ", _is_showing_death_dialogue)
		return
		
	var all_dead = true
	for e in enemies:
		if e.hp > 0: all_dead = false
	if not all_dead: return

	# Si llegamos aqui, todos estan muertos y no hay dialogos pendientes
	print("DEBUG: ALL DEAD. Ending combat.")
	_is_ending = true
	combat_ended = true
	
	# Detener distorsiones y música de boss
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Glith_distorsion_noised_sound")
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		AudioManager.stop_loop("king_intro_sound")
		AudioManager.stop_loop("intro_title_song")
	
	# Recuperación de Cordura al Ganar (Reducida por balance)
	GameManager.sanity = min(100, GameManager.sanity + 5)
	
	GameManager.player_hp = player_hp
	
	if (GameManager.is_elite_fight or GameManager.is_boss_fight) and GameManager.has_relic("caliz_olvido"):
		GameManager.player_max_energy += 1
		flash_small("Cáliz de Olvido: +1 Energía Máxima.")
		_flash_relic("caliz_olvido")

	GameManager.combat_count += 1
	GameManager.lore_progress += 1
	flash_small("📖 CONOCIMIENTO ADQUIRIDO (+1 Lore)", Color(0.4, 0.9, 1.0))
	
	if get_node_or_null("/root/AudioManager"): AudioManager.play("victory")
	
	var victory_phrases = CombatData.VICTORY_PHRASES
	show_message(victory_phrases[randi() % victory_phrases.size()], Color(0.85, 0.7, 0.2))
	await get_tree().create_timer(1.2).timeout
	
	# Desvanecer el panel de mensaje antes de pasar a la siguiente pantalla para evitar solapamientos
	var fade = create_tween()
	fade.tween_property(panel_message, "modulate:a", 0.0, 0.4)
	await fade.finished
	panel_message.visible = false
	panel_message.modulate.a = 1.0 # Reset para el próximo uso

	if GameManager.is_hastur_fight:
		# Final secreto — Hastur derrotado: victoria real
		GameManager.player_won = true
		_show_victory_cinematic(true)
		GameManager.go_to_scene("res://scenes/ui/GameOver.tscn")
	elif GameManager.is_final_boss:
		if GameManager.current_world == 0:
			# REY SIN CORONA caído → Mundo 2
			var lore_id = "rey_marfil"
			if not lore_id in GameManager.unlocked_lore:
				GameManager.unlock_lore(lore_id)
				await GameManager.lore_popup_closed
			else:
				GameManager.unlock_lore(lore_id)
			
			_show_relic_reward("__world2__")
			return
		else:

			# REY AMARILLO caído
			if GameManager.has_all_secret_items():
				# Los 3 fragmentos reunidos → Carcosa se abre → Hastur
				await _show_carcosa_transition()
				GameManager.is_final_boss = false
				GameManager.is_hastur_fight = true
				GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
			else:
				# Victoria normal sin secreto
				GameManager.player_won = true
				await _show_victory_cinematic(false)
				GameManager.go_to_scene("res://scenes/ui/GameOver.tscn")
	elif GameManager.is_boss_fight:
		# EL CARCELERO → reliquia → mapa
		_show_relic_reward("res://scenes/ui/Map.tscn")
	else:
		_show_loot_screen()

func _show_loot_screen() -> void:
	var vp = get_viewport_rect().size
	# Panel de despojos con estetica Carcosa
	var loot_panel = ui._make_panel(Vector2(vp.x/2 - 300, 120), Vector2(600, 380), Color(0.04, 0.04, 0.06, 0.96), Color(0.85, 0.75, 0.2))
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
		var draft_scene = load("res://scenes/ui/CardDraft.tscn")
		var draft = draft_scene.instantiate()
		draft.z_index = 200
		add_child(draft)
		# No hace falta conectar a señal si solo queremos que se cierre, 
		# pero podemos ocultar el panel de loot mientras tanto
		loot_panel.visible = false
		draft.connect("draft_completed", func():
			loot_panel.visible = true
		)
	)

	if randf() < 0.35:
		_add_loot_button(reward_vbox, "☤ Beber Esencia de Olvido (+8 Cordura)", func():
			GameManager.sanity = min(100, GameManager.sanity + 8)
		)

	var cont_btn = Button.new()
	cont_btn.text = "CONTINUAR EL VIAJE"
	cont_btn.position = Vector2(200, 315); cont_btn.size = Vector2(200, 45)
	cont_btn.pressed.connect(func():
		if GameManager.is_in_void_path:
			if GameManager.void_path_step == 2:
				GameManager.unlock_lore("centinela_nombre")
			GameManager.void_path_step += 1
			# Siempre volver al mapa de la grieta para ver el progreso
			GameManager.go_to_scene("res://scenes/ui/VoidMap.tscn")
		else:
			# Progresión normal del mapa (NO sumar piso aquí, Map.gd ya lo hizo al elegir)
			GameManager.go_to_scene("res://scenes/ui/Map.tscn")
	)
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
		var rpanel = ui._make_panel(Vector2(px, 100), Vector2(panel_w, panel_h),
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
		rdesc.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		# Ajustar panel si la descripción es muy larga
		var est_lines = rdesc.text.length() / 30 + rdesc.text.count("\n") + 1
		var desc_h = max(100, est_lines * 16)
		rdesc.position = Vector2(8, 104); rdesc.size = Vector2(panel_w - 16, desc_h)
		rpanel.add_child(rdesc)

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
				# Cinemática del Falso Rey
				await _show_yellow_truth_cinematic([
					"El Rey Sin Corona ha sido reclamado por el vacío.",
					"Buscó un trono que nunca existió, olvidando que en este tablero...",
					"Incluso los reyes son solo peones en manos del que viste de Amarillo.",
					"Bienvenido al Tablero Dorado. Donde la ceniza se vuelve ley."
				])
				
				GameManager.current_world = 1
				GameManager.map_graph = []
				GameManager.map_path = {} # Limpiar el camino del mundo anterior
				GameManager.current_map_floor = 0
				GameManager.current_map_col = -1
				
				# Recuperar fuerzas para el nuevo mundo
				GameManager.player_hp = GameManager.player_max_hp
				GameManager.sanity = 100
				
				GameManager.go_to_scene("res://scenes/ui/Map.tscn")
			else:
				GameManager.go_to_scene(next_scene)
		)

# ── Recompensa del Penitente ───────────────────────────────────────────────────
func _penitente_reward() -> void:
	# Marcar combate como terminado pacíficamente
	combat_ended = true
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		
	var has_trans = GameManager.has_relic("lengua_tablero")

	var lines = ["Tu paciencia es... inusual.", "Toma este eco de un juramento roto."]
	if has_trans:
		lines.append("Escucha: El Rey siente tu miedo, no tus piezas.")
		lines.append("Atácalo cuando tu mente esté más rota... es cuando más sangra.")

	# Mostrar diálogo del Penitente
	await _show_yellow_truth_cinematic(lines)

	# Preparar la carta única
	var p_card = {"name": "Plegaria de Ceniza", "attack": 0, "defense": 12, "cost": 0, "special": "penitente"}

	# Mostrar modal de recompensa clara
	_show_single_reward_modal("CARTA ÚNICA REVELADA", p_card, "res://scenes/ui/Map.tscn")

func _show_single_reward_modal(title_text: String, item_data: Dictionary, next_scene: String) -> void:
	var vp = get_viewport_rect().size
	
	# Usar un CanvasLayer para asegurar que está por encima de TODA la UI de combate
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	
	# Fondo oscuro bloqueante
	var dim = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.95)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.size = vp # Sizing manual para CanvasLayer
	layer.add_child(dim)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("relic_get")

	var title = Label.new(); title.text = title_text
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(0.9, 0.8, 0.2); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 60); dim.add_child(title)
	
	var is_card = item_data.has("cost")
	
	if is_card:
		var card_scene = load("res://scenes/combat/Card.tscn")
		var card_node = card_scene.instantiate()
		dim.add_child(card_node) # Primero al árbol
		card_node.setup(item_data) # Luego setup (ahora _ready ya tiene labels listos)
		card_node.position = Vector2(vp.x/2 - 65, vp.y/2 - 80)
		card_node.scale = Vector2(1.6, 1.6)
		# Forzar que la descripción sea visible en el modal
		card_node.mouse_filter = Control.MOUSE_FILTER_STOP 
		GameManager.add_card(item_data)
	
	var cont_btn = Button.new(); cont_btn.text = "ACEPTAR Y CONTINUAR"
	cont_btn.size = Vector2(280, 60); cont_btn.position = Vector2(vp.x/2 - 140, vp.y - 120)
	dim.add_child(cont_btn)
	
	cont_btn.pressed.connect(func():
		GameManager.go_to_scene(next_scene)
	)

# ── Turno enemigo ──────────────────────────────────────────────────────────────
func _on_end_turn_button_pressed() -> void:
	is_player_turn = false; end_turn_btn.disabled = true
	first_card_this_turn = true
	update_card_states()
	await get_tree().create_timer(0.4).timeout

	for e in enemies:
		if e.hp <= 0: continue

		# Bleed (Mirada que Devora)
		if e.get("bleed", 0) > 0:
			var bleed_dmg = e["bleed"]
			e.hp -= bleed_dmg
			e["bleed"] = max(0, e["bleed"] - 1)
			_spawn_damage_number(e.panel.global_position + Vector2(100, 60), bleed_dmg, Color(0.8, 0.1, 0.3))
			if e.get("sprite_label"): e.sprite_label.play_hit()
			log_message(e.name, "Sangra por %d de daño" % bleed_dmg, Color(0.8, 0.1, 0.3))
			update_ui()
			if e.hp <= 0:
				await _kill_enemy(e)
				continue

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

		# MECÁNICA: Aturdimiento
		if e.get("is_stunned", false):
			e["is_stunned"] = false
			flash_small(e.name + ": ¡ATURDIDO!")
			_show_enemy_banter(e.panel, "...", Color(0.5, 0.5, 0.5))
			await get_tree().create_timer(0.5).timeout
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
			
			var base_dmg = action.value
			var mark_bonus = 0
			if GameManager.mark_level > 0 and base_dmg > 0:
				mark_bonus = int(base_dmg * (0.25 * GameManager.mark_level))
				if mark_bonus < 1: mark_bonus = 1
				log_message("SIGNO AMARILLO", "La marca intensifica el dolor (+%d)" % mark_bonus, Color(1.0, 0.9, 0.2))
			
			var dmg = max(0, (base_dmg + mark_bonus) - e.get("atk_reduction", 0))
			var absorbed = min(player_shield, dmg)

			if absorbed > 0:
				player_shield -= absorbed; dmg -= absorbed
				if get_node_or_null("/root/AudioManager"): AudioManager.play("shield_block")
				_spawn_damage_number(player_panel.global_position + Vector2(200, 30), absorbed, Color(0.4, 0.7, 1.0))
				update_ui() # Actualizar escudo en tiempo real
			
			# Mostrar siempre el daño o el fallo si es un ataque
			if dmg > 0:
				player_hp -= dmg
				update_ui() # Actualizar HP en tiempo real
				log_message(e.name, "Te inflige %d de daño" % dmg, Color(1.0, 0.3, 0.3))
				_animate_player_hit()
				_spawn_damage_number(player_panel.global_position + Vector2(200, 30), dmg, Color(1, 0.3, 0.3))
				if get_node_or_null("/root/AudioManager"): AudioManager.play("player_hit")

				# Sinergia Reliquia: Ojo Arrancado — contraataque 2 de daño
				if GameManager.has_relic("ojo_arrancado"):
					e.hp -= 2
					_spawn_damage_number(e.panel.global_position + Vector2(100, 60), 2, Color(0.9, 0.55, 0.1))
					_flash_relic("ojo_arrancado")
				
				# Pasiva Guardian: Furia (Acumulativa: 1 por cada 5 de daño total recibido)
				if GameManager.selected_character == "guardian":
					damage_received_pool += dmg
					while damage_received_pool >= 5:
						damage_received_pool -= 5
						furia_points = min(3, furia_points + 1)
						flash_small("¡RESILIENCIA! Furia acumulada: " + str(furia_points) + "/3")
					update_ui()
				
				# --- EFECTO CORONA DE ESPINAS ---
				if GameManager.has_relic("corona_espinas"):
					var thorns_dmg = int(dmg * 0.2) # 20% base
					if thorns_dmg > 0:
						if GameManager.sanity < 50:
							thorns_dmg = int(thorns_dmg * 1.5) # +50% en locura (antes era x2)
							flash_small("¡ESPINAS DE CARCOSA! (+50%)")
						else:
							flash_small("Espinas: Contraataque.")

						thorns_dmg = clamp(thorns_dmg, 1, 12) # Tope máximo de 12 por golpe
						_flash_relic("corona_espinas")
						for e_thorns in enemies:
							if e_thorns.hp > 0:
								e_thorns.hp -= thorns_dmg
								_spawn_damage_number(e_thorns.panel.global_position + Vector2(100, 60), thorns_dmg, Color(0.8, 0.1, 0.1))
								_animate_enemy_hit(e_thorns)
						check_combat_end()

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
				
				player_hp -= self_dmg
				update_ui()
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
		
		elif action.type == "anular_energia":
			flash_small("¡SILENCIO ETERNO! No podrás actuar el próximo turno.")
			player_energy = 0 # El jugador empezará con 0
			_trigger_screen_blink()
			if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
			
		elif action.type == "curse_hand":
			var cards = hand_container.get_children()
			if not cards.is_empty():
				flash_small("¡CORRUPCIÓN! Tus piezas cambian de forma.")
				var target_card = cards[randi() % cards.size()]
				target_card.setup({"name": "Maldición de Ceniza", "attack": 0, "defense": 0, "cost": 1, "curse": true})
				target_card.modulate = Color(0.4, 0.1, 0.5)
				if get_node_or_null("/root/AudioManager"): AudioManager.play("curse_card")

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

	# Limpiar debuffs de TODOS los enemigos antes de que empiece el turno del jugador
	for e_final in enemies:
		e_final["atk_reduction"] = 0

	# Reset de energía (Basado en el nuevo máximo sincronizado)
	player_energy = player_max_energy

	# Sinergia Reliquia: Ficha de Marfil — drena 1 HP por turno
	if GameManager.has_relic("ficha_marfil"):
		player_hp -= 1
		flash_small("Ficha de Marfil: -1 HP", Color(0.9, 0.5, 0.2))
		_flash_relic("ficha_marfil")

	player_shield = 0

	# Sinergia Reliquia: Velo de la Dama (Negar la muerte una vez por RUN)
	if player_hp <= 0 and GameManager.has_relic("velo_dama") and not GameManager.velo_broken:
		player_hp = int(player_max_hp * 0.25) # Recupera 25% HP
		GameManager.velo_broken = true
		flash_small("¡EL VELO SE RASGA! La muerte ha sido negada.")
		log_message("VELO", "Venganza de la Dama activa: +2 ATK permanente.", Color(1, 0.2, 0.2))
		_flash_relic("velo_dama")
		if relics_container:
			for icon in relics_container.get_children():
				if icon.get("relic_id") == "velo_dama":
					icon.mark_broken()
					break
		_trigger_screen_blink()
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")

	if player_hp <= 0:
		_check_player_death()
		return

	GameManager.player_hp = player_hp
	cards_played_this_turn = 0
	
	# Incrementar turno para el jugador
	turn_counter += 1
	
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
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")],
		["FORZAR PENITENTE", func():
			GameManager.dev_force_penitente = true
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")],
		["+ Fragmentos x3", func():
			GameManager.add_secret_item("simbolo_amarillo")
			GameManager.add_secret_item("cancion_amarilla")
			GameManager.add_secret_item("carta_carcosa")
			show_message("Fragmentos: 3/3 — Hastur activado", Color(0.7, 0.3, 0.9))],
		["+ Reliquia: Traductor", func():
			GameManager.add_relic("lengua_tablero")
			flash_small("Reliquia obtenida: Lengua del Tablero")
			_populate_relics()],
		["Final: REY SIN CORONA", func():
			GameManager.is_hastur_fight = false
			GameManager.is_final_boss = true
			GameManager.current_world = 0
			_dev_force_win()],
		["SPAWN: REY SIN CORONA", func():
			GameManager.is_final_boss = true
			GameManager.current_world = 0
			get_tree().reload_current_scene()],
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
			GameManager.go_to_scene("res://scenes/combat/Combat.tscn")],
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
		["HOGUERA (Rest)", func(): GameManager.go_to_scene("res://scenes/ui/Rest.tscn")],
		["TESORO (Cofre)", func(): GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")],
	]

	for i in range(btns.size()):
		var b = Button.new()
		b.text = btns[i][0]
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(185, 32)
		b.pressed.connect(btns[i][1])
		vbox.add_child(b)

	var btn_gold = Button.new(); btn_gold.text = "ADD 100 GOLD"
	btn_gold.pressed.connect(func(): GameManager.add_coins(100); update_ui())
	vbox.add_child(btn_gold)
	
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
	var est_lines = text.length() / 30 + text.count("\n") + 1
	var ban_h = max(65, est_lines * 16)
	lbl.size = Vector2(220, ban_h)
	lbl.position = enemy_panel.global_position + Vector2(-10, -ban_h - 10)
	lbl.z_index = 12; add_child(lbl)
	var t = create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.8)
	t.tween_property(lbl, "modulate:a", 0.0, 0.5)
	t.tween_callback(lbl.queue_free)

func _typewrite(lbl: Label, text: String, base_delay: float = 0.02) -> void:
	lbl.text = ""
	for i in range(text.length()):
		lbl.text = text.substr(0, i + 1)
		var c = text[i]
		var wait = base_delay
		if c in [".", "!", "?"]:  wait = base_delay * 4.0
		elif c in [",", ";"]:     wait = base_delay * 2.0
		elif c == "\n":           wait = base_delay * 3.0
		await get_tree().create_timer(wait).timeout

func _show_death_dialogue(enemy_name: String) -> void:
	var text = LoreData.get_death_dialogue(enemy_name)
	if text.is_empty(): return

	# Encontrar el panel del enemigo que está muriendo
	var e_panel = null
	for e in enemies:
		if e.name == enemy_name:
			e_panel = e.panel
			break
	if not e_panel: return

	var col = Color(0.95, 0.8, 0.3) if enemy_name.begins_with("EL ") else Color(0.8, 0.8, 0.8)
	var pos = e_panel.global_position + Vector2(0, -35) # Más cerca del panel
	
	_show_floating_dialogue(text, col, pos, LoreData.is_garbled(text))

func _show_floating_dialogue(text: String, col: Color, pos: Vector2, is_cipher: bool = false) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	var lbl = Label.new()
	lbl.text = "\"%s\"" % text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size = Vector2(300, 80)
	lbl.position = pos - Vector2(lbl.size.x/2 - 100, 0) # Ajustar centrado local
	lbl.modulate = col
	lbl.modulate.a = 0
	layer.add_child(lbl)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.4)
	tw.tween_property(lbl, "position:y", lbl.position.y - 15, 0.4)
	
	if is_cipher:
		for _f in range(8):
			lbl.modulate.a = randf_range(0.4, 1.0)
			await get_tree().create_timer(0.06).timeout
		lbl.modulate.a = 1.0
	
	var wait_time = clamp(text.length() * 0.05, 2.5, 5.0)
	await get_tree().create_timer(wait_time).timeout
	
	var tw2 = create_tween().set_parallel(true)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw2.tween_property(lbl, "position:y", lbl.position.y - 20, 0.8)
	await tw2.finished
	layer.queue_free()

# ── Reliquias ──────────────────────────────────────────────────────────────────
func log_message(subject: String, text: String, color: Color) -> void:
	if not log_vbox: return
	
	var lbl = Label.new()
	lbl.text = "[%s]: %s" % [subject.to_upper(), text]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = color
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size.x = 280
	log_vbox.add_child(lbl)
	
	# Mantener solo los últimos 20 mensajes
	if log_vbox.get_child_count() > 20:
		log_vbox.get_child(0).queue_free()
	
	# Auto-scroll al final (esperar un frame para que el layout se actualice)
	await get_tree().process_frame
	var scroll = log_panel.get_child(0) as ScrollContainer
	if scroll:
		scroll.set_v_scroll(log_vbox.size.y)

func _show_player_passive_tooltip() -> void:
	var char_id = GameManager.selected_character
	var char_name = char_id.to_upper()
	var passive_txt = CombatData.PASSIVE_DESCRIPTIONS.get(char_id, "Sin descripción.")
	
	var txt = "[ HABILIDAD PASIVA ]\n"
	txt += char_name + "\n\n" + passive_txt
	
	var tip = Label.new()
	tip.name = "PassiveTooltipLabel"
	tip.text = txt
	tip.add_theme_font_size_override("font_size", 12)
	tip.modulate = Color(0.4, 0.8, 1.0) # Azul claro/Estrategia
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	# Cálculo más generoso de altura y ancho
	var panel_w = 280
	var line_count = txt.count("\n") + (txt.length() / 35) + 2 # Estimación de wrap
	var panel_h = line_count * 18 + 30

	var p = ui._make_panel(Vector2(85, -20), Vector2(panel_w, panel_h), Color(0,0,0,0.95), Color(0.2, 0.5, 0.8))
	p.name = "PassiveTooltipPanel"
	p.z_index = 100
	p.add_child(tip); tip.position = Vector2(12, 12); tip.size = Vector2(panel_w - 24, panel_h - 24)
	player_sprite_label.add_child(p)

func _hide_player_passive_tooltip() -> void:
	if is_instance_valid(player_sprite_label):
		var p = player_sprite_label.get_node_or_null("PassiveTooltipPanel")
		if p: p.queue_free()

func _show_enemy_intent_tooltip(idx: int) -> void:
	if idx >= enemies.size() or enemies[idx].hp <= 0: return
	var e = enemies[idx]
	var txt = ""
	
	if e.peaceful:
		txt = "ESTADO: PACIFICO\nNo atacara mientras no sea provocado.\n\n\"" + _get_enemy_banter(e.name) + "\""
	else:
		var has_manual = GameManager.has_relic("manual_anatomista")
		var is_insane = GameManager.sanity < 40 and not has_manual

		# --- EFECTO OJO DEL ORÁCULO ---
		if GameManager.has_relic("ojo_oraculo"):
			txt = "[👁 PREDICCIÓN DEL ORÁCULO]\n"
			var curr_idx = e.turn_index % e.pattern.size()
			var next_idx = (e.turn_index + 1) % e.pattern.size()

			for i in [curr_idx, next_idx]:
				var action = e.pattern[i]
				var header = "TURNO ACTUAL: " if i == curr_idx else "PRÓXIMO TURNO: "
				var act_name = action.type.to_upper()

				# Codificar tipo si hay locura y no hay manual
				if is_insane and GameManager.sanity < 25:
					act_name = "▓▓▓▓▓" if randf() < 0.7 else "???"
				elif act_name == "ATTACK": act_name = "ATAQUE"

				var val_str = str(action.value)
				if is_insane:
					if GameManager.sanity < 25: val_str = "░"
					elif randf() < 0.5: val_str = "???"

				txt += header + act_name + " (" + val_str + ")\n"
			txt += "\n"

		var action = e.pattern[e.turn_index % e.pattern.size()]

		txt += "--- DETALLES ---\n"
		
		if action.type == "attack":
			var reduction = e.get("atk_reduction", 0)
			var final_dmg = max(0, action.value - reduction)
			var dmg_str = str(final_dmg) if not is_insane else "???"
			
			txt += "INTENCION: ATACAR\nInfligira " + dmg_str + " de daño."
			if reduction > 0 and not is_insane:
				txt += "\n(Debilitado: -" + str(reduction) + " ATK)"
			
			if not is_insane:
				txt += "\n\n[El escudo puede absorber este golpe]"
			else:
				txt += "\n\n[▓▒░ ERROR DE PERCEPCIÓN ░▒▓]"
				
		elif action.type == "shield":
			var val_str = str(action.value) if not is_insane else "▓"
			txt += "INTENCION: ESCUDO\nGanara " + val_str + " de proteccion."
			if not is_insane:
				txt += "\n\n[El escudo enemigo se resetea al inicio de su turno]"
			else:
				txt += "\n\n[▓▒░ ERROR DE PERCEPCIÓN ░▒▓]"
				
		elif action.type == "insanity":
			var val_str = str(action.value) if not is_insane else "!!"
			txt += "INTENCION: CORROMPER\nDrenara " + val_str + " de tu Cordura."
			if not is_insane:
				txt += "\n\n[La cordura baja distorsiona la realidad]"
			else:
				txt += "\n\n[▓▒░ ERROR DE PERCEPCIÓN ░▒▓]"
				
		elif action.type == "possession":
			if not is_insane:
				txt += "INTENCION: POSESIÓN\nHastur tomara una de tus piezas y la usara contra ti.\n\n[Pierdes la carta y recibes su daño]"
			else:
				txt += "INTENCION: 👁\nTODO PERTENECE AL REY."
				
		elif action.type == "ultimate_charge":
			txt += "INTENCION: PREPARACIÓN\n" + ("Hastur acumula energía..." if not is_insane else "EL CIELO SE RASGA.")
			
		elif action.type == "ultimate_attack":
			var val_str = str(action.value) if not is_insane else "MUERTE"
			txt += "INTENCION: JUICIO DE CARCOSA\nInfligira " + val_str + " de daño masivo."
	
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
	
	# Cálculo dinámico de altura más preciso
	var chars_per_line = 35
	var est_lines = txt.length() / chars_per_line + txt.count("\n") + 1
	var panel_h = max(120, est_lines * 18 + 25)

	# Posicion Y=240 para que aparezca debajo del panel (que mide 230)
	var p = ui._make_panel(Vector2(-10, 240), Vector2(220, panel_h), Color(0,0,0,0.95), Color(0.5, 0.5, 0.2))
	p.name = "TooltipPanel"
	p.z_index = 100
	p.add_child(tip); tip.position = Vector2(10, 10); tip.size = Vector2(200, panel_h - 20)

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

# ── Helpers UI (DELEGADOS A CombatUI.gd) ─────────────────────────────────────────

func show_message(txt, col: Color) -> void:
	lbl_message.text = txt; lbl_message.modulate = col
	panel_message.visible = true
	
	if GameManager.sanity < 30:
		# Efecto de sacudida de texto
		var orig_pos = panel_message.position
		var tw = create_tween().set_loops(10)
		tw.tween_property(panel_message, "position", orig_pos + Vector2(randf_range(-5,5), randf_range(-3,3)), 0.05)
		tw.tween_property(panel_message, "position", orig_pos, 0.05)
	
	panel_message.modulate.a = 0.0
	create_tween().tween_property(panel_message, "modulate:a", 1.0, 0.5)

var active_flashes: Array = []

func flash_small(text: String, col: Color = Color(1.0, 0.85, 0.2)) -> void:
	# Registrar en el log de combate
	log_message("SISTEMA", text, col)

	var f = Label.new()
	f.text = text
	f.add_theme_font_size_override("font_size", 17)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.modulate = col

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

# ── Cinemáticas de Verdad Amarilla ─────────────────────────────────────────────

func _show_yellow_truth_cinematic(lines: Array) -> void:
	var vp = get_viewport_rect().size
	var layer = CanvasLayer.new()
	layer.layer = 150
	add_child(layer)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1.0)
	bg.size = vp
	root.add_child(bg)

	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("ambient_hum")

	# Combinar todas las líneas en un solo bloque de texto
	var full_text = "\n\n".join(lines)

	# Contenedor con clip para revelar de arriba hacia abajo
	var text_x = vp.x * 0.1
	var text_y = vp.y * 0.15
	var text_w = vp.x * 0.8
	var text_h = vp.y * 0.7

	var clip = Panel.new()
	clip.clip_contents = true
	clip.position = Vector2(text_x, text_y)
	clip.size = Vector2(text_w, 0)  # Empieza sin altura visible
	var empty_style = StyleBoxEmpty.new()
	clip.add_theme_stylebox_override("panel", empty_style)
	root.add_child(clip)

	var lbl = Label.new()
	lbl.text = full_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.position = Vector2(0, 0)
	lbl.size = Vector2(text_w, text_h)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.modulate = Color(1.2, 1.0, 0.2)
	clip.add_child(lbl)

	# Revelar de arriba hacia abajo expandiendo el clip
	var reveal = create_tween()
	reveal.tween_property(clip, "size:y", text_h, 2.2)
	await reveal.finished

	await get_tree().create_timer(3.0).timeout

	# Efecto rotoscopia
	for i in range(4):
		if not is_instance_valid(bg): break
		bg.color = Color(0.1, 0.08, 0.0) if i % 2 == 0 else Color.BLACK
		lbl.visible = !lbl.visible
		await get_tree().create_timer(0.05).timeout

	lbl.visible = true
	bg.color = Color.BLACK

	# Desvanecer todo
	var out = create_tween()
	out.tween_property(root, "modulate:a", 0.0, 1.0)
	await get_tree().create_timer(1.2).timeout

	layer.queue_free()

func _show_avatar_defeat_lore() -> void:
	var count = GameManager.secret_items.size()
	var lines = []
	
	match count:
		1:
			lines = [
				"El Heraldo cae, pero su sombra permanece.",
				"Un solo fragmento de verdad es una carga pesada.",
				"Has visto el borde del tablero... y lo que hay debajo."
			]
		2:
			lines = [
				"Dos verdades chocan en tu mente.",
				"El Rey no está lejos, su risa resuena en tu mazo.",
				"¿Sientes la lluvia roja? Es el cielo llorando por tu ignorancia."
			]
		3:
			lines = [
				"EL VELO SE HA ROTO.",
				"Hastur no necesita buscarte. Tú ya eres suyo.",
				"Bienvenido a la Perdida Carcosa. Aquí el tiempo es solo una pieza más."
			]
		_:
			lines = ["El vacío devuelve tu mirada."]
			
	await _show_yellow_truth_cinematic(lines)

func _check_player_death() -> void:
	GameManager.player_hp = 0
	GameManager.delete_run_save() # Borrar partida guardada por muerte
	is_eye_breaking_4th_wall = true # El ojo te observa caer
	update_ui()
	
	# Detener distorsiones en derrota
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Glith_distorsion_noised_sound")
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		AudioManager.play("defeat")
		
	await get_tree().create_timer(2.5).timeout
	GameManager.go_to_scene("res://scenes/ui/GameOver.tscn")
