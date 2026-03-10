extends Node2D

func _ready() -> void:
	modulate.a = 0.0
	build_ui()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)

func _typewrite(lbl: Label, text: String, base_delay: float = 0.07) -> void:
	lbl.text = ""
	for i in range(text.length()):
		lbl.text = text.substr(0, i + 1)
		var c = text[i]
		var wait = base_delay
		if c in [".", "!", "?"]: wait = base_delay * 5.0
		elif c == "\n":          wait = base_delay * 4.0
		await get_tree().create_timer(wait).timeout

func build_ui() -> void:
	var won = GameManager.player_won

	# Fondo oscuro
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.02) if won else Color(0.04, 0.02, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Titulo — aparece letra a letra tras el fade in
	var title = Label.new()
	title.text = ""
	title.add_theme_font_size_override("font_size", 56)
	title.modulate = Color(0.85, 0.75, 0.1) if won else Color(0.8, 0.15, 0.15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.size = Vector2(1152, 80)
	add_child(title)

	var title_text: String
	if won:
		title_text = "EL TABLERO SE ROMPE" if GameManager.is_hastur_fight else "HAS GANADO"
	else:
		title_text = "HAS CAIDO"
	_typewrite(title, title_text, 0.09)  # no await — corre en paralelo con el resto del build

	var subtitle = Label.new()
	if won and GameManager.is_hastur_fight:
		subtitle.text = "Hastur no muere. Pero esta vez, tu tampoco."
	elif won:
		subtitle.text = "El Rey Amarillo cae. El juego era tuyo desde el principio."
	else:
		subtitle.text = "El Gran Jugador mueve otra pieza."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(0.0, 0.0, 0.0, 0.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 115)
	subtitle.size = Vector2(1152, 30)
	add_child(subtitle)
	# Subtitulo aparece cuando el titulo termina de escribirse
	var st_delay = title_text.length() * 0.09 + 0.5
	get_tree().create_timer(st_delay).timeout.connect(func():
		var st = create_tween()
		st.tween_property(subtitle, "modulate", Color(0.7, 0.9, 0.7) if won else Color(0.6, 0.6, 0.6), 0.6)
	)

	var cause_lbl = Label.new()
	if won:
		cause_lbl.text = "PARTIDA COMPLETADA. EL TABLERO ESPERA LA PROXIMA PIEZA."
		cause_lbl.modulate = Color(0.6, 0.9, 0.4)
	elif GameManager.sanity <= 0:
		cause_lbl.text = "TU MENTE HA SIDO RECLAMADA POR EL TABLERO.\nERES UNA PIEZA SIN MEMORIA."
		cause_lbl.modulate = Color(0.8, 0.4, 1.0) # Purpura locura
	else:
		cause_lbl.text = "TU CARNE HA FALLADO. EL REY AMARILLO TE RECICLARA."
		cause_lbl.modulate = Color(0.8, 0.2, 0.2) # Rojo daño
	cause_lbl.add_theme_font_size_override("font_size", 18)
	cause_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cause_lbl.position = Vector2(0, 135)
	cause_lbl.size = Vector2(1152, 50)
	add_child(cause_lbl)

	# Panel resumen
	var panel = Panel.new()
	panel.position = Vector2(276, 160)
	panel.size = Vector2(600, 340)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.06) if won else Color(0.08, 0.06, 0.06)
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.5, 0.15) if won else Color(0.4, 0.15, 0.15)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var resumen_title = Label.new()
	resumen_title.text = "RESUMEN DE LA PARTIDA"
	resumen_title.add_theme_font_size_override("font_size", 18)
	resumen_title.modulate = Color(0.9, 0.7, 0.3)
	resumen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resumen_title.position = Vector2(276, 170)
	resumen_title.size = Vector2(600, 30)
	add_child(resumen_title)

	# Stats
	var stats = [
		["Piso alcanzado", str(GameManager.current_map_floor) + " / " + str(GameManager.map_graph.size())],
		["Combates ganados", str(GameManager.combat_count)],
		["Monedas acumuladas", str(GameManager.coins)],
		["Cartas en el mazo", str(GameManager.player_deck.size())],
		["Reliquias obtenidas", str(GameManager.relics.size())],
	]

	for i in range(stats.size()):
		var row = _make_stat_row(stats[i][0], stats[i][1])
		row.position = Vector2(310, 215 + i * 40)
		add_child(row)

	# Cartas del mazo
	var deck_title = Label.new()
	deck_title.text = "Mazo final:"
	deck_title.add_theme_font_size_override("font_size", 13)
	deck_title.modulate = Color(0.7, 0.7, 0.7)
	deck_title.position = Vector2(310, 425)
	add_child(deck_title)

	var deck_names = GameManager.player_deck.map(func(c): return c["name"])
	var deck_label = Label.new()
	deck_label.text = ", ".join(deck_names)
	deck_label.add_theme_font_size_override("font_size", 12)
	deck_label.modulate = Color(0.6, 0.6, 0.8)
	deck_label.position = Vector2(310, 445)
	deck_label.size = Vector2(532, 40)
	deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(deck_label)

	# Reliquias obtenidas
	if not GameManager.relics.is_empty():
		var relic_title = Label.new()
		relic_title.text = "Reliquias:"
		relic_title.add_theme_font_size_override("font_size", 13)
		relic_title.modulate = Color(0.7, 0.7, 0.7)
		relic_title.position = Vector2(310, 490)
		add_child(relic_title)

		var relic_scene = preload("res://scenes/ui/RelicIcon.tscn")
		var rx = 310
		for relic_id in GameManager.relics:
			var icon = relic_scene.instantiate()
			icon.position = Vector2(rx, 508)
			add_child(icon)
			icon.setup(relic_id)
			rx += 52

	# Botones
	var retry_btn = Button.new()
	retry_btn.text = "Nueva partida" if won else "Volver a intentarlo"
	retry_btn.position = Vector2(276, 540)
	retry_btn.size = Vector2(280, 50)
	retry_btn.pressed.connect(_on_retry)
	add_child(retry_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Salir"
	quit_btn.position = Vector2(596, 540)
	quit_btn.size = Vector2(280, 50)
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)

func _make_stat_row(label_text: String, value_text: String) -> Node2D:
	var row = Node2D.new()

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.8, 0.8, 0.8)
	lbl.size = Vector2(300, 30)
	row.add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 14)
	val.modulate = Color(1.0, 0.85, 0.4)
	val.position = Vector2(320, 0)
	val.size = Vector2(200, 30)
	row.add_child(val)

	return row

func _on_retry() -> void:
	GameManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")

func _on_quit() -> void:
	get_tree().quit()
