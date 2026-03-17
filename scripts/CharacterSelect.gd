extends Node2D

const CHARACTERS = [
	{
		"id": "conquistador",
		"name": "EL CONQUISTADOR",
		"style": "Senda del Acero — AGRESIVO",
		"hp": 55,
		"lore": "Un general de armadura bermellon, el ultimo de un imperio que el tiempo olvido. Llego a Valdris buscando la gloria eterna que sus poetas prometieron.\n\n'Si este es el tablero de los dioses, lo teñire de rojo hasta que mi nombre sea ley.'",
		"passive": "CONQUISTA: Al matar a un enemigo, tus Siervos ganan +1 ATK permanente y recuperas 3 de vida.",
		"color": Color(0.7, 0.2, 0.2),
		"symbol": "♜",
		"deck": [
			{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
			{"name": "Susurro Debilitante", "attack": 0, "defense": 0, "cost": 0},
			{"name": "Cabalgante del Vacio", "attack": 4, "defense": 0, "cost": 2},
			{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2},
			{"name": "Ofrenda de Carne", "attack": 8, "defense": 0, "cost": 2},
		]
	},
	{
		"id": "estratega",
		"name": "EL ESTRATEGA",
		"style": "Senda del Cristal — TACTICO",
		"hp": 40,
		"lore": "Un erudito que paso decadas estudiando las estrellas y los mapas imposibles. Cree que Valdris es un rompecabezas que, una vez resuelto, detendra la podredumbre de su mundo.\n\n'No busco sangre, sino el patron que mueve las manos de la realidad.'",
		"passive": "LOGICA: Tus cartas de Inquisidor Ciego cuestan -1 de energia. Robas 1 carta extra al inicio de cada combate.",
		"color": Color(0.2, 0.4, 0.7),
		"symbol": "♛",
		"deck": [
			{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
			{"name": "Susurro Debilitante", "attack": 0, "defense": 0, "cost": 0},
			{"name": "Inquisidor Ciego", "attack": 2, "defense": 0, "cost": 2},
			{"name": "Inquisidor Ciego", "attack": 2, "defense": 0, "cost": 2},
			{"name": "Dama del Tablero", "attack": 6, "defense": 2, "cost": 3},
		]
	},
	{
		"id": "guardian",
		"name": "EL GUARDIAN",
		"style": "Senda del Muro — DEFENSIVO",
		"hp": 55,
		"lore": "Un caballero que desperto entre las ruinas de su propio juramento. No recuerda a quien protegia, solo que no debe fallar de nuevo. Su escudo es lo unico que queda de su identidad.\n\n'No permitire que una sola pieza mas caiga en este juego sin sentido.'",
		"passive": "RESILIENCIA: Generas 1 de Furia por cada 5 de daño recibido. A las 3 cargas, tu siguiente ataque hace daño doble.",
		"color": Color(0.3, 0.55, 0.3),
		"symbol": "♞",
		"deck": [
			{"name": "Siervo Quebrado", "attack": 2, "defense": 0, "cost": 1},
			{"name": "Eco del Vacío", "attack": 4, "defense": 0, "cost": 2},
			{"name": "Baluarte de Hueso", "attack": 3, "defense": 3, "cost": 2},
			{"name": "Idolo Inerte", "attack": 0, "defense": 8, "cost": 3},
			{"name": "Idolo Inerte", "attack": 0, "defense": 8, "cost": 3},
		]
	}
]

var available_characters: Array = []
var selected_idx: int = 0
var title_lbl: Label
var lore_lbl: Label
var passive_lbl: Label
var stats_lbl: Label
var style_lbl: Label
var symbol_lbl: Label
var portrait_container: Control
var portrait_tween: Tween

func _ready() -> void:
	# Filtrar personajes disponibles
	available_characters = CHARACTERS.duplicate()
	if GameManager.prince_unlocked:
		available_characters.append({
			"id": "prince",
			"name": "EL PRÍNCIPE DE CARCOSA",
			"style": "Senda del Abismo — LOCURA",
			"hp": 45,
			"lore": "Un antiguo heredero de un reino que ya no existe. Su cuerpo es un receptáculo de la estática abisal.\n\n'No me liberaste para salvarme, sino para que termine lo que el Rey empezó.'",
			"passive": "RESONANCIA: Si tu Cordura es inferior a 35, tus efectos de Daño y Escudo se duplican.",
			"color": Color(0.5, 0.2, 0.8),
			"symbol": "♔",
			"deck": CardData.PRINCE_DECK.duplicate(true)
		})
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_all()
		AudioManager.play_loop("ES_Lost in Time - Aiyo")
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_ui()
	_update_display()

func _build_ui() -> void:
	var vp = get_viewport_rect().size
	var header = Label.new()
	header.text = "ELIGE TU PIEZA"
	header.add_theme_font_size_override("font_size", 40)
	header.modulate = Color(0.85, 0.75, 0.1)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 30); header.size = Vector2(vp.x, 60); add_child(header)

	var panel = Panel.new()
	panel.position = Vector2(176, 120); panel.size = Vector2(800, 420)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.05, 0.08, 0.9); ps.set_corner_radius_all(10); ps.border_width_left = 2; ps.border_color = Color(0.3, 0.3, 0.4)
	panel.add_theme_stylebox_override("panel", ps); add_child(panel)

	portrait_container = Control.new(); portrait_container.position = Vector2(25, 40); portrait_container.size = Vector2(180, 180); panel.add_child(portrait_container)
	symbol_lbl = Label.new(); symbol_lbl.add_theme_font_size_override("font_size", 32); symbol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; symbol_lbl.position = Vector2(25, 220); symbol_lbl.size = Vector2(180, 40); panel.add_child(symbol_lbl)
	title_lbl = Label.new(); title_lbl.add_theme_font_size_override("font_size", 32); title_lbl.position = Vector2(240, 40); title_lbl.size = Vector2(540, 50); panel.add_child(title_lbl)
	style_lbl = Label.new(); style_lbl.add_theme_font_size_override("font_size", 14); style_lbl.modulate = Color(0.6, 0.6, 0.7); style_lbl.position = Vector2(240, 85); style_lbl.size = Vector2(540, 25); panel.add_child(style_lbl)
	lore_lbl = Label.new(); lore_lbl.add_theme_font_size_override("font_size", 16); lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD; lore_lbl.modulate = Color(0.75, 0.75, 0.8); lore_lbl.position = Vector2(240, 130); lore_lbl.size = Vector2(540, 160); panel.add_child(lore_lbl)
	passive_lbl = Label.new(); passive_lbl.add_theme_font_size_override("font_size", 15); passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD; passive_lbl.modulate = Color(0.4, 0.8, 1.0); passive_lbl.position = Vector2(240, 300); passive_lbl.size = Vector2(540, 80); panel.add_child(passive_lbl)
	stats_lbl = Label.new(); stats_lbl.add_theme_font_size_override("font_size", 18); stats_lbl.position = Vector2(20, 200); stats_lbl.size = Vector2(200, 40); stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(stats_lbl)

	var btn_prev = Button.new(); btn_prev.text = " < "; btn_prev.position = Vector2(100, 300); btn_prev.size = Vector2(60, 60); btn_prev.pressed.connect(func(): _change_selection(-1)); add_child(btn_prev)
	var btn_next = Button.new(); btn_next.text = " > "; btn_next.position = Vector2(992, 300); btn_next.size = Vector2(60, 60); btn_next.pressed.connect(func(): _change_selection(1)); add_child(btn_next)
	
	# --- BOTÓN DEV DESBLOQUEO ---
	var btn_dev_prince = Button.new()
	btn_dev_prince.text = "[DEV] Habilitar Príncipe"
	btn_dev_prince.position = Vector2(20, vp.y - 50)
	btn_dev_prince.add_theme_font_size_override("font_size", 10)
	btn_dev_prince.pressed.connect(func(): 
		GameManager.prince_unlocked = !GameManager.prince_unlocked
		get_tree().reload_current_scene()
	)
	add_child(btn_dev_prince)
	
	var btn_select = Button.new(); btn_select.text = "ACEPTAR ESTE DESTINO"; btn_select.position = Vector2(vp.x/2 - 150, 560); btn_select.size = Vector2(300, 60); btn_select.add_theme_font_size_override("font_size", 20); btn_select.pressed.connect(_on_select_pressed); add_child(btn_select); _style_main_button(btn_select)

func _update_display() -> void:
	var c_data = available_characters[selected_idx]
	title_lbl.text = c_data["name"]; title_lbl.modulate = c_data["color"]; style_lbl.text = c_data["style"]; lore_lbl.text = c_data["lore"]
	passive_lbl.text = "PASIVA: " + c_data["passive"]; stats_lbl.text = "VIDA: " + str(c_data["hp"]); symbol_lbl.text = c_data["symbol"]; symbol_lbl.modulate = c_data["color"]
	_draw_portrait(c_data["id"])

func _draw_portrait(char_id: String) -> void:
	if portrait_tween: portrait_tween.kill()
	for c in portrait_container.get_children(): c.queue_free()
	var pixels = []; var colors = [Color(0,0,0,0), Color.WHITE, Color.WHITE]; var eye_pixels: Array[ColorRect] = []
	match char_id:
		"conquistador":
			colors = [Color(0.1, 0.05, 0.05), Color(0.6, 0.1, 0.1), Color(0.2, 0.2, 0.2)]
			pixels = [[0,0,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1],[1,1,2,2,2,2,2,2,1,1],[1,1,2,0,0,0,0,2,1,1],[1,1,2,2,2,2,2,2,1,1],[0,1,1,1,2,2,1,1,1,0],[0,0,1,1,2,2,1,1,0,0],[0,0,0,1,1,1,1,0,0,0]]
		"estratega":
			colors = [Color(0.05, 0.05, 0.1), Color(0.2, 0.3, 0.6), Color(0.9, 0.9, 0.5)]
			pixels = [[0,0,0,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,0],[1,1,1,0,0,0,0,1,1,1],[1,1,0,2,0,0,2,0,1,1],[1,1,1,0,0,0,0,1,1,1],[0,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,0,0],[0,0,0,1,1,1,1,0,0,0]]
		"guardian":
			colors = [Color(0.05, 0.1, 0.05), Color(0.3, 0.5, 0.3), Color(0.5, 0.5, 0.5)]
			pixels = [[1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1],[1,2,2,2,2,2,2,2,2,1],[1,2,0,0,0,0,0,0,2,1],[1,2,2,2,2,2,2,2,2,1],[1,1,1,1,2,2,1,1,1,1],[1,1,1,1,2,2,1,1,1,1],[0,1,1,1,2,2,1,1,1,0],[0,0,1,1,1,1,1,1,0,0]]
		"prince":
			colors = [Color(0.1, 0.05, 0.15), Color(0.5, 0.2, 0.8), Color(0.8, 0.8, 1.0)]
			pixels = [[0,0,1,1,1,1,1,1,0,0],[0,1,1,2,2,2,2,1,1,0],[1,1,2,2,2,2,2,2,1,1],[1,2,2,0,0,0,0,2,2,1],[1,2,0,2,0,0,2,0,2,1],[1,2,2,0,0,0,0,2,2,1],[0,1,2,2,2,2,2,2,1,0],[0,0,1,1,2,2,1,1,0,0],[0,0,0,1,1,1,1,0,0,0]]
	var p_size = 18
	for y in range(pixels.size()):
		for x in range(pixels[y].size()):
			var val = pixels[y][x]; if val == 0 and (char_id == "estratega" or char_id == "prince"): continue 
			var p = ColorRect.new(); p.size = Vector2(p_size - 1, p_size - 1); p.position = Vector2(x * p_size, y * p_size)
			if char_id == "conquistador" and val == 0 and y == 4: p.color = Color(0.2, 0, 0); eye_pixels.append(p)
			elif char_id == "estratega" and val == 2: p.color = colors[val]; eye_pixels.append(p)
			elif char_id == "guardian" and val == 0: p.color = Color(0.1, 0.1, 0.1); eye_pixels.append(p)
			elif char_id == "prince" and val == 0: p.color = Color(0.3, 0.1, 0.4); eye_pixels.append(p)
			else: p.color = colors[val]
			portrait_container.add_child(p)
	_animate_portrait_features(char_id, eye_pixels)

func _animate_portrait_features(char_id: String, eyes: Array) -> void:
	portrait_tween = create_tween().set_loops()
	match char_id:
		"conquistador":
			for p in eyes: portrait_tween.parallel().tween_property(p, "color", Color(1.0, 0.1, 0.1), 0.1).set_delay(randf_range(2.0, 4.0)); portrait_tween.tween_property(p, "color", Color(0.2, 0, 0), 0.1)
		"estratega":
			for p in eyes: portrait_tween.parallel().tween_property(p, "modulate", Color(1.5, 1.5, 1.5), 1.2); portrait_tween.tween_property(p, "modulate", Color(1.0, 1.0, 1.0), 1.2)
		"guardian":
			for p in eyes: portrait_tween.parallel().tween_property(p, "color", Color(0.4, 0.4, 0.4), 0.8); portrait_tween.tween_property(p, "color", Color(0.1, 0.1, 0.1), 0.8)
		"prince":
			for p in eyes: portrait_tween.parallel().tween_property(p, "modulate", Color(2.0, 1.5, 2.5), 1.5); portrait_tween.parallel().tween_property(p, "scale", Vector2(1.2, 1.2), 1.5); portrait_tween.tween_property(p, "modulate", Color(1.0, 1.0, 1.0), 1.5); portrait_tween.parallel().tween_property(p, "scale", Vector2(1.0, 1.0), 1.5)

func _change_selection(dir: int) -> void:
	selected_idx = posmod(selected_idx + dir, available_characters.size()); if get_node_or_null("/root/AudioManager"): AudioManager.play("menu_hover")
	_update_display()

func _on_select_pressed() -> void:
	var c_data = available_characters[selected_idx]
	var char_id = c_data["id"]
	
	# Reiniciar estado global para nueva partida
	GameManager.reset_run()
	
	GameManager.selected_character = char_id
	GameManager.player_hp = c_data["hp"]
	GameManager.player_max_hp = c_data["hp"]
	
	# Copia profunda del mazo base (Siempré limpio al empezar)
	var new_deck = []
	for card in c_data["deck"]:
		new_deck.append(card.duplicate())
	
	GameManager.player_deck = new_deck
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("button_click")
	GameManager.go_to_scene("res://scenes/ui/Map.tscn")

func _style_main_button(btn: Button) -> void:
	var s = StyleBoxFlat.new(); s.bg_color = Color(0.12, 0.1, 0.05); s.set_corner_radius_all(6); s.border_width_bottom = 4; s.border_color = Color(0.85, 0.75, 0.1); btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate(); h.bg_color = Color(0.2, 0.18, 0.08); btn.add_theme_stylebox_override("hover", h)
