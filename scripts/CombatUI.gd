extends Node

# Este script maneja toda la representación visual del combate
# para que Combat.gd se centre únicamente en la lógica del juego.

var main: Node2D # Referencia al script principal de Combat

# Referencias a nodos de UI (serán inicializados en build_ui)
var player_panel: Panel
var player_sprite_label: Label
var lbl_player_hp: Label
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

func setup(p_main: Node2D) -> void:
	main = p_main

func build_ui(vp: Vector2) -> void:
	_build_dynamic_background(vp)

	player_panel = _make_panel(Vector2(20, 280), Vector2(560, 125), Color(0.06, 0.06, 0.1), Color(0.4, 0.4, 0.6))
	main.add_child(player_panel)

	var char_id = GameManager.selected_character
	var char_info = CombatData.CHAR_DATA.get(char_id, {"symbol": "♟", "color": Color(0.8, 0.8, 0.8)})
	player_sprite_label = Label.new()
	player_sprite_label.text = char_info["symbol"]
	player_sprite_label.modulate = char_info["color"]
	player_sprite_label.add_theme_font_size_override("font_size", 60)
	player_sprite_label.position = Vector2(10, 15)
	player_sprite_label.size = Vector2(80, 90)
	player_sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_sprite_label.mouse_filter = Control.MOUSE_FILTER_STOP
	player_panel.add_child(player_sprite_label)
	
	player_sprite_label.mouse_entered.connect(main._show_player_passive_tooltip)
	player_sprite_label.mouse_exited.connect(main._hide_player_passive_tooltip)
	
	main._start_player_idle_bob()

	hp_bar_player = _make_hp_bar(main.player_max_hp, 440); hp_bar_player.position = Vector2(100, 40); player_panel.add_child(hp_bar_player)

	sanity_bar_player = _make_hp_bar(100, 440); sanity_bar_player.position = Vector2(100, 58); player_panel.add_child(sanity_bar_player)
	var sb_style = StyleBoxFlat.new(); sb_style.bg_color = Color(0.1, 0.05, 0.2); sb_style.set_corner_radius_all(4)
	var sb_fill = StyleBoxFlat.new(); sb_fill.bg_color = Color(0.5, 0.3, 0.8)
	sanity_bar_player.add_theme_stylebox_override("background", sb_style)
	sanity_bar_player.add_theme_stylebox_override("fill", sb_fill)

	lbl_player_hp = Label.new(); lbl_player_hp.position = Vector2(100, 10); player_panel.add_child(lbl_player_hp)
	
	lbl_sanity = Label.new(); lbl_sanity.position = Vector2(350, 10); lbl_sanity.add_theme_font_size_override("font_size", 14); player_panel.add_child(lbl_sanity)

	lbl_energy = Label.new(); lbl_energy.position = Vector2(100, 78); player_panel.add_child(lbl_energy)

	if char_id == "guardian":
		lbl_furia = Label.new()
		lbl_furia.position = Vector2(300, 78)
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
		var eh = _make_hp_bar(main.enemies[i].max_hp, 180); eh.position = Vector2(10, 215); ep.add_child(eh); main.enemies[i].hp_bar = eh

		var lin = Label.new(); lin.position = Vector2(0, 245); lin.size = Vector2(200, 22)
		lin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lin.add_theme_font_size_override("font_size", 11)
		ep.add_child(lin); main.enemies[i].lbl_intent_icon = lin

	targeting_arrow = Line2D.new(); targeting_arrow.width = 4
	targeting_arrow.default_color = Color(1, 0.8, 0.2); targeting_arrow.visible = false; main.add_child(targeting_arrow)

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
	
	for i in range(60):
		var p = ColorRect.new(); p.size = Vector2(1, 15)
		p.color = Color(0.8, 0.1, 0.1, 0.4) if is_avatar else Color(0.5, 0.5, 0.7, 0.15)
		p.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y)); p.z_index = -8; main.add_child(p)
		main.create_tween().set_loops().tween_property(p, "position:y", vp.y + 20, randf_range(0.8, 1.2)).from(-20)

func update_ui() -> void:
	lbl_player_hp.text = "SALUD: %d / %d" % [main.player_hp, main.player_max_hp]
	lbl_player_hp.modulate = Color.WHITE
	
	if main.player_shield > 0: 
		lbl_player_hp.text += " (+%d ESCUDO)" % main.player_shield
		lbl_player_hp.modulate = Color(0.5, 0.85, 1.0) # Tinte azulado para todo el texto si hay escudo
	
	hp_bar_player.max_value = main.player_max_hp
	hp_bar_player.value = main.player_hp
	
	sanity_bar_player.max_value = GameManager.max_sanity
	sanity_bar_player.value = GameManager.sanity
	
	var sanity_label = GameManager.get_sanity_label()
	lbl_sanity.text = "%s: %d / %d" % [sanity_label, GameManager.sanity, GameManager.max_sanity]
	if GameManager.sanity < 40:
		lbl_sanity.modulate = Color(0.8, 0.4, 1.0) # Morado brillante para Locura
	else:
		lbl_sanity.modulate = Color(0.6, 0.5, 0.8)
	
	lbl_energy.text = "ENERGÍA: %d / %d" % [main.player_energy, main.player_max_energy]
	if GameManager.mark_level > 0: lbl_energy.text += " (Signo Lv%d)" % GameManager.mark_level

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
		e.hp_bar.value = e.hp
		
		if e.shield > 0:
			e.lbl_shield.text = "ESCUDO: %d" % e.shield
			e.lbl_shield.visible = true
		else:
			e.lbl_shield.visible = false

func update_intent_labels() -> void:
	var has_manual = GameManager.has_relic("manual_anatomista")
	for e in main.enemies:
		if e.hp <= 0 or not e.get("lbl_intent_icon"): continue

		# Logica de Intenciones Corruptas por Locura (Respetar Manual del Anatomista)
		if GameManager.sanity < 20 and not has_manual:
			var creepy = ["TE OBSERVA", "ACECHANDO", "...", "INEVITABLE"]
			e.lbl_intent_icon.text = creepy[randi() % creepy.size()]
			e.lbl_intent_icon.modulate = Color(0.8, 0.2, 0.2)
			continue

		if e.peaceful:
			if e.name == "El Penitente":
				var thought = main._get_penitente_thought()
				var display_text = main._get_deciphered_thought(thought)

				e.lbl_intent_icon.text = display_text + " (" + str(e.peaceful_turns) + ")"
				e.lbl_intent_icon.modulate = Color(0.9, 0.8, 0.2) # Amarillo
				continue

		# Intencion normal
		var action = e.pattern[e.turn_index % e.pattern.size()]
		var icon = ""
		var col = Color.WHITE
		
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
			"shield": 
				icon = "🛡 " + str(action.value)
				col = Color(0.4, 0.7, 1.0)
			"insanity": 
				icon = "👁 " + str(action.value)
				col = Color(0.7, 0.4, 1.0)
			"ultimate_charge":
				icon = "⚠ CARGANDO..."
				col = Color(1.0, 0.9, 0.1)
			"ultimate_attack":
				var reduction = e.get("atk_reduction", 0)
				var final_dmg = max(0, action.value - reduction)
				icon = "☠ JUICIO (" + str(final_dmg) + ")"
				if reduction > 0:
					col = Color(0.5, 1.0, 0.5)
				else:
					col = Color(1.0, 0.0, 0.0)
			_: 
				icon = "???"

		e.lbl_intent_icon.text = icon
		e.lbl_intent_icon.modulate = col
		
		# --- INDICADOR DE ESTADOS (Sangrado, Debilidad extra) ---
		var status_text = ""
		if e.get("bleed", 0) > 0:
			status_text += " 🩸" + str(e["bleed"])
		
		if status_text != "":
			e.lbl_intent_icon.text += status_text
		
		# Animacion de escala si es un ataque fuerte
		if action.type in ["ultimate_attack", "attack"] and action.value > 15:
			var tw_sc = main.create_tween().set_loops()
			tw_sc.tween_property(e.lbl_intent_icon, "scale", Vector2(1.1, 1.1), 0.5)
			tw_sc.tween_property(e.lbl_intent_icon, "scale", Vector2(1.0, 1.0), 0.5)


# Funciones de utilidad para creación de nodos (copiadas de Combat.gd)
func _make_panel(pos: Vector2, size: Vector2, bg: Color, border: Color) -> Panel:
	var p = Panel.new()
	p.position = pos; p.size = size
	var s = StyleBoxFlat.new()
	s.bg_color = bg; s.set_border_width_all(2); s.border_color = border; s.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_hp_bar(m_hp: int, w: int) -> ProgressBar:
	var b = ProgressBar.new()
	b.max_value = m_hp; b.value = m_hp; b.size = Vector2(w, 12)
	b.show_percentage = false
	var s_bg = StyleBoxFlat.new(); s_bg.bg_color = Color(0.2, 0.05, 0.05); s_bg.set_corner_radius_all(4)
	var s_fg = StyleBoxFlat.new(); s_fg.bg_color = Color(0.8, 0.2, 0.2); s_fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", s_bg); b.add_theme_stylebox_override("fill", s_fg)
	return b

func _make_pile_label(pos: Vector2, col: Color) -> Label:
	var l = Label.new(); l.position = pos; l.modulate = col
	l.add_theme_font_size_override("font_size", 14)
	return l
