extends Node

# Este script maneja toda la representación visual del combate
# para que Combat.gd se centre únicamente en la lógica del juego.

var main: Node2D # Referencia al script principal de Combat

# Referencias a nodos de UI (serán inicializados en build_ui)
var player_panel: Panel
var player_sprite_label: Label
var lbl_player_hp: RichTextLabel
var lbl_sanity: Label
var hp_bar_player: ProgressBar
var sanity_bar_player: ProgressBar
var lbl_energy: Label
var lbl_furia: Label
var hand_container: Control
var lbl_draw_pile: Label
var lbl_discard_pile: Label
var end_turn_btn: Button
var relics_container: HBoxContainer
var log_panel: Panel
var log_vbox: VBoxContainer
var lbl_message: Label
var panel_message: Panel
var vignette: ColorRect
var eye_node: Control
var blink_overlay: ColorRect
var targeting_arrow: Line2D
var targeting_arrow_head: Line2D

# --- Target highlight ---
var _target_highlight_style: Dictionary = {}   # panel -> StyleBoxFlat original
var _target_highlight_tween: Tween = null
var _currently_highlighted: Panel = null

# --- Energía visual (dots) ---
var energy_dots: Array = []

# --- Pulso de cordura crítica ---
var _sanity_pulse_tween: Tween = null
var _sanity_fill_style: StyleBoxFlat = null

# --- Estado de animación de barras de vida ---
var _bar_tweens: Dictionary = {}         # ProgressBar -> Tween activo
var _ghost_bar_tweens: Dictionary = {}   # ProgressBar -> Tween (drain)
var _ghost_bar_delays: Dictionary = {}   # ProgressBar -> Tween (delay timer)
var ghost_bar_player: ProgressBar = null
var shield_bar_player: ProgressBar
var _player_panel_style: StyleBoxFlat = null
var _low_hp_pulse_tween: Tween = null

func setup(p_main: Node2D) -> void:
	main = p_main

func build_ui(vp: Vector2) -> void:
	_build_dynamic_background(vp)

	# Crear panel del jugador e inmediatamente guardar referencia al StyleBox para el pulso de HP crítico
	var _pp_style = StyleBoxFlat.new()
	_pp_style.bg_color = Color(0.07, 0.05, 0.13)
	_pp_style.set_border_width_all(2)
	_pp_style.border_color = Color(0.45, 0.35, 0.65)
	_pp_style.set_corner_radius_all(4)
	player_panel = Panel.new()
	player_panel.position = Vector2(20, 280)
	player_panel.size = Vector2(560, 100)
	player_panel.add_theme_stylebox_override("panel", _pp_style)
	_player_panel_style = _pp_style
	main.add_child(player_panel)

	var char_id = GameManager.selected_character
	var char_info = CombatData.CHAR_DATA.get(char_id, {"symbol": "♟", "color": Color(0.8, 0.8, 0.8)})
	player_sprite_label = Label.new()
	player_sprite_label.text = char_info["symbol"]
	player_sprite_label.modulate = char_info["color"]
	player_sprite_label.add_theme_font_size_override("font_size", 44)
	player_sprite_label.position = Vector2(2, 0)
	player_sprite_label.size = Vector2(90, 100)
	player_sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_sprite_label.mouse_filter = Control.MOUSE_FILTER_STOP
	player_panel.add_child(player_sprite_label)

	player_sprite_label.mouse_entered.connect(main._show_player_passive_tooltip)
	player_sprite_label.mouse_exited.connect(main._hide_player_passive_tooltip)

	main._start_player_idle_bob()

	# Barra fantasma del jugador (debajo de la barra principal)
	ghost_bar_player = _make_ghost_bar(main.player_max_hp, 300, 7)
	ghost_bar_player.position = Vector2(100, 32)
	player_panel.add_child(ghost_bar_player)

	hp_bar_player = _make_hp_bar(main.player_max_hp, 300, 7); hp_bar_player.position = Vector2(100, 32); player_panel.add_child(hp_bar_player)

	shield_bar_player = _make_shield_bar(main.player_max_hp, 300, 7)
	shield_bar_player.position = Vector2(100, 32)
	player_panel.add_child(shield_bar_player)

	sanity_bar_player = _make_hp_bar(100, 300, 5); sanity_bar_player.position = Vector2(100, 43); player_panel.add_child(sanity_bar_player)
	var sb_style = StyleBoxFlat.new(); sb_style.bg_color = Color(0.04, 0.01, 0.1); sb_style.set_corner_radius_all(2)
	sb_style.set_content_margin_all(0)
	var sb_fill = StyleBoxFlat.new(); sb_fill.bg_color = Color(0.38, 0.1, 0.68)
	sb_fill.set_content_margin_all(0)
	sanity_bar_player.add_theme_stylebox_override("background", sb_style)
	sanity_bar_player.add_theme_stylebox_override("fill", sb_fill)
	_sanity_fill_style = sb_fill

	lbl_player_hp = RichTextLabel.new()
	lbl_player_hp.position = Vector2(100, 10)
	lbl_player_hp.size = Vector2(240, 24)
	lbl_player_hp.bbcode_enabled = true
	lbl_player_hp.fit_content = true
	lbl_player_hp.add_theme_font_size_override("font_size", 13)
	player_panel.add_child(lbl_player_hp)

	lbl_sanity = Label.new(); lbl_sanity.position = Vector2(350, 10); lbl_sanity.add_theme_font_size_override("font_size", 13); player_panel.add_child(lbl_sanity)

	var lbl_energy_title = Label.new()
	lbl_energy_title.text = "ENERGÍA"
	lbl_energy_title.position = Vector2(100, 50)
	lbl_energy_title.add_theme_font_size_override("font_size", 10)
	lbl_energy_title.modulate = Color(0.7, 0.6, 0.3)
	player_panel.add_child(lbl_energy_title)

	lbl_energy = Label.new(); lbl_energy.position = Vector2(100, 58); player_panel.add_child(lbl_energy)

	if char_id == "guardian":
		lbl_furia = Label.new()
		lbl_furia.position = Vector2(300, 58)
		lbl_furia.add_theme_font_size_override("font_size", 14)
		lbl_furia.modulate = Color(0.4, 0.9, 0.4)
		player_panel.add_child(lbl_furia)


	hand_container = Control.new()
	hand_container.position = Vector2(20, 418); hand_container.size = Vector2(1112, 195)
	main.add_child(hand_container)

	lbl_draw_pile    = _make_pile_label(Vector2(950, 540), Color(0.7, 0.7, 0.9))
	lbl_discard_pile = _make_pile_label(Vector2(950, 575), Color(0.6, 0.5, 0.4))
	main.add_child(lbl_draw_pile); main.add_child(lbl_discard_pile)

	end_turn_btn = Button.new(); end_turn_btn.text = "TERMINAR TURNO"
	end_turn_btn.position = Vector2(900, 480); end_turn_btn.size = Vector2(230, 50)
	end_turn_btn.pressed.connect(main._on_end_turn_button_pressed); main.add_child(end_turn_btn)

	# Panel de Mensajes Lore/Pensamientos
	panel_message = _make_panel(Vector2(100, 180), Vector2(952, 200), Color(0, 0, 0, 0.9), Color(0.3, 0.25, 0.1))
	panel_message.z_index = 10
	panel_message.visible = false
	main.add_child(panel_message)

	lbl_message = Label.new()
	lbl_message.position = Vector2(20, 20)
	lbl_message.size = Vector2(912, 160)
	lbl_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_message.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel_message.add_child(lbl_message)

	# Paneles enemigos
	for i in range(main.enemies.size()):
		var is_peaceful = main.enemies[i].peaceful
		var border_col = Color(0.2, 0.5, 0.2) if is_peaceful else Color(0.6, 0.2, 0.2)
		var bg_col     = Color(0.04, 0.1, 0.04) if is_peaceful else Color(0.1, 0.05, 0.05)
		var ep = _make_panel(Vector2(650 + i*220, 80), Vector2(200, 270), bg_col, border_col)
		ep.mouse_filter = Control.MOUSE_FILTER_PASS
		main.add_child(ep); main.enemies[i].panel = ep

		# Conectar señales para Tooltips de Intencion
		var idx = i
		ep.mouse_entered.connect(func(): main._show_enemy_intent_tooltip(idx))
		ep.mouse_exited.connect(func(): main._hide_enemy_intent_tooltip(idx))

		var en = Label.new(); en.text = main.enemies[i].name
		en.position = Vector2(0, 8); en.size = Vector2(200, 30)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en.add_theme_font_size_override("font_size", 11)
		en.modulate = Color(0.5, 1.0, 0.5) if is_peaceful else Color.WHITE
		ep.add_child(en); main.enemies[i].lbl_name = en

		var esl = load("res://scripts/EnemySprite.gd").new() # Debemos cargarlo
		esl.position = Vector2(0, 38)
		esl.size = Vector2(200, 130)
		esl.setup(main.enemies[i].name)
		ep.add_child(esl); main.enemies[i].sprite_label = esl

		var elh = Label.new(); elh.position = Vector2(10, 175); elh.size = Vector2(180, 20); ep.add_child(elh); main.enemies[i].lbl_hp = elh
		var ebl = Label.new(); ebl.position = Vector2(10, 195); ebl.size = Vector2(180, 20)
		ebl.modulate = Color(0.4, 0.7, 1.0); ep.add_child(ebl); main.enemies[i].lbl_shield = ebl

		# Barra fantasma del enemigo (debajo de la barra principal)
		var eg = _make_ghost_bar(main.enemies[i].max_hp, 160, 4)
		eg.position = Vector2(18, 198)
		ep.add_child(eg)
		main.enemies[i].ghost_bar = eg

		var eh = _make_hp_bar(main.enemies[i].max_hp, 160, 4)
		eh.position = Vector2(18, 198)
		ep.add_child(eh)
		main.enemies[i].hp_bar = eh

		var esh = _make_shield_bar(main.enemies[i].max_hp, 160, 4)
		esh.position = Vector2(18, 198)
		ep.add_child(esh)
		main.enemies[i].shield_bar = esh

		# lbl_status se añade DESPUÉS de las barras para quedar encima en z-order
		var est = Label.new()
		est.position = Vector2(10, 212)
		est.size = Vector2(180, 14)
		est.add_theme_font_size_override("font_size", 12)
		est.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ep.add_child(est)
		main.enemies[i].lbl_status = est
		var idx3 = i
		est.mouse_filter = Control.MOUSE_FILTER_PASS
		est.mouse_entered.connect(func(): main._show_enemy_intent_tooltip(idx3))
		est.mouse_exited.connect(func(): main._hide_enemy_intent_tooltip(idx3))

		var intent_badge = Panel.new()
		intent_badge.position = Vector2(10, 244)
		intent_badge.size = Vector2(180, 26)
		var ib_style = StyleBoxFlat.new()
		ib_style.bg_color = Color(0.3, 0.1, 0.1, 0.0)
		ib_style.set_corner_radius_all(4)
		intent_badge.add_theme_stylebox_override("panel", ib_style)
		ep.add_child(intent_badge)
		main.enemies[i].intent_badge = intent_badge
		main.enemies[i].intent_badge_style = ib_style

		var lin = Label.new(); lin.position = Vector2(10, 246); lin.size = Vector2(180, 22)
		lin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lin.add_theme_font_size_override("font_size", 13)
		ep.add_child(lin); main.enemies[i].lbl_intent_icon = lin

	targeting_arrow = Line2D.new(); targeting_arrow.width = 4
	targeting_arrow.default_color = Color(1, 0.8, 0.2); targeting_arrow.visible = false; main.add_child(targeting_arrow)

	targeting_arrow_head = Line2D.new()
	targeting_arrow_head.width = 8
	targeting_arrow_head.default_color = Color(1.0, 0.9, 0.3)
	targeting_arrow_head.visible = false
	targeting_arrow_head.z_index = 5
	main.add_child(targeting_arrow_head)

	relics_container = HBoxContainer.new()
	relics_container.position = Vector2(10, 10)
	relics_container.add_theme_constant_override("separation", 6)
	main.add_child(relics_container)
	main._populate_relics()

	# --- HISTORIAL DE COMBATE (Log) ---
	log_panel = Panel.new()
	log_panel.position = Vector2(10, 55)
	log_panel.size = Vector2(300, 120)
	log_panel.modulate.a = 0.25 # Casi transparente por defecto
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(log_panel)

	var ls = StyleBoxFlat.new()
	ls.bg_color = Color(0, 0, 0, 0.7); ls.border_width_left = 2; ls.border_color = Color(0.3, 0.3, 0.3)
	log_panel.add_theme_stylebox_override("panel", ls)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 5)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(scroll)

	log_vbox = VBoxContainer.new()
	log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_vbox)

	# Hover logic para el Log
	log_panel.mouse_entered.connect(func(): main.create_tween().tween_property(log_panel, "modulate:a", 1.0, 0.2))
	log_panel.mouse_exited.connect(func(): main.create_tween().tween_property(log_panel, "modulate:a", 0.25, 0.3))

	# Viñeta de Cordura
	vignette = ColorRect.new()
	vignette.size = vp
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0, 0, 0, 0) # Empieza invisible
	vignette.z_index = 40 # Encima de todo menos mensajes criticos
	main.add_child(vignette)

	blink_overlay = ColorRect.new()
	blink_overlay.size = vp
	blink_overlay.color = Color.BLACK
	blink_overlay.visible = false
	blink_overlay.z_index = 60 # El parpadeo tapa todo
	main.add_child(blink_overlay)

	var dev_toggle = Button.new(); dev_toggle.text = "[DEV]"
	dev_toggle.position = Vector2(vp.x - 80, vp.y - 36); dev_toggle.size = Vector2(75, 30)
	dev_toggle.modulate = Color(0.5, 0.5, 0.5, 0.45)
	main.add_child(dev_toggle)

	# Botón Visor de Mazo
	var deck_btn = Button.new()
	deck_btn.text = " ▣ VER MAZO "
	deck_btn.position = Vector2(vp.x - 160, 10); deck_btn.size = Vector2(150, 40)
	deck_btn.add_theme_font_size_override("font_size", 14)
	main.add_child(deck_btn)
	deck_btn.pressed.connect(func(): GameManager.show_deck_overlay(main))

	var dev_panel = main._build_dev_panel(vp)
	dev_panel.visible = false
	main.add_child(dev_panel)
	dev_toggle.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)

func _build_dynamic_background(vp: Vector2) -> void:
	var is_w2 = GameManager.current_world == 1
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02) if not is_w2 else Color(0.04, 0.03, 0.01)
	bg.size = vp; bg.z_index = -10; main.add_child(bg)
	var sz = 450.0 if not is_w2 else 650.0
	var sun = Panel.new(); sun.size = Vector2(sz, sz); sun.position = Vector2(vp.x/2 - sz/2, -100)
	var sun_st = StyleBoxFlat.new(); sun_st.bg_color = Color(0,0,0)
	sun_st.set_corner_radius_all(sz/2); sun_st.border_width_left = 4
	sun_st.border_color = Color(0.9, 0.6, 0.1, 0.3)
	sun.add_theme_stylebox_override("panel", sun_st); sun.z_index = -9; main.add_child(sun)

	# El Ojo del Vacio (REDISEÑO GIGANTE)
	eye_node = Control.new()
	eye_node.position = sun.position + sun.size/2
	eye_node.z_index = -8; eye_node.modulate.a = 0.0
	main.add_child(eye_node)

	var eye_w = 320.0
	var eye_h = 160.0

	var eye_bg = Panel.new() # Esclerotica (Almendra simetrica)
	eye_bg.size = Vector2(eye_w, eye_h); eye_bg.position = -eye_bg.size/2
	var es = StyleBoxFlat.new(); es.bg_color = Color(0.85, 0.8, 0.6)
	es.set_corner_radius_all(160) # Simplificado para evitar constantes no definidas
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

	main._start_eye_blink_loop()
	# Lluvia de fondo
	var is_avatar = not main.enemies.is_empty() and "AVATAR" in main.enemies[0].name.to_upper()

	var rain_color = Color(0.8, 0.1, 0.1, 0.35) if is_avatar else Color(0.5, 0.5, 0.75, 0.12)
	var gpu_rain = GPUParticles2D.new()
	gpu_rain.position = Vector2(vp.x * 0.5, -5.0)
	gpu_rain.z_index = -8
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(vp.x * 0.5, 1.0, 0.0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 0.0
	mat.initial_velocity_min = 600.0
	mat.initial_velocity_max = 950.0
	mat.gravity = Vector3.ZERO
	mat.color = rain_color
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	gpu_rain.process_material = mat
	gpu_rain.amount = 60
	gpu_rain.lifetime = vp.y / 750.0
	gpu_rain.one_shot = false
	gpu_rain.emitting = true
	main.add_child(gpu_rain)

func update_ui() -> void:
	var hp_text = "SALUD: %d / %d" % [main.player_hp, main.player_max_hp]
	if main.player_shield > 0:
		hp_text += " [color=#66ccff](+%d ESCUDO)[/color]" % main.player_shield

	lbl_player_hp.text = hp_text

	# Animación de la barra de vida del jugador
	hp_bar_player.max_value = main.player_max_hp
	var player_ratio = float(main.player_hp) / float(main.player_max_hp)
	var old_player_val = hp_bar_player.value
	var heal_player = main.player_hp > old_player_val
	_set_bar_color(hp_bar_player, player_ratio)
	var player_duration = 0.5 if heal_player else 0.3
	_animate_bar_to(hp_bar_player, main.player_hp, player_duration)
	_update_ghost_bar(ghost_bar_player, main.player_hp)
	shield_bar_player.max_value = main.player_max_hp
	shield_bar_player.value = main.player_shield
	if heal_player:
		_flash_heal(hp_bar_player, player_ratio)

	# Pulso crítico de HP
	if player_ratio < 0.25:
		_start_low_hp_pulse()
	else:
		_stop_low_hp_pulse()

	sanity_bar_player.max_value = GameManager.max_sanity
	_animate_bar_to(sanity_bar_player, GameManager.sanity, 0.3)

	var sanity_label = GameManager.get_sanity_label()
	lbl_sanity.text = "%s: %d / %d" % [sanity_label, GameManager.sanity, GameManager.max_sanity]
	if GameManager.sanity < 40:
		lbl_sanity.modulate = Color(0.8, 0.4, 1.0) # Morado brillante para Locura
	else:
		lbl_sanity.modulate = Color(0.6, 0.5, 0.8)

	if GameManager.sanity < 30:
		_start_sanity_pulse()
	else:
		_stop_sanity_pulse()

	_update_energy_dots(main.player_energy, main.player_max_energy)
	lbl_energy.text = ""
	if GameManager.mark_level > 0: lbl_energy.text = "(Signo Lv%d)" % GameManager.mark_level

	if lbl_furia:
		lbl_furia.text = "FURIA: +%d DAÑO" % main.furia_points
		lbl_furia.visible = main.furia_points > 0

	lbl_draw_pile.text    = "MAZO: %d" % main.draw_pile.size()
	lbl_discard_pile.text = "DESC: %d" % main.discard_pile.size()

	for i in range(main.enemies.size()):
		var e = main.enemies[i]
		if not e.panel: continue

		if e.hp <= 0:
			e.panel.visible = false
			continue

		e.lbl_hp.text = "HP: %d / %d" % [e.hp, e.max_hp]
		e.hp_bar.max_value = e.max_hp
		var enemy_ratio = float(e.hp) / float(e.max_hp)
		var old_enemy_val = e.hp_bar.value
		var heal_enemy = e.hp > old_enemy_val
		_set_bar_color(e.hp_bar, enemy_ratio)
		var enemy_duration = 0.5 if heal_enemy else 0.3
		_animate_bar_to(e.hp_bar, e.hp, enemy_duration)
		if e.get("ghost_bar"):
			_update_ghost_bar(e.ghost_bar, e.hp)

		if e.get("shield_bar"):
			e.shield_bar.max_value = e.max_hp
			e.shield_bar.value = e.shield
		if e.shield > 0:
			e.lbl_shield.text = "ESCUDO: %d" % e.shield
			e.lbl_shield.visible = true
		else:
			e.lbl_shield.visible = false

		# Estados activos del enemigo
		var status_parts = []
		if e.get("bleed", 0) > 0:
			status_parts.append("🩸%d" % e["bleed"])
		if e.get("atk_reduction", 0) > 0:
			status_parts.append("⚡-%d" % e["atk_reduction"])
		if e.get("is_stunned", false):
			status_parts.append("💫")
		if e.get("lbl_status"):
			e.lbl_status.text = "  ".join(status_parts)
			e.lbl_status.visible = not status_parts.is_empty()

# --- Funciones de animación de barras ---

func _animate_bar_to(bar: ProgressBar, target: float, duration: float = 0.35) -> void:
	if _bar_tweens.has(bar) and _bar_tweens[bar] != null:
		_bar_tweens[bar].kill()
	var tw = main.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar, "value", target, duration)
	_bar_tweens[bar] = tw

func _update_ghost_bar(ghost: ProgressBar, target: float) -> void:
	if target >= ghost.value:
		# Curación: sincronizar ghost inmediatamente
		if _ghost_bar_delays.has(ghost) and _ghost_bar_delays[ghost] != null:
			_ghost_bar_delays[ghost].kill()
		if _ghost_bar_tweens.has(ghost) and _ghost_bar_tweens[ghost] != null:
			_ghost_bar_tweens[ghost].kill()
		ghost.value = target
		return
	# Daño: esperar 0.45s luego drenar en 0.6s
	if _ghost_bar_delays.has(ghost) and _ghost_bar_delays[ghost] != null:
		_ghost_bar_delays[ghost].kill()
	var delay_tw = main.create_tween()
	delay_tw.tween_interval(0.45)
	delay_tw.tween_callback(func():
		if _ghost_bar_tweens.has(ghost) and _ghost_bar_tweens[ghost] != null:
			_ghost_bar_tweens[ghost].kill()
		var drain = main.create_tween()
		drain.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drain.tween_property(ghost, "value", target, 0.6)
		_ghost_bar_tweens[ghost] = drain
	)
	_ghost_bar_delays[ghost] = delay_tw

func _get_hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.72, 0.08, 0.08)   # Carmesí oscuro — sangre
	elif ratio > 0.3:
		return Color(0.78, 0.32, 0.04)   # Ámbar quemado
	else:
		return Color(0.92, 0.04, 0.04)   # Carmesí brillante crítico

func _set_bar_color(bar: ProgressBar, ratio: float) -> void:
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = _get_hp_color(ratio)
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", s_fg)

func _flash_heal(bar: ProgressBar, final_ratio: float) -> void:
	var flash = StyleBoxFlat.new()
	flash.bg_color = Color(0.9, 0.3, 0.3)   # Rosa-carmesí (curación)
	flash.set_corner_radius_all(2)
	flash.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", flash)
	var target_color = _get_hp_color(final_ratio)
	var tw = main.create_tween()
	tw.tween_method(func(c: Color): flash.bg_color = c,
		Color(0.9, 0.3, 0.3), target_color, 0.4)

func _start_low_hp_pulse() -> void:
	if _low_hp_pulse_tween != null and _low_hp_pulse_tween.is_running():
		return
	if _low_hp_pulse_tween != null:
		_low_hp_pulse_tween.kill()
	_low_hp_pulse_tween = main.create_tween().set_loops()
	_low_hp_pulse_tween.tween_method(
		func(c: Color): _player_panel_style.border_color = c,
		Color(0.45, 0.35, 0.65), Color(0.9, 0.1, 0.1), 0.5)
	_low_hp_pulse_tween.tween_method(
		func(c: Color): _player_panel_style.border_color = c,
		Color(0.9, 0.1, 0.1), Color(0.45, 0.35, 0.65), 0.5)

func _stop_low_hp_pulse() -> void:
	if _low_hp_pulse_tween != null:
		_low_hp_pulse_tween.kill()
		_low_hp_pulse_tween = null
	if _player_panel_style != null:
		_player_panel_style.border_color = Color(0.45, 0.35, 0.65)

func update_intent_labels() -> void:
	var has_manual = GameManager.has_relic("manual_anatomista")
	for e in main.enemies:
		if e.hp <= 0 or not e.get("lbl_intent_icon"): continue

		# Logica de Intenciones Corruptas por Locura (Respetar Manual del Anatomista)
		if GameManager.sanity < 20 and not has_manual:
			var creepy = ["TE OBSERVA", "ACECHANDO", "...", "INEVITABLE"]
			e.lbl_intent_icon.text = creepy[randi() % creepy.size()]
			e.lbl_intent_icon.modulate = Color(0.8, 0.2, 0.2)
			if e.get("intent_badge_style"):
				e.intent_badge_style.bg_color = Color(0.4, 0.05, 0.4, 0.7)
			continue

		if e.peaceful:
			if e.name == "El Penitente":
				var thought = main._get_penitente_thought()
				var display_text = main._get_deciphered_thought(thought)

				e.lbl_intent_icon.text = display_text + " (" + str(e.peaceful_turns) + ")"
				e.lbl_intent_icon.modulate = Color(0.9, 0.8, 0.2) # Amarillo
				if e.get("intent_badge_style"):
					e.intent_badge_style.bg_color = Color(0.3, 0.1, 0.1, 0.0)
				continue

		# Intencion normal
		var action = e.pattern[e.turn_index % e.pattern.size()]
		var icon = ""
		var col = Color.WHITE
		var badge_col = Color(0.3, 0.1, 0.1, 0.0)

		match action.type:
			"attack":
				var reduction = e.get("atk_reduction", 0)
				var final_dmg = max(0, action.value - reduction)
				icon = "⚔ " + str(final_dmg)
				if reduction > 0:
					col = Color(0.5, 1.0, 0.5) # Verde si está debilitado
					icon += " (-" + str(reduction) + ")"
				else:
					col = Color(1, 0.4, 0.4)
				badge_col = Color(0.5, 0.08, 0.08, 0.7)
			"shield":
				icon = "🛡 " + str(action.value)
				col = Color(0.4, 0.7, 1.0)
				badge_col = Color(0.05, 0.15, 0.5, 0.7)
			"insanity":
				icon = "👁 " + str(action.value)
				col = Color(0.7, 0.4, 1.0)
				badge_col = Color(0.25, 0.05, 0.4, 0.7)
			"ultimate_charge":
				icon = "⚠ CARGANDO..."
				col = Color(1.0, 0.9, 0.1)
				badge_col = Color(0.5, 0.3, 0.0, 0.8)
			"ultimate_attack":
				var reduction = e.get("atk_reduction", 0)
				var final_dmg = max(0, action.value - reduction)
				icon = "☠ JUICIO (" + str(final_dmg) + ")"
				if reduction > 0:
					col = Color(0.5, 1.0, 0.5)
				else:
					col = Color(1.0, 0.0, 0.0)
				badge_col = Color(0.5, 0.3, 0.0, 0.8)
			_:
				icon = "???"

		e.lbl_intent_icon.text = icon
		e.lbl_intent_icon.modulate = col
		if e.get("intent_badge_style"):
			e.intent_badge_style.bg_color = badge_col

		# Animacion de escala si es un ataque fuerte
		if action.type in ["ultimate_attack", "attack"] and action.value > 15:
			var tw_sc = main.create_tween().set_loops()
			tw_sc.tween_property(e.lbl_intent_icon, "scale", Vector2(1.1, 1.1), 0.5)
			tw_sc.tween_property(e.lbl_intent_icon, "scale", Vector2(1.0, 1.0), 0.5)


# --- Energía como puntos visuales ---
func _build_energy_dots(max_energy: int) -> void:
	for d in energy_dots:
		if is_instance_valid(d): d.queue_free()
	energy_dots.clear()
	for i in range(max_energy):
		var dot = Panel.new()
		dot.size = Vector2(16, 16)
		dot.position = Vector2(100 + i * 22, 84)
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = Color(0.9, 0.7, 0.1)
		dot_style.set_corner_radius_all(8)
		dot_style.set_border_width_all(1)
		dot_style.border_color = Color(0.6, 0.45, 0.05)
		dot.add_theme_stylebox_override("panel", dot_style)
		player_panel.add_child(dot)
		energy_dots.append(dot)

func _update_energy_dots(current: int, maximum: int) -> void:
	if energy_dots.size() != maximum:
		_build_energy_dots(maximum)
	for i in range(energy_dots.size()):
		var style = energy_dots[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i < current:
			style.bg_color = Color(0.9, 0.7, 0.1)
		else:
			style.bg_color = Color(0.25, 0.2, 0.05)

# --- Pulso de cordura crítica ---
func _start_sanity_pulse() -> void:
	if _sanity_pulse_tween != null and _sanity_pulse_tween.is_running(): return
	if _sanity_pulse_tween != null: _sanity_pulse_tween.kill()
	_sanity_pulse_tween = main.create_tween().set_loops()
	_sanity_pulse_tween.tween_method(
		func(c: Color): _sanity_fill_style.bg_color = c,
		Color(0.38, 0.1, 0.68), Color(0.65, 0.05, 0.45), 0.7)
	_sanity_pulse_tween.tween_method(
		func(c: Color): _sanity_fill_style.bg_color = c,
		Color(0.65, 0.05, 0.45), Color(0.38, 0.1, 0.68), 0.7)

func _stop_sanity_pulse() -> void:
	if _sanity_pulse_tween != null:
		_sanity_pulse_tween.kill(); _sanity_pulse_tween = null
	if _sanity_fill_style != null:
		_sanity_fill_style.bg_color = Color(0.38, 0.1, 0.68)

# Funciones de utilidad para creación de nodos (copiadas de Combat.gd)
func _make_panel(pos: Vector2, size: Vector2, bg: Color, border: Color) -> Panel:
	var p = Panel.new()
	p.position = pos; p.size = size
	var s = StyleBoxFlat.new()
	s.bg_color = bg; s.set_border_width_all(2); s.border_color = border; s.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_hp_bar(m_hp: int, w: int, h: int = 16) -> ProgressBar:
	var b = ProgressBar.new()
	b.max_value = m_hp; b.value = m_hp; b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_constant_override("minimum_height", h)
	var s_bg = StyleBoxFlat.new()
	s_bg.bg_color = Color(0.08, 0.01, 0.01)
	s_bg.set_corner_radius_all(2)
	s_bg.set_content_margin_all(0)
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = Color(0.72, 0.08, 0.08)
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", s_bg); b.add_theme_stylebox_override("fill", s_fg)
	b.set_deferred("size", Vector2(w, h))
	return b

func _make_ghost_bar(m_hp: int, w: int, h: int = 16) -> ProgressBar:
	var b = ProgressBar.new()
	b.max_value = m_hp; b.value = m_hp; b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_constant_override("minimum_height", h)
	var s_bg = StyleBoxFlat.new(); s_bg.bg_color = Color(0, 0, 0, 0)
	s_bg.set_content_margin_all(0)
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = Color(0.45, 0.15, 0.04)   # naranja-marrón oscuro
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", s_bg); b.add_theme_stylebox_override("fill", s_fg)
	b.set_deferred("size", Vector2(w, h))
	return b

func _make_shield_bar(max_hp: int, w: int, h: int = 10) -> ProgressBar:
	var b = ProgressBar.new()
	b.max_value = max_hp; b.value = 0; b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_constant_override("minimum_height", h)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s_bg = StyleBoxFlat.new(); s_bg.bg_color = Color(0, 0, 0, 0)
	s_bg.set_content_margin_all(0)
	var s_fg = StyleBoxFlat.new()
	s_fg.bg_color = Color(0.18, 0.48, 0.88, 0.75)
	s_fg.set_corner_radius_all(2)
	s_fg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", s_bg)
	b.add_theme_stylebox_override("fill", s_fg)
	b.set_deferred("size", Vector2(w, h))
	return b

func _make_pile_label(pos: Vector2, col: Color) -> Label:
	var l = Label.new(); l.position = pos; l.modulate = col
	l.add_theme_font_size_override("font_size", 14)
	return l

# --- Target Highlight ---
func highlight_enemy_panel(panel: Panel) -> void:
	if _currently_highlighted == panel:
		return
	if _currently_highlighted != null and _currently_highlighted != panel:
		clear_target_highlight()

	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return

	if not _target_highlight_style.has(panel):
		var saved = StyleBoxFlat.new()
		saved.bg_color = style.bg_color
		saved.border_color = style.border_color
		saved.set_border_width_all(style.get_border_width(SIDE_LEFT))
		saved.set_corner_radius_all(style.get_corner_radius(CORNER_TOP_LEFT))
		_target_highlight_style[panel] = saved

	style.border_color = Color(1.0, 0.85, 0.1)
	style.set_border_width_all(3)
	_currently_highlighted = panel

	if _target_highlight_tween != null:
		_target_highlight_tween.kill()
	_target_highlight_tween = main.create_tween().set_loops()
	_target_highlight_tween.tween_property(panel, "scale", Vector2(1.02, 1.02), 0.2)
	_target_highlight_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2)

func clear_target_highlight() -> void:
	if _currently_highlighted == null:
		return
	var panel = _currently_highlighted
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null and _target_highlight_style.has(panel):
		var saved = _target_highlight_style[panel] as StyleBoxFlat
		style.border_color = saved.border_color
		style.set_border_width_all(saved.get_border_width(SIDE_LEFT))
	if _target_highlight_tween != null:
		_target_highlight_tween.kill()
		_target_highlight_tween = null
	panel.scale = Vector2(1.0, 1.0)
	_currently_highlighted = null

func update_targeting_arrow(from: Vector2, to: Vector2) -> void:
	targeting_arrow.clear_points()
	targeting_arrow.add_point(from)
	targeting_arrow.add_point(to)
	targeting_arrow.visible = true

	# Arrowhead triangle
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var tip_size = 12.0
	var p1 = to
	var p2 = to - dir * tip_size + perp * (tip_size * 0.6)
	var p3 = to - dir * tip_size - perp * (tip_size * 0.6)
	targeting_arrow_head.clear_points()
	targeting_arrow_head.add_point(p1)
	targeting_arrow_head.add_point(p2)
	targeting_arrow_head.add_point(p3)
	targeting_arrow_head.add_point(p1)
	targeting_arrow_head.visible = true
