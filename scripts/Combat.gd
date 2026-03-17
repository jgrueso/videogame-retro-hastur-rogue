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

# ── Módulos de combate ─────────────────────────────────────────────────────────
var enemy_turn: Node
var card_resolver: Node
var cinematics: Node

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

	enemy_turn = Node.new()
	enemy_turn.set_script(load("res://scripts/combat/EnemyTurnProcessor.gd"))
	add_child(enemy_turn)
	enemy_turn.setup(self)

	card_resolver = Node.new()
	card_resolver.set_script(load("res://scripts/combat/CardResolver.gd"))
	add_child(card_resolver)
	card_resolver.setup(self)

	cinematics = Node.new()
	cinematics.set_script(load("res://scripts/combat/CinematicManager.gd"))
	add_child(cinematics)
	cinematics.setup(self)

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
	await cinematics.show_avatar_intro()

func _show_avatar_bark() -> void:
	cinematics.show_avatar_bark()

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
		var m = get_global_mouse_position()
		var from = targeting_card.global_position + Vector2(65, 0)
		ui.update_targeting_arrow(from, m)

		# Detectar enemigo bajo el cursor y destacarlo
		var hovered_panel: Panel = null
		for e in enemies:
			if e.hp > 0 and e.panel.get_global_rect().has_point(m):
				hovered_panel = e.panel
				break
		if hovered_panel:
			ui.highlight_enemy_panel(hovered_panel)
		else:
			ui.clear_target_highlight()

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
	ui.clear_target_highlight()
	if target >= 0:
		_resolve_card(targeting_card, target)
	else:
		targeting_card.set_disabled(false)
	targeting_active = false
	targeting_arrow.visible = false
	if ui.targeting_arrow_head:
		ui.targeting_arrow_head.visible = false
	targeting_card = null

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
	await card_resolver.resolve(card, enemy_idx)


func _set_enemy_aggressive(e: Dictionary) -> void:
	enemy_turn.set_enemy_aggressive(e)

# ── Sistema de Descifrado de Pensamientos ─────────────────────────────────────
func _get_deciphered_thought(original: String) -> String:
	return card_resolver.get_deciphered_thought(original)

func _get_penitente_thought() -> String:
	return card_resolver.get_penitente_thought()

# ── Animaciones ────────────────────────────────────────────────────────────────
func _animate_enemy_attack_unique(e: Dictionary) -> void:
	await enemy_turn.animate_enemy_attack_unique(e)

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
	var font_size = 22
	var rise = Vector2(randf_range(-20, 20), -55)
	var duration = 0.7

	if amount <= 0 and col.r > 0.7:
		lbl.text = "FALLÓ"; lbl.modulate = Color(0.6, 0.6, 0.65)
		font_size = 16; duration = 0.45
	elif col.g > 0.6 and col.r < 0.5:  # Curación (verde)
		lbl.text = "+%d" % amount; lbl.modulate = col
		duration = 1.0; rise = Vector2(randf_range(-10, 10), -65)
	elif col.b > 0.6 and col.r < 0.5:  # Escudo (azul)
		lbl.text = "🛡 %d" % amount; lbl.modulate = col
		font_size = 18; rise = Vector2(randf_range(-15, 15), -45)
	elif col == Color(0.8, 0.1, 0.3):  # Sangrado
		lbl.text = "🩸 %d" % amount; lbl.modulate = col
		rise = Vector2(randf_range(10, 30), -40)
	elif amount >= 25:  # Daño crítico
		lbl.text = "-%d!" % amount; lbl.modulate = Color(1.0, 0.5, 0.1)
		font_size = 34
	else:
		lbl.text = "-%d" % amount; lbl.modulate = col
		if amount >= 15: font_size = 28
		elif amount < 5: font_size = 18

	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.position = pos; lbl.z_index = 20; lbl.scale = Vector2(1.4, 1.4)
	add_child(lbl)

	# Animación punch + float
	var t = create_tween().set_parallel(true)
	t.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15)
	t.tween_property(lbl, "position", pos + rise, duration).set_delay(0.1)
	t.tween_property(lbl, "modulate:a", 0.0, duration * 0.6).set_delay(duration * 0.4)
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
	await enemy_turn.trigger_boss_phase_2(e)

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
				pass  # ya desbloqueado, no re-disparar popup

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
	cinematics.show_loot_screen()

func _add_loot_button(container: Control, txt: String, action: Callable) -> void:
	cinematics.add_loot_button(container, txt, action)

# ── Transición a Carcosa (secreto) ─────────────────────────────────────────────
func _show_carcosa_transition() -> void:
	await cinematics.show_carcosa_transition()

# ── Cinemática de victoria final ───────────────────────────────────────────────
func _show_victory_cinematic(is_hastur: bool) -> void:
	await cinematics.show_victory_cinematic(is_hastur)

# ── Recompensa de reliquia (boss / jefe final) ─────────────────────────────────
func _show_relic_reward(next_scene: String = "res://scenes/ui/Map.tscn") -> void:
	cinematics.show_relic_reward(next_scene)

# ── Recompensa del Penitente ───────────────────────────────────────────────────
func _penitente_reward() -> void:
	# Marcar combate como terminado pacíficamente
	combat_ended = true
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Cry_whisper_woman_sound")
		
	var has_trans = GameManager.has_relic("lengua_tablero")
	var p_card = {"name": "Plegaria de Ceniza", "attack": 0, "defense": 12, "cost": 0, "special": "penitente"}
	await _show_penitente_cinematic(has_trans, p_card)

func _show_single_reward_modal(title_text: String, item_data: Dictionary, next_scene: String) -> void:
	cinematics.show_single_reward_modal(title_text, item_data, next_scene)

# ── Turno enemigo ──────────────────────────────────────────────────────────────
func _on_end_turn_button_pressed() -> void:
	await enemy_turn.process_enemy_turn()

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

func _get_enemy_banter(enemy_name: String) -> String:
	return enemy_turn.get_enemy_banter(enemy_name)

func _get_banter_color(enemy_name: String, text: String) -> Color:
	return enemy_turn.get_banter_color(enemy_name, text)

func _show_enemy_banter(enemy_panel: Panel, text: String, col: Color = Color(0.9, 0.8, 0.5)) -> void:
	enemy_turn.show_enemy_banter(enemy_panel, text, col)

func _typewrite(lbl: Label, text: String, base_delay: float = 0.02) -> void:
	await cinematics.typewrite(lbl, text, base_delay)

func _show_death_dialogue(enemy_name: String) -> void:
	cinematics.show_death_dialogue(enemy_name)

func _show_floating_dialogue(text: String, col: Color, pos: Vector2, is_cipher: bool = false) -> void:
	await cinematics.show_floating_dialogue(text, col, pos, is_cipher)

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
	lbl.modulate.a = 0.0
	var tw_fade = create_tween()
	tw_fade.tween_property(lbl, "modulate:a", 1.0, 0.3)

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
	if e.panel and e.panel.get_node_or_null("TooltipPanel"): return  # ya visible, evitar duplicados
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
	
	# Añadir todos los estados activos
	var status_parts = []
	if e.get("bleed", 0) > 0:
		status_parts.append("🩸 Sangrado (%d): recibe %d daño al fin del turno, -1 cada turno." % [e["bleed"], e["bleed"]])
	if e.get("atk_reduction", 0) > 0:
		status_parts.append("⚡ Debilitado (-%d atk): daño de ataque reducido." % e["atk_reduction"])
	if e.get("is_stunned", false):
		status_parts.append("💫 Aturdido: saltará su próximo turno.")
	if not status_parts.is_empty():
		txt += "\n\n--- ESTADOS ---\n" + "\n".join(status_parts)

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

# ── Cinemática del Penitente ───────────────────────────────────────────────────

func _show_penitente_cinematic(has_relic_hint: bool, p_card: Dictionary) -> void:
	await cinematics.show_penitente_cinematic(has_relic_hint, p_card)

# ── Transición al Mundo 2 ──────────────────────────────────────────────────────

func _show_world2_transition() -> void:
	await cinematics.show_world2_transition()

# ── Cinemáticas de Verdad Amarilla ─────────────────────────────────────────────

func _show_yellow_truth_cinematic(lines: Array) -> void:
	await cinematics.show_yellow_truth_cinematic(lines)

func _show_avatar_defeat_lore() -> void:
	await cinematics.show_avatar_defeat_lore()

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
