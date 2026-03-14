extends Node2D

const DICE_REROLL_COST: int = 5
const DICE_FACES: Array = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]

var events: Array = [
	{
		"title": "El Altar Roto",
		"text": "Encuentras un altar con una pieza de ajedrez grabada.\nEmana un poder extrano.",
		"options": [
			{"label": "Tocarla (-5 HP)", "hp": -5, "coins": 0, "heal": 0, "relic": true},
			{"label": "Destruirla (+8 monedas)", "hp": 0, "coins": 8, "heal": 0},
			{"label": "Ignorar (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "El Mercader Encadenado",
		"text": "Un hombre con grilletes te mira con odio.\nTiene objetos valiosos.",
		"options": [
			{"label": "Comprar normalmente (ir a tienda)", "hp": 0, "coins": 0, "heal": 0, "goto_shop": true},
			{"label": "Liberarlo", "hp": 0, "coins": 0, "heal": 0, "relic": true},
			{"label": "Robarle (+10 monedas, -10 HP)", "hp": -10, "coins": 10, "heal": 0},
		]
	},
	{
		"title": "El Pueblo Fantasma",
		"text": "Un pueblo vacio. En las paredes:\n'Los heroes vinieron. Luego el silencio.'",
		"options": [
			{"label": "Investigar (+8 monedas)", "hp": 0, "coins": 8, "heal": 0},
			{"label": "Arrodillarte (-10 HP max)", "hp": 0, "coins": 0, "heal": 0, "relic": true, "max_hp": -10},
			{"label": "Salir rapido (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "La Fuente Oscura",
		"text": "Una fuente con agua negra.\nHuele a magia antigua.",
		"options": [
			{"label": "Beber (+20 HP)", "hp": 0, "coins": 0, "heal": 20},
			{"label": "Sumergir la mano (-15 HP)", "hp": -15, "coins": 0, "heal": 0, "relic": true},
			{"label": "Ignorar (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "El Caballero Sin Nombre",
		"text": "Un caballero de armadura negra bloquea el camino.\nNo ataca. Solo observa.\n\n'Si me vences, soy tuyo.'",
		"options": [
			{"label": "Desafiarlo (miniboss)", "hp": 0, "coins": 0, "heal": 0, "miniboss": true},
			{"label": "Ofrecerle monedas (-8 monedas)", "hp": 0, "coins": -8, "heal": 0},
			{"label": "Dar media vuelta (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "La Mesa del Destino",
		"text": "Una mesa de obsidiana en el centro de la sala.\nSobre ella, un dado con runas antiguas.\nUna voz sin boca susurra:\n'Un lanzamiento gratuito. Los demas... cuestan vida.'",
		"options": [
			{"label": "Tirar el dado (gratis)", "dice_game": true},
			{"label": "Ignorar (nada)", "hp": 0, "coins": 0, "heal": 0},
		]
	},
	{
		"title": "La Biblioteca de los Susurros",
		"text": "Una sala circular con miles de libros flotando, encuadernados en piel humana.\nVoces de todas las epocas hablan a la vez. No puedes taparte los oidos.\n'Todo es un juego. Todo es un ciclo. No eres real.'",
		"options": [
			{"label": "Leer el Capitulo Prohibido (+15 Lore, -30 Cordura)", "hp": 0, "coins": 0, "heal": 0, "lore_hint_big": true, "sanity_loss": 30},
			{"label": "Quemar la biblioteca (+10 HP, +15 Cordura)", "hp": 0, "coins": 0, "heal": 10, "sanity_gain": 15},
			{"label": "Escuchar los susurros (Reliquia, +2 Maldiciones)", "hp": 0, "coins": 0, "heal": 0, "relic": true, "double_curse": true},
		]
	},
	{
		"title": "El Espejo de las Vidas Pasadas",
		"text": "Un espejo de plata empanada. Al mirarte, no ves tu rostro, sino una de tus piezas de ajedrez desvaneciéndose.\nUna voz susurra: 'Olvida una parte de ti, y tu mente será más ligera... o tal vez más vacía.'",
		"options": [
			{"label": "Sacrificar un recuerdo (Eliminar carta, -20 Cordura)", "remove_card_event": true, "sanity_loss": 20},
			{"label": "Romper el espejo (-10 HP, +10 Monedas)", "hp": -10, "coins": 10},
			{"label": "Alejarse (nada)", "hp": 0},
		]
	},
]

var current_event: Dictionary = {}
var relic_assignments: Dictionary = {}

# Dice game state
var _dice_panel: Panel = null
var _dice_face_lbl: Label = null
var _dice_result_lbl: Label = null
var _dice_detail_lbl: Label = null
var _dice_status_lbl: Label = null
var _dice_reroll_btn: Button = null
var _dice_roll_count: int = 0
var _dice_rolling: bool = false

func _ready() -> void:
	var pool = events.duplicate()
	if GameManager.lore_progress >= 4 and not GameManager.has_relic("lengua_tablero"):
		pool.append({
			"title": "El Susurro Amarillo",
			"text": "Los caidos te hablan en un idioma extrano.\nPero entre los simbolos, reconoces algo:\nuna figura dorada. Un tablero infinito.\nUn nombre que no deberias saber.",
			"options": [
				{"label": "Buscar quien traduce (Lengua del Tablero, maldicion incluida)", "hp": 0, "coins": 0, "heal": 0, "specific_relic": "lengua_tablero"},
				{"label": "Ignorarlo. Los heroes no necesitan preguntas.", "hp": 0, "coins": 0, "heal": 0},
				{"label": "Escuchar hasta sangrar (-8 HP, +1 lore)", "hp": -8, "coins": 0, "heal": 0, "lore_hint": true},
			]
		})
	current_event = pool[randi() % pool.size()]
	_assign_relics()
	build_ui()

func _assign_relics() -> void:
	var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
	available.shuffle()
	var pool_idx = 0
	for i in range(current_event["options"].size()):
		var opt = current_event["options"][i]
		if opt.get("relic", false) and pool_idx < available.size():
			relic_assignments[i] = available[pool_idx]
			pool_idx += 1

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo abisal
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.size = vp
	add_child(bg)
	
	# Sol Negro sutil de fondo
	_create_background_sun(vp)
	_start_event_rain(vp)

	var info = Label.new()
	info.name = "InfoLabel"
	info.text = "HP: " + str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp) + "   Monedas: " + str(GameManager.coins) + "   Cordura: " + str(GameManager.sanity)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 15)
	info.size = Vector2(1152, 28)
	info.z_index = 10
	add_child(info)

	var title = Label.new()
	title.text = current_event["title"].to_upper()
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(0.85, 0.75, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(100, 60)
	title.size = Vector2(952, 50)
	title.z_index = 10
	add_child(title)

	var text_panel = Panel.new()
	text_panel.position = Vector2(176, 120); text_panel.size = Vector2(800, 140)
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.05, 0.08, 0.85); ts.set_corner_radius_all(8)
	ts.border_width_left = 2; ts.border_color = Color(0.4, 0.4, 0.5, 0.5)
	text_panel.add_theme_stylebox_override("panel", ts)
	text_panel.z_index = 5
	add_child(text_panel)

	var text = Label.new()
	text.text = current_event["text"]
	text.add_theme_font_size_override("font_size", 17)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.position = Vector2(20, 20); text.size = Vector2(760, 100)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_panel.add_child(text)

	var options = current_event["options"]
	for i in range(options.size()):
		var opt = options[i]
		_create_option_button(i, opt)
		
	# --- BOTON VER MAZO ---
	var btn_view = Button.new()
	btn_view.text = "🎴 VER MAZO"
	btn_view.size = Vector2(180, 45)
	btn_view.position = Vector2(vp.x - 220, 20)
	btn_view.add_theme_font_size_override("font_size", 14)
	btn_view.pressed.connect(func(): GameManager.show_deck_overlay(self))
	add_child(btn_view)

func _create_background_sun(vp: Vector2) -> void:
	var sun = Panel.new()
	var sz = 400.0
	sun.size = Vector2(sz, sz)
	sun.position = Vector2(vp.x/2 - sz/2, -100)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0,0,0)
	s.set_corner_radius_all(sz/2)
	s.border_width_left = 4; s.border_color = Color(0.8, 0.5, 0.1, 0.2)
	sun.add_theme_stylebox_override("panel", s)
	sun.modulate.a = 0.4
	add_child(sun)

func _start_event_rain(vp: Vector2) -> void:
	for i in range(60):
		var drop = ColorRect.new()
		drop.size = Vector2(1, randi_range(10, 20))
		drop.color = Color(0.5, 0.5, 0.7, 0.2)
		drop.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		add_child(drop)
		var dur = randf_range(0.6, 1.0)
		var tw = create_tween().set_loops()
		tw.tween_property(drop, "position:y", vp.y + 20, dur).from(-20)

func _create_option_button(i: int, opt: Dictionary) -> void:
	var row = Node2D.new()
	row.name = "OptionRow" + str(i)
	row.position = Vector2(226, 280 + i * 85)
	row.z_index = 10
	add_child(row)

	var label_text = opt["label"]
	if opt.get("hp", 0) < 0 or opt.get("max_hp", 0) < 0: label_text = "🩸 " + label_text
	elif opt.get("heal", 0) > 0: label_text = "🩹 " + label_text
	if opt.get("sanity_loss", 0) > 0: label_text = "🧠 " + label_text
	elif opt.get("sanity_gain", 0) > 0: label_text = "🕯 " + label_text
	if opt.get("relic", false): label_text = "💍 " + label_text
	if opt.get("add_curse", false) or opt.get("double_curse", false): label_text = "💀 " + label_text
	if opt.get("remove_card_event", false):
		label_text = "✂ " + label_text

	var btn = Button.new()
	btn.text = label_text
	btn.size = Vector2(560, 60)
	btn.add_theme_font_size_override("font_size", 15)
	
	# Tooltip Dinamico
	var tt = ""
	var has_relic_info = false
	var r_data_final = {}
	
	if opt.get("hp", 0) < 0: tt += "Pierdes " + str(abs(opt["hp"])) + " HP.\n"
	if opt.get("max_hp", 0) < 0: tt += "Pierdes " + str(abs(opt["max_hp"])) + " de Vida Maxima.\n"
	if opt.get("sanity_loss", 0) > 0: tt += "Pierdes " + str(opt["sanity_loss"]) + " de Cordura.\n"
	
	if opt.get("relic", false) and relic_assignments.has(i):
		var r_id = relic_assignments[i]
		r_data_final = GameManager.RELIC_DATA[r_id]
		has_relic_info = true
	elif opt.get("specific_relic", "") != "":
		var r_id = opt["specific_relic"]
		r_data_final = GameManager.RELIC_DATA.get(r_id, {"name": "???", "desc": "???"})
		has_relic_info = true
		
	if opt.get("double_curse", false):
		tt += "[!] MALDICION: Recibes 2 cartas de 'Peso de la Verdad'.\n"
	if opt.get("add_curse", false):
		tt += "[!] MALDICION: Recibes 1 carta de 'Peso de la Verdad'.\n"
	
	btn.tooltip_text = tt
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.border_width_bottom = 2; style.border_color = Color(0.3, 0.3, 0.4)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var idx = i
	btn.pressed.connect(func(): _on_option_selected(idx))
	
	var is_curse = opt.get("add_curse", false) or opt.get("double_curse", false)
	var is_bonus = opt.get("bonus_card", false)
	
	btn.mouse_entered.connect(func():
		if has_relic_info:
			_show_relic_preview(btn, r_data_final)
		if is_curse:
			var curse_data = {"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true}
			_show_card_preview(btn, curse_data, has_relic_info)
		elif is_bonus:
			var card_data = {"name": "Reina", "attack": 6, "defense": 2, "cost": 4}
			_show_card_preview(btn, card_data, has_relic_info)
	)
	
	btn.mouse_exited.connect(func():
		_hide_relic_preview()
		_hide_card_preview()
	)
		
	row.add_child(btn)

var _card_preview: Control

func _show_card_preview(target: Button, data: Dictionary, is_offset: bool = false) -> void:
	if _card_preview: _card_preview.queue_free()
	
	var vp = get_viewport_rect().size
	var card_scene = load("res://scenes/combat/Card.tscn")
	_card_preview = card_scene.instantiate()
	add_child(_card_preview)
	_card_preview.setup(data)
	
	var card_w = 130 * 1.1
	var relic_w = 300 if is_offset else 0
	
	# Determinar si hay espacio a la derecha
	var space_right = vp.x - (target.global_position.x + target.size.x)
	var required_w = relic_w + card_w + 40
	
	var final_pos = Vector2.ZERO
	if space_right >= required_w:
		# Lógica normal: a la derecha
		final_pos = target.global_position + Vector2(target.size.x + 20 + relic_w, -50)
	else:
		# No hay espacio a la derecha: mover a la izquierda del botón
		final_pos = target.global_position + Vector2(-card_w - 20, -50)
		
	_card_preview.global_position = final_pos
	_card_preview.scale = Vector2(1.1, 1.1)
	_card_preview.z_index = 150
	
	_card_preview.modulate.a = 0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_card_preview, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card_preview, "position:y", _card_preview.position.y + 20, 0.2).from(_card_preview.position.y)

func _hide_card_preview() -> void:
	if _card_preview:
		_card_preview.queue_free()
		_card_preview = null

var _relic_preview: Panel

func _show_relic_preview(target: Button, data: Dictionary) -> void:
	if _relic_preview: _relic_preview.queue_free()
	
	_relic_preview = Panel.new()
	_relic_preview.size = Vector2(280, 100)
	_relic_preview.z_index = 100
	
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.1, 0.98)
	s.border_width_left = 3; s.border_color = Color(0.9, 0.7, 0.2)
	s.set_corner_radius_all(6)
	_relic_preview.add_theme_stylebox_override("panel", s)
	
	var title = Label.new()
	title.text = "💍 " + data["name"].to_upper()
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(1, 0.9, 0.4)
	title.position = Vector2(12, 10)
	_relic_preview.add_child(title)
	
	var desc = Label.new()
	desc.text = data["desc"]
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	var est_lines = desc.text.length() / 30 + desc.text.count("\n") + 1
	var desc_h = max(60, est_lines * 16)
	desc.position = Vector2(12, 35); desc.size = Vector2(250, desc_h)
	_relic_preview.add_child(desc)
	
	_relic_preview.size = Vector2(280, 45 + desc_h)
	
	_relic_preview.global_position = target.global_position + Vector2(target.size.x + 15, -20)
	add_child(_relic_preview)
	
	_relic_preview.modulate.a = 0
	_relic_preview.scale = Vector2(0.9, 0.9)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_relic_preview, "modulate:a", 1.0, 0.15)
	tw.tween_property(_relic_preview, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_relic_preview() -> void:
	if _relic_preview:
		_relic_preview.queue_free()
		_relic_preview = null

func _show_lore_modal() -> void:
	var vp = get_viewport_rect().size
	# Usar CanvasLayer para asegurar prioridad sobre los otros elementos de Evento
	var layer = CanvasLayer.new()
	layer.layer = 150
	add_child(layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.96)
	overlay.size = vp
	layer.add_child(overlay)
	
	# Efecto de pergamino antiguo (estilizado con Panel)
	var scroll_panel = Panel.new()
	scroll_panel.size = Vector2(vp.x * 0.75, vp.y * 0.75)
	scroll_panel.position = (vp - scroll_panel.size) / 2
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.08, 0.05) # Sepia abisal
	s.set_border_width_all(3)
	s.border_color = Color(0.5, 0.4, 0.1)
	s.set_corner_radius_all(4)
	scroll_panel.add_theme_stylebox_override("panel", s)
	overlay.add_child(scroll_panel)
	
	var title = Label.new()
	title.text = "--- EL CAPÍTULO PROHIBIDO ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.9, 0.8, 0.3)
	title.position = Vector2(0, 40); title.size = Vector2(scroll_panel.size.x, 50)
	scroll_panel.add_child(title)
	
	var lore_text = Label.new()
	lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	lore_text.add_theme_font_size_override("font_size", 18)
	lore_text.modulate = Color(0.85, 0.85, 0.8)
	lore_text.position = Vector2(60, 110); lore_text.size = Vector2(scroll_panel.size.x - 120, scroll_panel.size.y - 220)
	scroll_panel.add_child(lore_text)
	
	var content = "En un reino que el mapa no nombra, un Rey buscó la eternidad en el reflejo de una pieza de marfil. No entendió que el tablero no era su dominio, sino su celda.\n\nAhora, el Rey Sin Corona aguarda en el tramo final del Tablero Dorado. Es el guardián de una puerta que no debe abrirse, el primer velo antes de la Perdida Carcosa.\n\n'Incluso los reyes lloran cuando el Amarillo viste su piel...'"
	
	var cont_btn = Button.new()
	cont_btn.text = "VOLVER AL MAPA"
	cont_btn.size = Vector2(240, 50)
	cont_btn.position = Vector2(scroll_panel.size.x/2 - 120, scroll_panel.size.y - 80)
	cont_btn.visible = false
	scroll_panel.add_child(cont_btn)
	cont_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/Map.tscn"))
	
	await _typewrite(lore_text, content)
	cont_btn.visible = true

func _typewrite(lbl: Label, text: String, base_delay: float = 0.015) -> void:
	lbl.text = ""
	for i in range(text.length()):
		lbl.text = text.substr(0, i + 1)
		if get_node_or_null("/root/AudioManager") and i % 6 == 0:
			AudioManager.play("menu_hover") # Sonido de escritura
		await get_tree().create_timer(base_delay).timeout

func _on_option_selected(idx: int) -> void:
	var opt = current_event["options"][idx]

	if opt.get("dice_game", false):
		_show_dice_game()
		return

	if opt.get("hp", 0) != 0:
		GameManager.player_hp = clamp(GameManager.player_hp + opt["hp"], 1, GameManager.player_max_hp)

	if opt.get("coins", 0) != 0:
		GameManager.coins = max(0, GameManager.coins + opt["coins"])

	if opt.get("heal", 0) > 0:
		GameManager.heal(opt["heal"])

	if opt.get("max_hp", 0) != 0:
		GameManager.player_max_hp = max(10, GameManager.player_max_hp + opt["max_hp"])
		GameManager.player_hp = clamp(GameManager.player_hp, 1, GameManager.player_max_hp)

	if opt.get("miniboss", false):
		GameManager.is_miniboss_fight = true
		GameManager.is_boss_fight = false
		get_tree().change_scene_to_file("res://scenes/combat/Combat.tscn")
		return

	if opt.get("goto_shop", false):
		get_tree().change_scene_to_file("res://scenes/ui/Shop.tscn")
		return

	if opt.get("bonus_card", false):
		var bonus = {"name": "Reina", "attack": 6, "defense": 2, "cost": 4}
		GameManager.add_card(bonus)

	if opt.get("remove_card_event", false):
		_show_card_removal_screen()
		return

	if opt.get("add_curse", false):
		var curse = {"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true}
		GameManager.add_card(curse)

	if opt.get("double_curse", false):
		var curse = {"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true}
		GameManager.add_card(curse)
		GameManager.add_card(curse)

	if opt.get("sanity_loss", 0) > 0:
		GameManager.sanity = max(0, GameManager.sanity - opt["sanity_loss"])

	if opt.get("sanity_gain", 0) > 0:
		GameManager.sanity = min(100, GameManager.sanity + opt["sanity_gain"])

	if opt.get("lore_hint_big", false):
		GameManager.lore_progress += 15
		GameManager.unlock_lore("capitulo_prohibido")
		_show_lore_modal()
		return

	if opt.get("relic", false) and relic_assignments.has(idx):
		GameManager.add_relic(relic_assignments[idx])
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("relic_get")

	if opt.get("specific_relic", "") != "":
		GameManager.add_relic(opt["specific_relic"])
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("relic_get")

	if opt.get("lore_hint", false):
		GameManager.lore_progress += 1

	get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")

# Dice game
func _show_dice_game() -> void:
	for i in range(current_event["options"].size()):
		var row = get_node_or_null("OptionRow" + str(i))
		if row:
			row.visible = false

	_dice_roll_count = 0

	_dice_panel = Panel.new()
	_dice_panel.position = Vector2(226, 100)
	_dice_panel.size = Vector2(700, 430)
	_dice_panel.z_index = 5
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.09, 0.98)
	ps.set_corner_radius_all(10)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.55, 0.45, 0.1)
	_dice_panel.add_theme_stylebox_override("panel", ps)
	add_child(_dice_panel)

	var title_lbl = Label.new()
	title_lbl.text = "El Dado del Destino"
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.modulate = Color(0.95, 0.82, 0.3)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(0, 18)
	title_lbl.size = Vector2(700, 38)
	_dice_panel.add_child(title_lbl)

	_dice_face_lbl = Label.new()
	_dice_face_lbl.text = "⚄"
	_dice_face_lbl.add_theme_font_size_override("font_size", 100)
	_dice_face_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_face_lbl.position = Vector2(0, 60)
	_dice_face_lbl.size = Vector2(700, 120)
	_dice_panel.add_child(_dice_face_lbl)

	_dice_result_lbl = Label.new()
	_dice_result_lbl.add_theme_font_size_override("font_size", 17)
	_dice_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_result_lbl.position = Vector2(30, 195)
	_dice_result_lbl.size = Vector2(640, 30)
	_dice_panel.add_child(_dice_result_lbl)

	_dice_detail_lbl = Label.new()
	_dice_detail_lbl.add_theme_font_size_override("font_size", 14)
	_dice_detail_lbl.modulate = Color(0.75, 0.75, 0.8)
	_dice_detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_detail_lbl.position = Vector2(30, 230)
	_dice_detail_lbl.size = Vector2(640, 50)
	_dice_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dice_panel.add_child(_dice_detail_lbl)

	_dice_status_lbl = Label.new()
	_dice_status_lbl.add_theme_font_size_override("font_size", 13)
	_dice_status_lbl.modulate = Color(0.6, 0.6, 0.65)
	_dice_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_status_lbl.position = Vector2(0, 288)
	_dice_status_lbl.size = Vector2(700, 26)
	_dice_panel.add_child(_dice_status_lbl)

	var sep = ColorRect.new()
	sep.color = Color(0.25, 0.22, 0.12, 0.6)
	sep.position = Vector2(40, 322)
	sep.size = Vector2(620, 1)
	_dice_panel.add_child(sep)

	var roll_btn = Button.new()
	roll_btn.name = "InitialRollBtn"
	roll_btn.text = "Tirar el dado"
	roll_btn.position = Vector2(200, 340)
	roll_btn.size = Vector2(300, 50)
	roll_btn.add_theme_font_size_override("font_size", 16)
	_style_btn(roll_btn, Color(0.2, 0.45, 0.2))
	roll_btn.pressed.connect(func(): _do_dice_roll(roll_btn))
	_dice_panel.add_child(roll_btn)

	_dice_reroll_btn = Button.new()
	_dice_reroll_btn.name = "RerollBtn"
	_dice_reroll_btn.text = "Lanzar de nuevo  (-%d HP)" % DICE_REROLL_COST
	_dice_reroll_btn.position = Vector2(60, 340)
	_dice_reroll_btn.size = Vector2(320, 50)
	_dice_reroll_btn.add_theme_font_size_override("font_size", 14)
	_style_btn(_dice_reroll_btn, Color(0.4, 0.22, 0.05))
	_dice_reroll_btn.visible = false
	_dice_reroll_btn.pressed.connect(func(): _do_dice_reroll())
	_dice_panel.add_child(_dice_reroll_btn)

	var cont_btn = Button.new()
	cont_btn.name = "ContinueBtn"
	cont_btn.text = "Continuar"
	cont_btn.position = Vector2(390, 340)
	cont_btn.size = Vector2(250, 50)
	cont_btn.add_theme_font_size_override("font_size", 14)
	_style_btn(cont_btn, Color(0.12, 0.12, 0.22))
	cont_btn.visible = false
	cont_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/Map.tscn"))
	_dice_panel.add_child(cont_btn)

	_update_dice_status()

func _do_dice_roll(initial_btn: Button) -> void:
	if _dice_rolling:
		return
	initial_btn.visible = false
	_start_roll_animation()

func _do_dice_reroll() -> void:
	if _dice_rolling:
		return
	GameManager.player_hp = max(1, GameManager.player_hp - DICE_REROLL_COST)
	_update_dice_status()
	_start_roll_animation()

func _start_roll_animation() -> void:
	_dice_rolling = true
	_dice_reroll_btn.visible = false
	var cont_btn = _dice_panel.get_node_or_null("ContinueBtn")
	if cont_btn:
		cont_btn.visible = false
	_dice_result_lbl.text = ""
	_dice_detail_lbl.text = ""

	var final_roll = randi_range(1, 6)

	var steps_fast = 8
	var steps_slow = 4
	var total_steps = steps_fast + steps_slow
	var tween = create_tween()

	for step in range(total_steps):
		var delay = 0.06 if step < steps_fast else 0.14
		var face_idx = randi() % 6
		if step == total_steps - 1:
			face_idx = final_roll - 1
		tween.tween_callback(func(): _dice_face_lbl.text = DICE_FACES[face_idx])
		tween.tween_interval(delay)

	tween.tween_callback(func(): _on_roll_settled(final_roll))

func _on_roll_settled(roll: int) -> void:
	_dice_rolling = false
	_dice_roll_count += 1

	var outcome = _dice_outcome(roll)
	_apply_dice_outcome(outcome)

	_dice_face_lbl.text = DICE_FACES[roll - 1]
	_dice_result_lbl.text = outcome["text"]
	_dice_result_lbl.modulate = outcome["color"]
	_dice_detail_lbl.text = outcome["detail"]
	_update_dice_status()

	var border_color: Color
	match outcome["type"]:
		"curse":   border_color = Color(0.75, 0.15, 0.15)
		"neutral": border_color = Color(0.35, 0.35, 0.4)
		_:         border_color = Color(0.2, 0.7, 0.3)

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.09, 0.98)
	ps.set_corner_radius_all(10)
	ps.set_border_width_all(2)
	ps.border_color = border_color
	_dice_panel.add_theme_stylebox_override("panel", ps)

	_dice_result_lbl.modulate.a = 0.0
	create_tween().tween_property(_dice_result_lbl, "modulate:a", 1.0, 0.35)

	var cont_btn = _dice_panel.get_node_or_null("ContinueBtn")
	if cont_btn:
		cont_btn.visible = true

	_dice_reroll_btn.visible = true
	_dice_reroll_btn.disabled = GameManager.player_hp <= DICE_REROLL_COST

func _dice_outcome(roll: int) -> Dictionary:
	match roll:
		1: return {
			"type": "curse",
			"text": "Maldicion — El tablero te castiga.",
			"detail": "Pierdes 10 HP.",
			"color": Color(0.9, 0.2, 0.2),
			"hp": -10
		}
		2: return {
			"type": "curse",
			"text": "Maldicion — Una pieza cae al vacio.",
			"detail": "La carta mas debil de tu mazo desaparece.",
			"color": Color(0.85, 0.3, 0.15),
			"remove_weak_card": true
		}
		3: return {
			"type": "neutral",
			"text": "El dado rueda sin gracia.",
			"detail": "Pierdes 4 HP.",
			"color": Color(0.6, 0.6, 0.65),
			"hp": -4
		}
		4: return {
			"type": "bonus",
			"text": "Ventaja — El alfil te senala.",
			"detail": "Ganas 12 monedas.",
			"color": Color(0.35, 0.85, 0.45),
			"coins": 12
		}
		5: return {
			"type": "bonus",
			"text": "Ventaja — La torre resiste.",
			"detail": "Recuperas 15 HP.",
			"color": Color(0.3, 0.8, 0.5),
			"heal": 15
		}
		6: return {
			"type": "bonus",
			"text": "Ventaja — La reina elige.",
			"detail": "Obtienes una reliquia aleatoria.",
			"color": Color(0.95, 0.82, 0.2),
			"relic": true
		}
	return {"type": "neutral", "text": "", "detail": "", "color": Color.WHITE}

func _apply_dice_outcome(outcome: Dictionary) -> void:
	if outcome.get("hp", 0) != 0:
		GameManager.player_hp = clamp(GameManager.player_hp + outcome["hp"], 1, GameManager.player_max_hp)

	if outcome.get("heal", 0) > 0:
		GameManager.heal(outcome["heal"])

	if outcome.get("coins", 0) > 0:
		GameManager.coins += outcome["coins"]

	if outcome.get("remove_weak_card", false) and GameManager.player_deck.size() > 1:
		var weakest_idx = 0
		var min_atk = GameManager.player_deck[0].get("attack", 0)
		for i in range(1, GameManager.player_deck.size()):
			var atk = GameManager.player_deck[i].get("attack", 0)
			if atk < min_atk:
				min_atk = atk
				weakest_idx = i
		var removed = GameManager.player_deck[weakest_idx]
		GameManager.player_deck.remove_at(weakest_idx)
		_dice_detail_lbl.text = "La carta '%s' ha sido eliminada." % removed["name"]

	if outcome.get("relic", false):
		var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
		if available.is_empty():
			_dice_detail_lbl.text = "Ya posees todas las reliquias. Recibes 15 monedas en su lugar."
			GameManager.coins += 15
		else:
			available.shuffle()
			GameManager.add_relic(available[0])
			var rname = GameManager.RELIC_DATA[available[0]]["name"]
			_dice_detail_lbl.text = "Obtienes: " + rname
			if get_node_or_null("/root/AudioManager"):
				AudioManager.play("relic_get")

func _update_dice_status() -> void:
	if _dice_status_lbl == null:
		return
	var base = "HP: %d/%d   |   Monedas: %d" % [
		GameManager.player_hp, GameManager.player_max_hp, GameManager.coins
	]
	if _dice_roll_count > 0:
		base += "   |   Lanzamientos: %d" % _dice_roll_count
	_dice_status_lbl.text = base
	var info = get_node_or_null("InfoLabel")
	if info:
		info.text = "HP: " + str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp) + "   Monedas: " + str(GameManager.coins)

func _style_btn(btn: Button, color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = color.lightened(0.3)
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate()
	h.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)

func _show_card_removal_screen() -> void:
	var vp = get_viewport_rect().size
	
	# Contenedor principal (oscurecimiento)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0) # Empieza invisible
	overlay.size = vp # Sizing manual
	overlay.z_index = 100
	add_child(overlay)
	
	# Tween para el fade-in del fondo
	var tw_bg = create_tween()
	tw_bg.tween_property(overlay, "color:a", 0.9, 0.4)
	
	# Panel Central Estilizado
	var panel = Panel.new()
	panel.size = Vector2(vp.x * 0.8, vp.y * 0.75)
	panel.position = (vp - panel.size) / 2
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	panel.pivot_offset = panel.size / 2
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.98)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.75, 0.2, 0.6) # Dorado tenue
	style.shadow_size = 30
	style.shadow_color = Color(0, 0, 0, 0.7)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	
	# Tween para el panel
	var tw_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_panel.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw_panel.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5)
	
	var title = Label.new()
	title.text = "ELIGE UNA PIEZA PARA OLVIDAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.9, 0.8, 0.4)
	title.position = Vector2(0, 30); title.size = Vector2(panel.size.x, 50)
	panel.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(50, 100)
	scroll.size = Vector2(panel.size.x - 100, panel.size.y - 200)
	panel.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 25)
	scroll.add_child(grid)
	
	var card_scene = load("res://scenes/combat/Card.tscn")
	for i in range(GameManager.player_deck.size()):
		var idx = i
		var card = card_scene.instantiate()
		grid.add_child(card)
		card.setup(GameManager.player_deck[i])
		card.scale = Vector2(0.85, 0.85)
		card.modulate.a = 0.0
		
		# Animación stagger para las cartas
		create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.2 + i * 0.05)
		
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameManager.player_deck.remove_at(idx)
				if get_node_or_null("/root/AudioManager"): AudioManager.play("card_discard")
				# Animación de salida
				var tw_out = create_tween()
				tw_out.tween_property(overlay, "modulate:a", 0.0, 0.3)
				await tw_out.finished
				get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
		)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "RETROCEDER"
	cancel_btn.size = Vector2(240, 50)
	cancel_btn.position = Vector2(panel.size.x/2 - 120, panel.size.y - 70)
	cancel_btn.pressed.connect(func(): 
		var tw_out = create_tween()
		tw_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
		await tw_out.finished
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)
	panel.add_child(cancel_btn)
