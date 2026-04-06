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
var furia_points: int = 0:
	set(v):
		furia_points = clamp(v, 0, 3)
		if is_inside_tree():
			update_ui()
			update_card_states()
var shield_gained_this_turn: int = 0 # Acumulador de escudo por turno para la pasiva del Guardián
var enemy_attacked_last_turn: bool = false # Para Contraofensiva
var trono_carcosa_active: bool = false
var ojo_grito_first_turn: bool = false
var mahar_guided_struck: bool = false # Pasiva FERVOR: rastrear primer golpe del turno
var presion_points: int = 0            # Pasiva PRESIÓN TÁCTICA del Estratega (reset cada turno enemigo)
var prince_quiebre_active: bool = false # Príncipe: estado QUIEBRE cuando cordura llega a 0
var espejo_acero_active: bool = false   # Guardián: reflejo pendiente del Espejo de Acero

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
var lbl_fervor: Label:
	get: return ui.lbl_fervor
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
var targeting_destilado: String = ""        # ID del destilado en targeting de enemigo
var targeting_destilado_card: String = ""   # ID del destilado en targeting de carta
var _destilado_targeting_origin: Vector2 = Vector2.ZERO
# Estados de combate por destilados (se resetean por turno o por uso)
var destilado_next_atk_mult: float = 1.0   # Sangre del Ejecutor: +50% próximo ataque
var destilado_dmg_mult: float = 1.0        # Fragmento del Príncipe: +30% N turnos
var destilado_dmg_turns: int = 0
var destilado_chispa_debt: int = 0         # Chispa Efímera: -1 energía próximo turno
var destilado_rey_amarillo: bool = false    # Sangre del Rey Amarillo: daño x2 este turno
var destilado_resonancia_zero: bool = false # Resonancia de Coste Cero: cartas cuestan 0
var time_since_mouse_move: float = 0.0
var is_eye_breaking_4th_wall: bool = false

var last_m_pos: Vector2 = Vector2.ZERO
var rey_music_triggered: bool = false  # Si ya se activó la música al recibir el primer golpe

var _eye_breathe_t: float = 0.0
var _pupil_target: Vector2 = Vector2.ZERO
var _pupil_wander_timer: float = 0.0

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
		# Boss del mundo: intro_title_song, excepto Rey Sin Corona (tiene su propio lamento)
		var is_rey_sin_corona = GameManager.is_final_boss and GameManager.current_world == 0
		if GameManager.is_final_boss and not is_rey_sin_corona:
			AudioManager.crossfade_loop("map_ambient_song", "ES_The End Of All Things - Niklas Johansson", 2.0)
			AudioManager.stop_loop("resting_song")
		elif GameManager.is_boss_fight and not is_rey_sin_corona:
			AudioManager.crossfade_loop("map_ambient_song", "intro_title_song", 1.5)
			AudioManager.stop_loop("resting_song")
		elif is_rey_sin_corona:
			AudioManager.crossfade_loop("map_ambient_song", "king_intro_sound", 2.0)
			AudioManager.stop_loop("resting_song")
	modulate.a = 0.0
	player_hp = GameManager.player_hp
	player_max_hp = GameManager.player_max_hp
	
	# Reliquias y bonus de energia inicial
	player_max_energy = GameManager.player_max_energy
	if GameManager.has_relic("corona_dorada"):
		player_max_energy += 1
		GameManager.sanity = max(0, GameManager.sanity - 5)

	if GameManager.selected_character == "prince" and GameManager.current_world == 2:
		GameManager.sanity = 20  # Comienza en RESONANCIA en W3
		DialogueUI.toast("HAS VUELTO A CASA. LA GRIETA TE RECONOCE.", Color(0.7, 0.2, 1.0))
	elif GameManager.selected_character == "prince":
		GameManager.sanity = max(0, GameManager.sanity - 8)
		DialogueUI.toast("El Abismo susurra... -8 Cordura", Color(0.65, 0.3, 0.95))

	# Sinergia Reliquia: Escudo Astillado
	if GameManager.has_relic("escudo_astillado"):
		player_shield = 5

	# Sinergia Reliquia: Fragmento de la Mascara Palida — +2 energía
	if GameManager.has_relic("fragmento_mascara_palida"):
		player_energy += 2
		DialogueUI.toast("Fragmento de la Mascara: +2 Energia")

	# Sinergia Reliquia: Ceniza de la Guardia — +2 energía máxima solo en W3
	if GameManager.has_relic("ceniza_guardia") and GameManager.current_world == 2:
		player_max_energy += 2

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
		ojo_grito_first_turn = true
		DialogueUI.toast("Ojo del Grito: el miedo inmoviliza a los enemigos 1 turno.", Color(0.8, 0.2, 0.3))
		_flash_relic("ojo_grito")

	# Sinergia Reliquia: Manual del Anatomista — intenciones visibles desde el primer turno
	if GameManager.has_relic("manual_anatomista"):
		for e_m in enemies:
			e_m["intent_visible"] = true
		DialogueUI.toast("Manual del Anatomista: intenciones enemigas reveladas.", Color(0.55, 0.75, 0.55))

	# Sinergia Reliquia: Ojo del Testigo — revela patrones completos en W3
	if GameManager.has_relic("ojo_testigo") and GameManager.current_world == 2:
		for e_t in enemies:
			e_t["intent_visible"] = true
		DialogueUI.toast("Ojo del Testigo: los patrones del umbral son visibles.", Color(0.65, 0.2, 1.0))

	create_tween().tween_property(self, "modulate:a", 1.0, 0.45)

	# Refrescar HUD de reliquias si se obtiene una reliquia mid-combat
	Events.relic_was_chosen.connect(func(_rid): _populate_relics())

	# Despertar del Ojo (si es la primera vez con baja cordura)
	if GameManager.sanity < 55 and not GameManager.sanity_notified:
		GameManager.sanity_notified = true
		await get_tree().create_timer(0.5).timeout
		_trigger_screen_blink()
		if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_glitch")
		DialogueUI.cinematic("EL TABLERO TE OBSERVA", Color(0.8, 0.4, 1.0))
		await get_tree().create_timer(1.5).timeout

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
					"mahar": thought = "He servido a coronas de carne... pero esta solo huele a algo que llevaba siglos esperando."
					"estratega": thought = "Las crónicas hablaban de un soberano, no de esta aberración esquelética."
					"guardian": thought = "Juré proteger la corona... pero no queda cabeza donde ponerla."
					"prince": thought = "Padre... ¿qué te han hecho los susurros de Carcosa?"

			await get_tree().create_timer(0.9).timeout
			# Mostrar pensamiento flotante sobre el personaje (Alineado a la izquierda)
			var thought_with_name = "[" + char_id.to_upper() + "]: " + thought
			_show_floating_dialogue(thought_with_name, char_info["color"], Vector2(167, 280))


	is_player_turn = true
	enemy_attacked_last_turn = false
	await draw_hand()
	# --- LÓGICA ESPECIAL AVATAR DE HASTUR ---
	if not enemies.is_empty() and "AVATAR" in enemies[0].name.to_upper():
		await _show_avatar_intro() # Espera a que termine la frase
		# Llamamos a la nueva función de la UI para mostrarlo
		ui.reveal_avatar(0)
		GameManager.sanity = max(0, GameManager.sanity - 30)
		DialogueUI.toast("¡PRESENCIA ATERRADORA! -30 Cordura")

	# --- LÓGICA ESPECIAL VERDADERO HASTUR ---
	if GameManager.is_hastur_fight:
		# Hastur ES el caos. Drenaje inicial masivo
		GameManager.sanity = max(0, GameManager.sanity - 50)
		DialogueUI.toast("¡HASTUR HA LLEGADO! -50 Cordura")
		
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
		if GameManager.current_world == 2:
			pool = CombatData.BOSS_POOLS_W3_FINAL
		elif GameManager.current_world == 1:
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
		if GameManager.current_world == 2:
			pool = CombatData.BOSS_POOLS_W3[randi() % CombatData.BOSS_POOLS_W3.size()]
		elif GameManager.current_world == 0:
			pool = CombatData.BOSS_POOLS_W1[randi() % CombatData.BOSS_POOLS_W1.size()]
		else:
			pool = CombatData.BOSS_POOLS_W2[randi() % CombatData.BOSS_POOLS_W2.size()]
	elif GameManager.is_elite_fight or GameManager.dev_force_avatar:
		# --- PROBABILIDAD ESCALADA DEL AVATAR ---
		var items_count = GameManager.secret_items.size()
		var spawn_chance = 0.0
		if items_count == 1: spawn_chance = 0.15
		elif items_count == 2: spawn_chance = 0.35
		elif items_count >= 3: spawn_chance = 1.0 # Inevitable si tienes todo
		
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
	elif GameManager.current_world == 2 and GameManager.is_elite_fight:
		pool = CombatData.ELITE_POOLS_W3[randi() % CombatData.ELITE_POOLS_W3.size()]
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
	elif GameManager.is_mimic_chest:
		pool = CombatData.MIMIC_POOL
	elif GameManager.current_world == 2:
		pool = CombatData.NORMAL_POOLS_W3[randi() % CombatData.NORMAL_POOLS_W3.size()]
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
	ui.populate_destilados(_on_destilado_clicked)

func update_ui() -> void:
	ui.update_ui()

# ── Cartas ─────────────────────────────────────────────────────────────────────
func draw_hand(count: int = -1) -> void:
	var is_turn_start := (count == -1)
	if count == -1:
		# Lógica de inicio de turno
		var keep_hand = GameManager.has_relic("reloj_circular") and turn_counter % 3 == 0
		
		if not keep_hand:
			for c in hand_container.get_children(): c.queue_free()
			for h in hand: discard_pile.append(h)
			hand.clear()
		else:
			DialogueUI.toast("RELOJ CIRCULAR: Mantienes tu mano.")
			_flash_relic("reloj_circular")

		# Pasiva Mahar: FERVOR — resetear flag de primer golpe guiado
		mahar_guided_struck = false

		# Calcular robo base
		count = 3
		if GameManager.sanity >= 80: count += 1
		if GameManager.selected_character == "estratega": count += 1
		
		# Efecto Cáliz del Olvido (Solo Turno 1)
		if GameManager.has_relic("caliz_olvido") and turn_counter == 1:
			if not draw_pile.is_empty():
				draw_pile.shuffle()
				var lost = draw_pile.pop_front()
				DialogueUI.add_log("CÁLIZ", "El olvido consume: " + lost["name"], Color(0.5, 0.2, 0.8))
				player_energy += 1
				count += 2
				_flash_relic("caliz_olvido")
				DialogueUI.toast("Cáliz del Olvido: +1 Energía, +2 Robo.")

	var deck_pos = lbl_draw_pile.global_position
	# Límite de mano: 10 cartas
	var actual_to_draw = min(count, 10 - hand.size())
	
	for i in range(actual_to_draw):
		if draw_pile.is_empty() and not discard_pile.is_empty():
			draw_pile = discard_pile.duplicate(); discard_pile.clear(); draw_pile.shuffle()

		if draw_pile.is_empty(): 
			# Si el jugador se quedó sin cartas literalmente en toda la run
			if hand.is_empty() and i == 0:
				DialogueUI.toast("EL VACÍO TE RECLAMA. No quedan piezas.")
				var desperate_card = {"name": "Maldición de Ceniza", "attack": 0, "defense": 0, "cost": 0, "curse": true}
				hand.append(desperate_card)
				_spawn_card_node(desperate_card, deck_pos, 0)
			break

		var c_data = draw_pile.pop_front()
		hand.append(c_data)
		_spawn_card_node(c_data, deck_pos, i * 0.1)

	update_card_states()
	reorganize_hand()

	if is_turn_start:
		CombatLog.log_turn(turn_counter, true)
		ui._assign_cursed_card()
		update_ui()   # sincroniza _fervor_last_spent tras reset del flag

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
	
	card.connect("card_selected", _on_card_selected)
	card.connect("card_played",   _on_card_played)

func _on_card_selected(card) -> void:
	if targeting_destilado_card != "":
		var dest_id = targeting_destilado_card
		_clear_destilado_card_highlight()
		_apply_destilado(dest_id, -1, card)
		return
	targeting_active = true; targeting_card = card; targeting_arrow.visible = true; card.set_disabled(true)

func _on_card_played(card) -> void:
	if targeting_destilado_card != "":
		var dest_id = targeting_destilado_card
		_clear_destilado_card_highlight()
		_apply_destilado(dest_id, -1, card)
		return
	_resolve_card(card, -1)

# ── Targeting ──────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	# Deteccion de movimiento de raton para inactividad
	var m_pos = get_global_mouse_position()
	if m_pos.distance_to(last_m_pos) > 1.0:
		time_since_mouse_move = 0.0
		if is_eye_breaking_4th_wall and is_instance_valid(eye_node):
			is_eye_breaking_4th_wall = false
			var tw_reset = eye_node.create_tween()
			tw_reset.tween_property(eye_node, "modulate", Color(1.0, 1.0, 1.0, eye_node.modulate.a), 0.3)
		else:
			is_eye_breaking_4th_wall = false
	else:
		time_since_mouse_move += _delta
		if time_since_mouse_move > 8.0 and not is_eye_breaking_4th_wall:
			is_eye_breaking_4th_wall = true
			if is_instance_valid(eye_node):
				_start_4th_wall_stare()
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
			if GameManager.selected_character == "prince":
				if GameManager.sanity < 35:
					t_col = Vector3(0.08, 0.0, 0.18)   # Void violeta — RESONANCIA ABISAL
				elif GameManager.sanity < 60:
					t_col = Vector3(0.04, 0.0, 0.10)   # Añil oscuro — Sombra
			else:
				if GameManager.sanity < 30:
					t_col = Vector3(0.2, 0.15, 0.0)    # Amarillo-marrón — otros personajes
			
			vignette.material.set_shader_parameter("intensity", sanity_factor * 0.8)
			vignette.material.set_shader_parameter("tint", t_col)
		else:
			vignette.visible = false

	# Actualizar Ojo del Vacio
	if is_instance_valid(eye_node):
		var eye_intensity = clamp((55.0 - GameManager.sanity) / 55.0, 0.0, 1.0)
		eye_node.modulate.a = eye_intensity * 0.95

		# 2a. Breathing — el ojo respira
		_eye_breathe_t += _delta
		var breathe = 1.0 + sin(_eye_breathe_t * 1.4) * 0.035
		eye_node.scale = Vector2(1, 1) * (0.6 + eye_intensity * 0.4) * breathe

		# 2b. Sclera se enrojece/tiñe de violeta con la cordura
		var redness = clamp((40.0 - GameManager.sanity) / 40.0, 0.0, 1.0)
		var sclera_node = eye_node.get_node_or_null("EyeBg")
		if sclera_node:
			if GameManager.selected_character == "prince":
				sclera_node.modulate = Color(1.0 - redness * 0.25, 1.0 - redness * 0.45, 1.0 + redness * 0.15)
			else:
				sclera_node.modulate = Color(1.0, 1.0 - redness * 0.6, 1.0 - redness * 0.7)

		# 2c. Venas bloodshot/violeta aparecen progresivamente
		var vein_alpha = clamp((45.0 - GameManager.sanity) / 45.0, 0.0, 0.85)
		var is_prince = GameManager.selected_character == "prince"
		for vi in range(5):
			var vein = eye_node.get_node_or_null("Vein%d" % vi)
			if vein:
				vein.color.a = vein_alpha * (0.6 + vi * 0.08)
				if is_prince:
					vein.color = Color(0.55, 0.0, 0.9, vein.color.a)   # Purple veins

		# 2d. Iris glow — violeta eléctrico para Príncipe, ambar para otros
		var iris_node = eye_node.get_node("Iris")
		var iris_glow_factor = clamp((50.0 - GameManager.sanity) / 50.0, 0.0, 1.0)
		if not is_eye_breaking_4th_wall:
			if GameManager.selected_character == "prince":
				iris_node.modulate = Color(1.0 + iris_glow_factor * 0.3, 1.0 - iris_glow_factor * 0.4, 1.0 + iris_glow_factor * 0.8)
			else:
				iris_node.modulate = Color(1.0 + iris_glow_factor * 0.6, 1.0 - iris_glow_factor * 0.1, 1.0 - iris_glow_factor * 0.4)

		# 2e. Pupila organica — wander suave + lerp
		var pupil_node = iris_node.get_node("Pupil")
		_pupil_wander_timer -= _delta
		if _pupil_wander_timer <= 0.0:
			var wander_range = 8.0 + (30.0 - clamp(GameManager.sanity, 0, 30)) * 0.5
			_pupil_target = Vector2(randf_range(-wander_range, wander_range), randf_range(-wander_range * 0.4, wander_range * 0.4))
			_pupil_wander_timer = randf_range(0.4, 1.2) if GameManager.sanity >= 30 else randf_range(0.1, 0.5)

		var m_dir = (get_global_mouse_position() - iris_node.global_position).normalized()
		var base_pupil_pos = (m_dir * 10.0) - pupil_node.size / 2
		var target_pupil = base_pupil_pos + _pupil_target

		if is_eye_breaking_4th_wall:
			target_pupil = -pupil_node.size / 2  # Mira directo al frente
			iris_node.modulate = Color(2.0, 1.4, 0.8)  # Brillo intenso

		pupil_node.position = pupil_node.position.lerp(target_pupil, _delta * 6.0)

		# Dilatacion horizontal suave (pavor)
		var dilation_target = 1.0 + clamp((40.0 - GameManager.sanity) / 40.0, 0.0, 0.8)
		pupil_node.scale.x = lerpf(pupil_node.scale.x, dilation_target, _delta * 3.0)

		# Iris sigue al raton
		iris_node.position = (m_dir * 25.0) - iris_node.size/2

	# Efecto de temblor ritmico (latido) en baja cordura
	if not combat_ended and GameManager.sanity < 40:
		var shake_intensity = (40.0 - GameManager.sanity) * 0.08
		var t = Time.get_ticks_msec() / 1000.0
		var beat = abs(sin(t * 0.9 * PI)) * abs(sin(t * 1.8 * PI))
		position = Vector2(
			sin(t * 3.2) * shake_intensity * beat,
			cos(t * 2.5) * shake_intensity * beat * 0.5
		)
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

	if targeting_active:
		var m = get_global_mouse_position()
		var from: Vector2 = _destilado_targeting_origin if targeting_card == null \
			else targeting_card.global_position + Vector2(65, 0)
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

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_F9:
		CombatLog.verbosity = CombatLog.Verbosity.VERBOSE \
			if CombatLog.verbosity == CombatLog.Verbosity.NORMAL \
			else CombatLog.Verbosity.NORMAL
		DialogueUI.toast("Log: " + CombatLog.Verbosity.keys()[CombatLog.verbosity])
	elif event.keycode == KEY_F10:
		CombatLog.export_to_file()
		DialogueUI.toast("Log exportado → user://combat_log.txt")


func _input(event: InputEvent) -> void:
	# Cancelar selección de carta para destilado con Escape
	if targeting_destilado_card != "" and event is InputEventKey \
			and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_destilado_card_highlight()
		return
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
	targeting_active = false
	targeting_arrow.visible = false
	if ui.targeting_arrow_head:
		ui.targeting_arrow_head.visible = false

	if targeting_destilado != "":
		# Targeting de enemigo para un destilado
		var dest_id = targeting_destilado
		targeting_destilado = ""
		if target >= 0:
			_apply_destilado(dest_id, target)
		# Si no hay target válido: destilado queda en inventario (cancelado)
		return

	if target >= 0:
		_resolve_card(targeting_card, target)
	else:
		if targeting_card:
			targeting_card.set_disabled(false)
	targeting_card = null

var _is_resolving_extra_mirror_card: bool = false

func _flash_relic(relic_id: String) -> void:
	if not relics_container: return
	var r_name = GameManager.RELIC_DATA.get(relic_id, {"name": relic_id})["name"]
	DialogueUI.add_log("RELIQUIA", "Se activa: " + r_name, Color(0.9, 0.8, 0.2))
	
	for icon in relics_container.get_children():
		if icon.get("relic_id") == relic_id:
			# Efecto de pulso
			var tw = create_tween().set_parallel(true)
			tw.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.1)
			tw.tween_property(icon, "modulate", Color(2, 2, 2), 0.1)
			tw.chain().set_parallel(true)
			tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.2)
			tw.tween_property(icon, "modulate", Color(1, 1, 1), 0.2)
			
			# Partículas GPU (reemplaza el for range(8) de ColorRect)
			_make_gpu_burst(icon.global_position + Vector2(20, 20), 8, 20,
				Color(1.0, 0.95, 0.2, 1.0),
				Color(1.0, 0.6, 0.0, 0.0),
				40.0, 120.0, 0.45)
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
	var orig_scale = e.panel.scale
	# Flash blanco puro (overbright)
	var tf = create_tween()
	tf.tween_property(e.panel, "modulate", Color(4.0, 4.0, 4.0), 0.04)
	tf.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.18)
	# Sacudida horizontal
	var ts = create_tween()
	ts.tween_property(e.panel, "position", orig + Vector2(-8, 0), 0.04)
	ts.tween_property(e.panel, "position", orig + Vector2(8, 0), 0.04)
	ts.tween_property(e.panel, "position", orig + Vector2(-5, 0), 0.04)
	ts.tween_property(e.panel, "position", orig, 0.04)
	# Squash & stretch
	var tss = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tss.tween_property(e.panel, "scale", Vector2(orig_scale.x * 1.18, orig_scale.y * 0.82), 0.06)
	tss.tween_property(e.panel, "scale", orig_scale, 0.14)

func _animate_shield_block(e: Dictionary) -> void:
	if not e.panel: return
	var t = create_tween()
	t.tween_property(e.panel, "modulate", Color(0.4, 0.6, 1.4), 0.06)
	t.tween_property(e.panel, "modulate", Color(1, 1, 1), 0.2)

func _animate_player_hit() -> void:
	var orig = player_panel.position
	var orig_scale = player_panel.scale
	# Flash blanco puro (overbright)
	var tf = create_tween()
	tf.tween_property(player_panel, "modulate", Color(4.0, 4.0, 4.0), 0.04)
	tf.tween_property(player_panel, "modulate", Color(1, 1, 1), 0.22)
	# Sacudida horizontal
	var ts = create_tween()
	ts.tween_property(player_panel, "position", orig + Vector2(-6, 0), 0.04)
	ts.tween_property(player_panel, "position", orig + Vector2(6, 0), 0.04)
	ts.tween_property(player_panel, "position", orig, 0.05)
	# Squash & stretch (aplastamiento vertical al recibir impacto)
	var tss = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tss.tween_property(player_panel, "scale", Vector2(orig_scale.x * 0.88, orig_scale.y * 1.15), 0.06)
	tss.tween_property(player_panel, "scale", orig_scale, 0.16)

func _kill_enemy(e: Dictionary) -> void:
	if e.name == "El Penitente" and get_node_or_null("/root/AudioManager"):
		AudioManager.stop_loop("Cry_whisper_woman_sound")

	if e.sprite_label: e.sprite_label.play_death()
	_spawn_death_particles(e.panel.global_position + Vector2(100, 110))
	_dissolve_enemy(e.panel)
	_show_death_dialogue(e.name)
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

func _make_gpu_burst(pos: Vector2, count: int, z: int,
		col_from: Color, col_to: Color,
		vel_min: float, vel_max: float,
		lifetime: float) -> void:
	var gpu = GPUParticles2D.new()
	gpu.position = pos
	gpu.z_index = z
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.spread = 180.0
	mat.initial_velocity_min = vel_min
	mat.initial_velocity_max = vel_max
	mat.gravity = Vector3(0, 400, 0)
	mat.scale_min = 4.0
	mat.scale_max = 10.0
	var grad = Gradient.new()
	grad.set_color(0, col_from)
	grad.set_color(1, col_to)
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	gpu.process_material = mat
	gpu.amount = count
	gpu.lifetime = lifetime
	gpu.one_shot = true
	gpu.explosiveness = 0.95
	add_child(gpu)
	gpu.emitting = true
	get_tree().create_timer(lifetime + 0.5).timeout.connect(gpu.queue_free)

func _dissolve_enemy(panel: Panel) -> void:
	# Crear un ColorRect overlay que cubre el panel con el shader de dissolve
	var overlay = ColorRect.new()
	overlay.size = panel.size
	overlay.global_position = panel.global_position
	overlay.color = Color(0.12, 0.08, 0.14)  # Color oscuro abisal, similar al fondo del panel
	overlay.z_index = panel.z_index + 1
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/dissolve.gdshader")
	shader_mat.set_shader_parameter("progress", 0.0)
	shader_mat.set_shader_parameter("edge_color", Color(1.0, 0.45, 0.08, 1.0))
	overlay.material = shader_mat
	panel.get_parent().add_child(overlay)
	# Ocultar el panel original inmediatamente (el overlay lo reemplaza)
	panel.visible = false
	# Animar el dissolve
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(func(v: float): shader_mat.set_shader_parameter("progress", v), 0.0, 1.1, 0.55)
	tw.tween_callback(overlay.queue_free)

func _spawn_death_particles(pos: Vector2) -> void:
	_make_gpu_burst(pos, 14, 15,
		Color(1.0, 0.6, 0.1, 1.0),
		Color(0.8, 0.05, 0.0, 0.0),
		80.0, 220.0, 0.6)

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
	if GameManager.selected_character == "prince":
		if GameManager.sanity < 35:
			blink_overlay.color = Color(0.55, 0.0, 0.9)    # Deep void — RESONANCIA
		elif GameManager.sanity < 60:
			blink_overlay.color = Color(0.35, 0.05, 0.65)  # Dark violet — Sombra
		else:
			blink_overlay.color = Color(0.6, 0.4, 1.0)     # Pale violet — normal
	else:
		if GameManager.sanity < 20:
			blink_overlay.color = Color(0.7, 0.0, 0.0)
		elif GameManager.sanity < 35:
			blink_overlay.color = Color(0.85, 0.15, 0.1)
		else:
			blink_overlay.color = Color(1.0, 1.0, 1.0)
	var max_alpha = 0.25 if GameManager.selected_character == "prince" else 0.55
	blink_overlay.modulate.a = max_alpha
	var tw = create_tween()
	var fade_dur = randf_range(0.6, 1.2) if GameManager.selected_character == "prince" else randf_range(0.15, 0.3)
	tw.tween_property(blink_overlay, "modulate:a", 0.0, fade_dur)
	tw.tween_callback(func(): blink_overlay.visible = false)

func update_intent_labels() -> void:
	# Esta función ahora debería ser manejada por la UI o delegada
	if ui.has_method("update_intent_labels"):
		ui.update_intent_labels()

func _trigger_boss_phase_2(e: Dictionary) -> void:
	await enemy_turn.trigger_boss_phase_2(e)

func update_card_states() -> void:
	for card in hand_container.get_children():
		var blocked = not is_player_turn or card.get_effective_cost() > player_energy
		# QUIEBRE del Príncipe: cartas con coste de cordura no se pueden pagar
		if not blocked and prince_quiebre_active and card.card_data.get("sanity_cost", 0) > 0:
			blocked = true
		card.set_disabled(blocked)
		# Indicador visual de Contraofensiva
		if "CONTRAOFENSIVA" in card.card_name:
			if enemy_attacked_last_turn:
				card.modulate = Color(0.6, 1.2, 0.6) # Verde: condición activa
			else:
				card.modulate = Color(1.2, 0.6, 0.6) # Rojo: condición inactiva

	if GameManager.selected_character == "mahar":
		for card in hand_container.get_children():
			if card.has_method("_update_fervor_badge") and card.get("attack") > 0:
				card._update_fervor_badge()

	var hs = hand_container.get_child_count()
	for card in hand_container.get_children():
		if card.has_method("_refresh_context"):
			card._refresh_context(hs)

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
	var is_prince = GameManager.selected_character == "prince"
	var is_w3 = GameManager.current_world == 2
	if s < 60 and not sanity_60_triggered:
		sanity_60_triggered = true
		if is_w3:
			_show_mythical_text(CombatData.MYTH_W3_60[randi() % CombatData.MYTH_W3_60.size()], Color(0.45, 0.05, 0.75))
		elif is_prince:
			_show_mythical_text(CombatData.PRINCE_MYTH_60[randi() % CombatData.PRINCE_MYTH_60.size()], Color(0.7, 0.3, 1.0))
		else:
			_show_mythical_text(CombatData.MYTH_60[randi() % CombatData.MYTH_60.size()], Color(0.6, 0.4, 0.8))
	elif s < (35 if is_prince else 40) and not sanity_40_triggered:
		sanity_40_triggered = true
		if is_w3:
			_show_mythical_text(CombatData.MYTH_W3_40[randi() % CombatData.MYTH_W3_40.size()], Color(0.45, 0.05, 0.75))
		elif is_prince:
			_show_mythical_text(CombatData.PRINCE_MYTH_35[randi() % CombatData.PRINCE_MYTH_35.size()], Color(0.85, 0.3, 1.0))
		else:
			_show_mythical_text(CombatData.MYTH_40[randi() % CombatData.MYTH_40.size()], Color(0.8, 0.3, 0.3))
	elif s < 20 and not sanity_20_triggered:
		sanity_20_triggered = true
		if is_w3:
			_show_mythical_text(CombatData.MYTH_W3_20[randi() % CombatData.MYTH_W3_20.size()], Color(0.45, 0.05, 0.75))
		elif is_prince:
			_show_mythical_text(CombatData.PRINCE_MYTH_20[randi() % CombatData.PRINCE_MYTH_20.size()], Color(1.0, 0.7, 1.0))
		else:
			_show_mythical_text(CombatData.MYTH_20[randi() % CombatData.MYTH_20.size()], Color(1.0, 0.1, 0.1))

func _show_mythical_text(txt: String, col: Color) -> void:
	_trigger_screen_blink()
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("Glith_distorsion_noised_sound")

	var vp = get_viewport_rect().size
	# Aberracion cromatica: 3 copias con offset R/G/B
	var offsets = [Vector2(-3, 0), Vector2(3, 0), Vector2(0, 0)]
	var chroma_colors = [Color(1, 0, 0, 0.55), Color(0, 0.8, 1, 0.55), col]
	var main_lbl: Label = null

	for ci in range(3):
		var lbl = Label.new()
		lbl.text = txt
		lbl.add_theme_font_size_override("font_size", 48)
		lbl.modulate = chroma_colors[ci]; lbl.modulate.a = 0.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(vp.x, 200)
		lbl.position = Vector2(offsets[ci].x, vp.y / 2 - 100)
		lbl.z_index = 150
		add_child(lbl)
		var tw = create_tween()
		tw.tween_property(lbl, "modulate:a", 1.0, 0.4)
		tw.tween_interval(1.8)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
		tw.tween_callback(lbl.queue_free)
		if ci == 2: main_lbl = lbl

	# Shake solo en el label principal
	if main_lbl:
		var stw = create_tween().set_loops(15)
		stw.tween_property(main_lbl, "position", main_lbl.position + Vector2(randf_range(-10, 10), 0), 0.05)
		stw.tween_property(main_lbl, "position", Vector2(0, vp.y / 2 - 100), 0.05)

func _start_eye_blink_loop() -> void:
	while true:
		if not is_instance_valid(eye_node) or combat_ended: break
		var wait = randf_range(2.0, 6.0)
		if GameManager.sanity < 30: wait = randf_range(0.5, 2.5)
		await get_tree().create_timer(wait).timeout
		if not is_instance_valid(eye_node): break
		var top = eye_node.get_node("LidTop")
		var bot = eye_node.get_node("LidBot")
		# Cierre rapido con BACK easing (golpe organico)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(top, "position:y", -80, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(bot, "position:y", -10, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		await tw.finished
		if get_node_or_null("/root/AudioManager") and randf() < 0.6:
			AudioManager.play("eye_blink")   # Sonido orgánico al cerrar
		await get_tree().create_timer(0.06).timeout
		# Apertura suave con QUAD easing
		var tw2 = create_tween().set_parallel(true)
		tw2.tween_property(top, "position:y", -180, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_property(bot, "position:y", 90, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_4th_wall_stare() -> void:
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("eye_exhale")   # Suspiro profundo al fijar mirada
	# Zoom lento hacia el jugador
	var tw = eye_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(eye_node, "scale", eye_node.scale * 1.35, 2.5)
	# Latido rojo: pulso del ojo 3 veces
	var pulse = create_tween().set_loops(3)
	pulse.tween_property(eye_node, "modulate", Color(1.4, 0.3, 0.2, eye_node.modulate.a), 0.4)
	pulse.tween_property(eye_node, "modulate", Color(1.0, 1.0, 1.0, eye_node.modulate.a), 0.6)

var _is_ending: bool = false

var is_sanity_loop_active: bool = false
var _heartbeat_loop_active: bool = false
var _whisper_loop_active: bool = false

const HEARTBEAT_SOUND = "ES_Human, Heartbeat, Cinematic, 58 BPM - Epidemic Sound"
const WHISPER_SOUND    = "ES_Creatures, Ethereal, Ghosts, Whispers, Nightmare 02 - Epidemic Sound"

func _sync_dynamic_audio() -> void:
	if not get_node_or_null("/root/AudioManager"): return

	# 1. Lógica para Hastur (Prioridad máxima)
	if GameManager.is_hastur_fight and not enemies.is_empty():
		var h = enemies[0]
		var hp_perc = float(h.hp) / float(h.max_hp)
		var intensity = 1.0 - hp_perc
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", -5.0 + (intensity * 7.0), 1.0 + (intensity * 0.6))
		return

	# 2. Lógica de Cordura Normal — audio reactivo proporcional (umbral 60)
	var s = GameManager.sanity
	if s < 60:
		if not is_sanity_loop_active:
			is_sanity_loop_active = true
			AudioManager.play_loop("Glith_distorsion_noised_sound")
		# Volumen e intensidad progresivos: silencioso a 60, maximo a 0
		var vol_db = lerp(-28.0, -6.0, clamp((60.0 - s) / 60.0, 0.0, 1.0))
		var pitch: float
		if GameManager.selected_character == "prince":
			pitch = lerp(0.82, 0.50, clamp((60.0 - s) / 60.0, 0.0, 1.0))  # Baja → profundo/resonante
		else:
			pitch = lerp(0.82, 1.08, clamp((60.0 - s) / 60.0, 0.0, 1.0))  # Sube → caótico/aterrador
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", vol_db, pitch)
	else:
		if is_sanity_loop_active:
			is_sanity_loop_active = false
			AudioManager.stop_loop("Glith_distorsion_noised_sound")

	# Susurros tenebrosos: cordura < 40
	if s < 40:
		if not _whisper_loop_active:
			_whisper_loop_active = true
			AudioManager.play_loop(WHISPER_SOUND)
			AudioManager.update_loop_params(WHISPER_SOUND, -22.0, 1.0)
		# Volumen sube progresivamente: -22dB a -10dB
		var wh_vol = lerp(-22.0, -10.0, clamp((40.0 - s) / 40.0, 0.0, 1.0))
		AudioManager.update_loop_params(WHISPER_SOUND, wh_vol, 1.0)
	else:
		if _whisper_loop_active:
			_whisper_loop_active = false
			AudioManager.stop_loop(WHISPER_SOUND)

	# Heartbeat ambiental en cordura extrema — pitch acelera con la locura
	if s < 25:
		if not _heartbeat_loop_active:
			_heartbeat_loop_active = true
			AudioManager.play_loop(HEARTBEAT_SOUND)
			AudioManager.update_loop_params(HEARTBEAT_SOUND, -18.0, 1.0)
		# Volumen: -18dB → -8dB | Pitch: 1.0 (58BPM) → 1.5 (87BPM) según locura
		var t = clamp((25.0 - s) / 25.0, 0.0, 1.0)
		var hb_vol = lerp(-18.0, -8.0, t)
		var hb_pitch: float
		if GameManager.selected_character == "prince":
			hb_pitch = 1.0   # Constante — calma del que ha aceptado el vacío
		else:
			hb_pitch = lerp(1.0, 1.5, t)  # Acelerante — pánico creciente
		AudioManager.update_loop_params(HEARTBEAT_SOUND, hb_vol, hb_pitch)
	else:
		if _heartbeat_loop_active:
			_heartbeat_loop_active = false
			AudioManager.stop_loop(HEARTBEAT_SOUND)

# ── Fin de combate ─────────────────────────────────────────────────────────────
func check_combat_end() -> void:
	if combat_ended or _is_ending:
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
		AudioManager.stop_loop("ES_The End Of All Things - Niklas Johansson")
		AudioManager.stop_loop(HEARTBEAT_SOUND)
		AudioManager.stop_loop(WHISPER_SOUND)
	_heartbeat_loop_active = false
	_whisper_loop_active   = false
	
	# Recuperación de Cordura al Ganar (Reducida por balance)
	GameManager.sanity = min(100, GameManager.sanity + 5)
	
	GameManager.player_hp = player_hp
	
	if (GameManager.is_elite_fight or GameManager.is_boss_fight) and GameManager.has_relic("caliz_olvido"):
		GameManager.player_max_energy += 1
		DialogueUI.toast("Cáliz de Olvido: +1 Energía Máxima.")
		_flash_relic("caliz_olvido")

	GameManager.combat_count += 1
	GameManager.lore_progress += 1
	DialogueUI.toast("📖 CONOCIMIENTO ADQUIRIDO (+1 Lore)", Color(0.4, 0.9, 1.0))
	
	if get_node_or_null("/root/AudioManager"): AudioManager.play("victory")
	
	var victory_phrases: Array
	if GameManager.current_world == 2:
		victory_phrases = CombatData.VICTORY_PHRASES_W3
	else:
		victory_phrases = CombatData.VICTORY_PHRASES
	DialogueUI.cinematic(victory_phrases[randi() % victory_phrases.size()], Color(0.85, 0.7, 0.2))
	await DialogueUI.cinematic_finished

	if GameManager.is_hastur_fight:
		# Final secreto — Hastur derrotado: victoria real
		GameManager.player_won = true
		_show_victory_cinematic(true)
		GameManager.go_to_scene("res://scenes/ui/GameOver.tscn")
	elif GameManager.is_final_boss:
		if GameManager.current_world == 2:
			# TESTIGO PRIMORDIAL caído → Victoria W3
			var victory_msg = "EL TESTIGO HA CERRADO SUS OJOS. CARCOSA TE LLAMA." if GameManager.selected_character == "prince" else "EL TESTIGO HA CERRADO SUS OJOS"
			DialogueUI.cinematic(victory_msg, Color(0.8, 0.3, 1.0))
			await get_tree().create_timer(2.0).timeout

			if GameManager.has_all_secret_items():
				# Los 3 fragmentos responden — La Puerta se abre
				DialogueUI.cinematic("LA PUERTA SE ABRE.", Color(0.95, 0.85, 0.1))
				await get_tree().create_timer(1.5).timeout
				DialogueUI.cinematic("EL REY TE ESPERA.", Color(0.95, 0.85, 0.1))
				await get_tree().create_timer(1.5).timeout
				await _show_carcosa_transition()
				GameManager.is_hastur_fight = true
				GameManager.is_final_boss = false
				GameManager.go_to_scene("res://scenes/combat/Combat.tscn")
			else:
				GameManager.player_won = true
				await _show_victory_cinematic(false)
				GameManager.go_to_scene("res://scenes/ui/GameOver.tscn")
		elif GameManager.current_world == 0:
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
			# REY AMARILLO caído → siempre va a W3
			DialogueUI.cinematic("LA GRIETA SE EXPANDE. EL UMBRAL TE LLAMA.", Color(0.6, 0.1, 0.9))
			await get_tree().create_timer(2.0).timeout
			GameManager.current_world = 2
			GameManager.is_final_boss = false
			GameManager.map_graph = []
			GameManager.map_path = {}
			GameManager.current_map_floor = 0
			GameManager.current_map_col = -1
			GameManager.player_hp = GameManager.player_max_hp
			GameManager.sanity = 100
			if GameManager.selected_character == "prince":
				GameManager.sanity = 20
			GameManager.go_to_scene("res://scenes/ui/Map.tscn")
	elif GameManager.is_mimic_chest:
		# Mímico vencido → 2 reliquias como recompensa
		GameManager.is_mimic_chest = false
		_show_relic_reward("__mimic_segunda__")
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
	ui.clear_cursed_card()
	destilado_rey_amarillo = false
	destilado_resonancia_zero = false
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
			DialogueUI.cinematic("Fragmentos: 3/3 — Hastur activado", Color(0.7, 0.3, 0.9))],
		["+ Reliquia: Traductor", func():
			GameManager.add_relic("lengua_tablero")
			DialogueUI.toast("Reliquia obtenida: Lengua del Tablero")
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
		["MÍMICO (Cofre)", func():
			GameManager.is_mimic_chest = true
			GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")],
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

func _show_death_dialogue(enemy_name: String) -> void:
	cinematics.show_death_dialogue(enemy_name)

func _show_floating_dialogue(text: String, col: Color, pos: Vector2, _is_cipher: bool = false) -> void:
	DialogueUI.bark(text, pos, col, false, 260.0, "player")

# ── Reliquias ──────────────────────────────────────────────────────────────────

func _show_player_passive_tooltip() -> void:
	if get_node_or_null("PassiveTooltipPanel"): return  # ya visible
	var char_id = GameManager.selected_character
	var char_name = char_id.to_upper()
	var passive_txt = CombatData.PASSIVE_DESCRIPTIONS.get(char_id, "Sin descripción.")

	const CHAR_PASSIVE_COLORS = {
		"prince":    Color(0.65, 0.3, 0.95),
		"estratega": Color(0.4, 0.8, 1.0),
		"guardian":  Color(0.4, 0.85, 0.55),
		"mahar":     Color(0.95, 0.65, 0.25),
	}
	var tip_color = CHAR_PASSIVE_COLORS.get(char_id, Color(0.8, 0.8, 0.8))

	var txt = "[ HABILIDAD PASIVA ]\n" + char_name + "\n\n" + passive_txt

	var panel_w = 280
	var line_count = txt.count("\n") + (txt.length() / 35) + 2
	var panel_h = line_count * 18 + 30

	# Posición: justo a la derecha del player_panel en coordenadas de escena
	var pp_global = ui.player_panel.global_position
	var panel_pos = Vector2(pp_global.x + ui.player_panel.size.x + 8, pp_global.y)

	var p = ui._make_panel(panel_pos, Vector2(panel_w, panel_h), Color(0, 0, 0, 0.95), tip_color)
	p.name = "PassiveTooltipPanel"
	p.z_index = 200
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE  # No bloquear eventos del padre

	var tip = Label.new()
	tip.text = txt
	tip.add_theme_font_size_override("font_size", 12)
	tip.modulate = tip_color
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.position = Vector2(12, 12); tip.size = Vector2(panel_w - 24, panel_h - 24)
	p.add_child(tip)
	add_child(p)  # Al nodo raíz Combat, no a player_sprite_label

func _hide_player_passive_tooltip() -> void:
	var p = get_node_or_null("PassiveTooltipPanel")
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


# ── Destilados ─────────────────────────────────────────────────────────────────
func _on_destilado_clicked(dest_id: String) -> void:
	if not is_player_turn or combat_ended:
		return
	var data = GameManager.DESTILADO_DATA.get(dest_id, {})
	match data.get("target", "auto"):
		"auto", "all_enemies":
			_apply_destilado(dest_id)
		"enemy":
			targeting_destilado = dest_id
			targeting_active = true
			_destilado_targeting_origin = Vector2(665, 302)
			targeting_arrow.visible = true
		"card":
			targeting_destilado_card = dest_id
			_highlight_hand_for_destilado()

func _highlight_hand_for_destilado() -> void:
	for card in hand_container.get_children():
		if not card.is_queued_for_deletion():
			card.set_disabled(false)
			card.modulate = Color(1.1, 0.9, 0.4)

func _clear_destilado_card_highlight() -> void:
	targeting_destilado_card = ""
	for card in hand_container.get_children():
		if not card.is_queued_for_deletion():
			card.modulate = Color(1.0, 1.0, 1.0)
	update_card_states()

func _apply_destilado(dest_id: String, target_enemy_idx: int = -1, target_card = null) -> void:
	GameManager.remove_destilado(dest_id)
	var d_name = GameManager.DESTILADO_DATA.get(dest_id, {}).get("name", dest_id)
	DialogueUI.add_log("DESTILADO", d_name, Color(0.7, 0.5, 0.9))

	match dest_id:
		"sangre_ejecutor":
			destilado_next_atk_mult = 1.5
			DialogueUI.toast("Sangre del Ejecutor: +50% al próximo ataque.", Color(0.9, 0.3, 0.3))

		"recuerdo_robado":
			await draw_hand(3)
			if not hand.is_empty():
				var idx = randi() % hand.size()
				var lost = hand[idx]
				hand.remove_at(idx)
				discard_pile.append(lost)
				var nodes = hand_container.get_children()
				if idx < nodes.size(): nodes[idx].queue_free()
				reorganize_hand()
				DialogueUI.toast("Recuerdo Robado: +3 cartas. Descartada: " + lost.get("name", "?"), Color(0.5, 0.6, 0.9))

		"polvo_dama_ceniza":
			for e in enemies:
				if e.hp > 0:
					e["bleed"] = e.get("bleed", 0) + 3
			GameManager.sanity = max(0, GameManager.sanity - 5)
			DialogueUI.toast("Polvo de la Dama: Sangrado ×3 a todos. -5 Cordura.", Color(0.8, 0.2, 0.3))
			update_ui()

		"bruma_rey_caido":
			for e in enemies:
				if e.hp > 0:
					var dmg = 15
					var abs_val = min(e.shield, dmg)
					if abs_val > 0: e.shield -= abs_val; dmg -= abs_val
					if dmg > 0:
						e.hp = max(0, e.hp - dmg)
						_spawn_damage_number(e.panel.global_position + Vector2(100, 60), dmg, Color(0.4, 0.7, 0.9))
						_animate_enemy_hit(e)
						if e.hp <= 0: await _kill_enemy(e)
			GameManager.sanity = max(0, GameManager.sanity - 10)
			DialogueUI.toast("Bruma del Rey Caído: 15 daño a todos. -10 Cordura.", Color(0.4, 0.7, 0.9))
			update_ui()

		"chispa_efimera":
			player_energy = min(player_max_energy, player_energy + 2)
			destilado_chispa_debt = 1
			DialogueUI.toast("Chispa Efímera: +2 Energía. El tablero cobrará el próximo turno.", Color(0.9, 0.8, 0.3))
			update_ui()

		"susurro_abismo":
			if target_enemy_idx >= 0 and target_enemy_idx < enemies.size():
				var e = enemies[target_enemy_idx]
				var debuff = int(e.get("attack", e.hp) * 0.3)
				e["atk_reduction"] = e.get("atk_reduction", 0) + debuff
				e["locura_turns"] = 2
				GameManager.sanity = max(0, GameManager.sanity - 10)
				DialogueUI.toast("Susurro del Abismo: Locura en " + e.name + ". -10 Cordura.", Color(0.6, 0.2, 0.9))
				update_ui()

		"olvido_puro":
			if target_card != null:
				var c_name = target_card.card_name if target_card.get("card_name") != null else ""
				for i in range(hand.size()):
					if hand[i].get("name", "") == c_name:
						hand.remove_at(i); break
				for i in range(GameManager.player_deck.size()):
					if GameManager.player_deck[i].get("name", "") == c_name:
						GameManager.player_deck.remove_at(i); break
				target_card.queue_free()
				reorganize_hand()
				GameManager.coins += 10
				DialogueUI.toast("Olvido Puro: '" + c_name + "' olvidada. +10 oro.", Color(0.7, 0.7, 0.5))
				update_ui()

		"lucidez_prestada":
			GameManager.sanity = min(GameManager.max_sanity, GameManager.sanity + 35)
			var deuda = {"name": "Deuda de Cordura", "attack": 0, "defense": 0, "cost": 0,
				"curse": true, "sanity_cost": 15, "innate": true, "exhaust": true}
			GameManager.player_deck.append(deuda)
			DialogueUI.toast("Lucidez Prestada: +35 Cordura. El vacío anota tu deuda.", Color(0.5, 0.3, 0.8))
			update_ui()

		"tinta_sacrificio":
			if target_card != null:
				var atk_val = target_card.card_data.get("attack", 0) if target_card.get("card_data") != null else 0
				var c_name = target_card.card_name if target_card.get("card_name") != null else ""
				for i in range(hand.size()):
					if hand[i].get("name", "") == c_name:
						hand.remove_at(i); break
				target_card.queue_free()
				reorganize_hand()
				for e in enemies:
					if e.hp > 0 and atk_val > 0:
						var dmg = atk_val
						var abs_val = min(e.shield, dmg)
						if abs_val > 0: e.shield -= abs_val; dmg -= abs_val
						if dmg > 0:
							e.hp = max(0, e.hp - dmg)
							_spawn_damage_number(e.panel.global_position + Vector2(100, 60), dmg, Color(0.9, 0.4, 0.2))
							_animate_enemy_hit(e)
							if e.hp <= 0: await _kill_enemy(e)
				DialogueUI.toast("Tinta del Sacrificio: " + str(atk_val) + " daño a todos. '" + c_name + "' consumida.", Color(0.9, 0.4, 0.2))
				update_ui()

		"resonancia_cero":
			destilado_resonancia_zero = true
			for card in hand_container.get_children():
				if not card.is_queued_for_deletion():
					card.set_cost_modifier(-card.get_effective_cost())
			DialogueUI.toast("Resonancia de Coste Cero: todas las cartas cuestan 0 este turno.", Color(0.3, 0.9, 0.7))
			update_card_states()

		"fragmento_principe":
			GameManager.sanity = max(0, GameManager.sanity - 25)
			destilado_dmg_mult = 1.3
			destilado_dmg_turns = 3
			DialogueUI.toast("Fragmento del Príncipe: -25 Cordura. +30% daño por 3 turnos.", Color(0.7, 0.2, 0.9))
			update_ui()

		"conocimiento_prohibido":
			for e in enemies:
				e["intent_visible"] = true
			update_intent_labels()
			GameManager.relic_fragments += 1
			if GameManager.relic_fragments >= 3:
				GameManager.relic_fragments = 0
				var available = GameManager.RELIC_DATA.keys().filter(
					func(r): return not GameManager.has_relic(r))
				if not available.is_empty():
					var r_id = available[randi() % available.size()]
					GameManager.add_relic(r_id)
					_populate_relics()
					DialogueUI.toast("¡3 Fragmentos! Reliquia: " + GameManager.RELIC_DATA[r_id]["name"], Color(0.9, 0.8, 0.2))
			else:
				DialogueUI.toast("Conocimiento Prohibido: patrones revelados. Fragmento %d/3." % GameManager.relic_fragments, Color(0.5, 0.3, 0.8))
			GameManager.sanity = max(0, GameManager.sanity - 20)
			GameManager.max_sanity = max(20, GameManager.max_sanity - 5)
			GameManager.sanity = min(GameManager.sanity, GameManager.max_sanity)
			update_ui()

		"sangre_rey_amarillo":
			player_energy = min(player_max_energy + 3, player_energy + 3)
			destilado_rey_amarillo = true
			GameManager.player_max_hp = max(10, GameManager.player_max_hp - 20)
			player_max_hp = GameManager.player_max_hp
			player_hp = min(player_hp, player_max_hp)
			GameManager.player_hp = player_hp
			GameManager.sanity = max(0, GameManager.sanity - 15)
			DialogueUI.toast("¡SANGRE DEL REY AMARILLO! Daño ×2. -20 HP máx, -15 Cordura.", Color(1.0, 0.85, 0.1))
			_trigger_screen_blink()
			update_ui()

		"ultimo_vial":
			player_hp = player_max_hp
			GameManager.player_hp = player_hp
			GameManager.sanity = GameManager.max_sanity
			GameManager.destilados_blocked = true
			DialogueUI.toast("El Último Vial: curación total. Los Destilados se han sellado para siempre.", Color(0.6, 0.9, 0.6))
			update_ui()

		"eco_grieta":
			await _apply_eco_grieta()

	ui.populate_destilados(_on_destilado_clicked)
	update_ui()

func _apply_eco_grieta() -> void:
	var outcomes: Array[Callable] = [
		func():
			player_hp = min(player_max_hp, player_hp + 30)
			update_ui()
			DialogueUI.toast("Eco de la Grieta: +30 HP.", Color(0.4, 1.0, 0.5)),
		func():
			await draw_hand(2)
			DialogueUI.toast("Eco de la Grieta: +2 cartas.", Color(0.5, 0.7, 0.9)),
		func():
			GameManager.coins += 30
			update_ui()
			DialogueUI.toast("Eco de la Grieta: +30 oro.", Color(0.9, 0.8, 0.2)),
		func():
			player_hp = max(1, player_hp - 15)
			update_ui()
			DialogueUI.toast("Eco de la Grieta: -15 HP.", Color(1.0, 0.3, 0.3))
			_trigger_screen_blink(),
		func():
			GameManager.sanity = max(0, GameManager.sanity - 20)
			update_ui()
			DialogueUI.toast("Eco de la Grieta: -20 Cordura.", Color(0.6, 0.2, 0.9)),
		func():
			if not hand.is_empty():
				var best_idx = 0
				for i in range(hand.size()):
					if hand[i].get("attack", 0) + hand[i].get("defense", 0) > \
							hand[best_idx].get("attack", 0) + hand[best_idx].get("defense", 0):
						best_idx = i
				var lost = hand[best_idx]
				hand.remove_at(best_idx)
				var nodes = hand_container.get_children()
				if best_idx < nodes.size(): nodes[best_idx].queue_free()
				reorganize_hand()
				DialogueUI.toast("Eco de la Grieta: '" + lost.get("name", "carta") + "' consumida para siempre.", Color(0.5, 0.1, 0.6)),
	]
	await outcomes[randi() % outcomes.size()].call()

func _populate_relics() -> void:
	if not relics_container: return
	# Clear existing relic icons to prevent visual accumulation
	for child in relics_container.get_children():
		child.queue_free()
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
		AudioManager.stop_loop(HEARTBEAT_SOUND)
		AudioManager.stop_loop(WHISPER_SOUND)
		AudioManager.play("defeat")
	_heartbeat_loop_active = false
	_whisper_loop_active   = false
		
	await get_tree().create_timer(2.5).timeout
	GameManager.go_to_scene("res://scenes/ui/GameOver.tscn")
