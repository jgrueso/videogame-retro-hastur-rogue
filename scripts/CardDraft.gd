extends Node2D
var card_pool: Array = [
	{"name": "Siervo Quebrado",    "attack": 2,  "defense": 0, "cost": 1},
	{"name": "Baluarte de Hueso",   "attack": 3,  "defense": 3, "cost": 2},
	{"name": "Cabalgante del Vacio", "attack": 4,  "defense": 0, "cost": 2},
	{"name": "Inquisidor Ciego",    "attack": 2,  "defense": 0, "cost": 2},
	{"name": "Dama del Tablero",    "attack": 6,  "defense": 2, "cost": 4},
	{"name": "Idolo Inerte",        "attack": 2,  "defense": 8, "cost": 4},
	{"name": "Ofrenda de Carne",    "attack": 8,  "defense": 0, "cost": 2},
	{"name": "Formacion",      "attack": 0,  "defense": 4, "cost": 1},
	{"name": "Gambito",        "attack": 5,  "defense": 0, "cost": 3},
	{"name": "Enroque",        "attack": 3,  "defense": 5, "cost": 3},
	# Cartas epicas
	{"name": "Jaque Eterno",   "attack": 0,  "defense": 0, "cost": 3},
	{"name": "Rompetablero",   "attack": 20, "defense": 0, "cost": 4},
	{"name": "Gran Maestro",   "attack": 8,  "defense": 6, "cost": 4},
	{"name": "Sacrificio del Rey", "attack": 12, "defense": 0, "cost": 2},
]

var chosen: bool = false
var cards_container: HBoxContainer

signal draft_completed

func _ready() -> void:
	modulate.a = 0.0
	build_ui()
	show_draft()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo de velo oscuro para separar del combate
	var veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0.85)
	veil.size = vp
	add_child(veil)

	# Panel central decorativo
	var panel = Panel.new()
	panel.size = Vector2(800, 500)
	panel.position = (vp - panel.size) / 2
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.35, 0.1) # Oro viejo
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var title = Label.new()
	title.text = "RECOLECTAR ECO"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.85, 0.75, 0.2)
	title.position = Vector2(0, 30); title.size = Vector2(800, 50)
	panel.add_child(title)

	var sub_title = Label.new()
	sub_title.text = "Una pieza del pasado busca un nuevo tablero."
	sub_title.add_theme_font_size_override("font_size", 14)
	sub_title.modulate = Color(0.6, 0.6, 0.6)
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_title.position = Vector2(0, 80); sub_title.size = Vector2(800, 30)
	panel.add_child(sub_title)

	cards_container = HBoxContainer.new()
	cards_container.position = Vector2(165, 140)
	cards_container.size = Vector2(470, 195)
	cards_container.add_theme_constant_override("separation", 40)
	panel.add_child(cards_container)

	var skip_btn = Button.new()
	skip_btn.text = "DEJAR QUE EL ECO SE EXTINGA (Omitir)"
	skip_btn.position = Vector2(250, 400); skip_btn.size = Vector2(300, 45)
	skip_btn.add_theme_font_size_override("font_size", 13)
	skip_btn.modulate = Color(0.7, 0.3, 0.3)
	skip_btn.pressed.connect(_on_skip)
	panel.add_child(skip_btn)

func show_draft() -> void:
	var choices = CardData.get_draft_cards(3, GameManager.selected_character)

	var epic_names = ["Jaque Eterno", "Rompetablero", "Gran Maestro", "Sacrificio del Rey"]
	for i in range(3):
		var card_scene = preload("res://scenes/combat/Card.tscn")
		var card = card_scene.instantiate()
		cards_container.add_child(card)
		card.setup(choices[i])
		card.requires_target = false
		card.hover_scale_enabled = false
		card.glow_enabled = true
		var delay = i * 0.15
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.25).set_delay(delay)
		create_tween().tween_callback(card.flash_new_card).set_delay(delay + 0.25)
		if choices[i]["name"] in epic_names:
			var s = StyleBoxFlat.new()
			s.bg_color = Color(0.15, 0.1, 0.05)
			s.set_corner_radius_all(6)
			s.border_width_left = 2
			s.border_width_right = 2
			s.border_width_top = 2
			s.border_width_bottom = 2
			s.border_color = Color(0.9, 0.7, 0.1)
			card.add_theme_stylebox_override("panel", s)
		var data = choices[i]
		card.connect("card_played", func(_c): _on_card_chosen(data))

func _on_card_chosen(card_data: Dictionary) -> void:
	if chosen:
		return
	chosen = true
	GameManager.add_card(card_data)
	draft_completed.emit()
	queue_free()

func _on_skip() -> void:
	if chosen:
		return
	chosen = true
	draft_completed.emit()
	queue_free()
