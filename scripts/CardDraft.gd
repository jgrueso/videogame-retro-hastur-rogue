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

func _ready() -> void:
	modulate.a = 0.0
	build_ui()
	show_draft()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

func build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "Elige una carta"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60)
	title.size = Vector2(1152, 60)
	add_child(title)

	var combat_label = Label.new()
	combat_label.text = "Combate " + str(GameManager.combat_count) + "  |  Monedas: " + str(GameManager.coins)
	combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_label.position = Vector2(0, 120)
	combat_label.size = Vector2(1152, 40)
	add_child(combat_label)

	cards_container = HBoxContainer.new()
	# 3 cartas x 130px + 2 separadores x 40px = 470px → centrado en 1152px
	cards_container.position = Vector2(341, 200)
	cards_container.size = Vector2(470, 195)
	cards_container.add_theme_constant_override("separation", 40)
	add_child(cards_container)

	var skip_btn = Button.new()
	skip_btn.text = "Omitir recompensa"
	skip_btn.position = Vector2(426, 510)
	skip_btn.size = Vector2(300, 40)
	skip_btn.add_theme_font_size_override("font_size", 13)
	skip_btn.modulate = Color(0.6, 0.6, 0.6)
	skip_btn.pressed.connect(_on_skip)
	add_child(skip_btn)

func show_draft() -> void:
	var pool = card_pool.duplicate()
	pool.shuffle()
	var choices = pool.slice(0, 3)

	var epic_names = ["Jaque Eterno", "Rompetablero", "Gran Maestro", "Sacrificio del Rey"]
	for i in range(3):
		var card_scene = preload("res://scenes/combat/Card.tscn")
		var card = card_scene.instantiate()
		cards_container.add_child(card)
		card.setup(choices[i])
		card.requires_target = false  # No hay enemigos que apuntar en el draft
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
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")

func _on_skip() -> void:
	if chosen:
		return
	chosen = true
	get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
