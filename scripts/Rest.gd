extends Node2D

func _ready() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo abisal
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Efecto de fuego fatuo (ceniza)
	_start_fire_effect(vp)
	
	build_ui()

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	var title = Label.new()
	title.text = "🕯 HOGUERA DE CENIZA 🕯"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.4, 0.7, 0.8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 60)
	add_child(title)

	var sub = Label.new()
	sub.text = "El calor es frio, pero reconfortante. ¿Que buscas en las brasas?"
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.6, 0.6, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 130); sub.size = Vector2(vp.x, 30)
	add_child(sub)
	
	var info = Label.new()
	info.text = "HP: " + str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp) + "   |   Energia: " + str(GameManager.player_max_energy)
	info.add_theme_font_size_override("font_size", 16)
	info.modulate = Color(0.8, 0.8, 0.8)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 165); info.size = Vector2(vp.x, 30)
	add_child(info)

	var btn_container = VBoxContainer.new()
	btn_container.position = Vector2(vp.x * 0.3, 220)
	btn_container.size = Vector2(vp.x * 0.4, 300)
	btn_container.add_theme_constant_override("separation", 25)
	add_child(btn_container)

	# --- BOTONES ---
	var btn_rest = _make_rest_button("🩹 DESCANSAR (Recupera 30% HP)")
	btn_rest.tooltip_text = "Tus heridas se cierran con ceniza fría.\nRecuperas vida según tu capacidad máxima."
	btn_rest.pressed.connect(_on_rest_pressed)
	btn_container.add_child(btn_rest)

	var btn_forge = _make_rest_button("🔨 FORJAR (Mejora una carta)")
	btn_forge.tooltip_text = "Refuerzas una de tus piezas del mazo actual.\nAumenta +3 el ATK y DEF de una carta al azar."
	btn_forge.pressed.connect(_on_forge_pressed)
	btn_container.add_child(btn_forge)

	var btn_sac = _make_rest_button("🌑 SACRIFICIO OSCURO (+1 Energia Max / -25 HP Max)")
	btn_sac.tooltip_text = "CAMBIO EQUIVALENTE.\nPierdes vitalidad permanente para ganar el poder de jugar más cartas cada turno."
	btn_sac.modulate = Color(0.8, 0.4, 0.4)
	btn_sac.disabled = GameManager.player_max_hp <= 30
	btn_sac.pressed.connect(_on_sacrifice_pressed)
	btn_container.add_child(btn_sac)

func _make_rest_button(txt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 65)
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _on_rest_pressed() -> void:
	var amount = int(GameManager.player_max_hp * 0.3)
	GameManager.player_hp = min(GameManager.player_hp + amount, GameManager.player_max_hp)
	_finish_rest()

func _on_forge_pressed() -> void:
	if GameManager.player_deck.is_empty():
		_finish_rest()
		return
	
	# Seleccionar una carta aleatoria del mazo para mejorar
	var deck = GameManager.player_deck
	var idx = randi() % deck.size()
	var card = deck[idx]
	
	if card is Dictionary:
		# Mejorar estadisticas si existen (+3 segun peticion del usuario)
		if card.has("attack"): 
			card["attack"] = int(card["attack"]) + 3
		if card.has("defense"): 
			card["defense"] = int(card["defense"]) + 3
		
		# Marcar como mejorada para Card.gd
		card["upgraded"] = true
		
		# Añadir un indicador visual al nombre si no lo tiene
		if card.has("name"):
			var c_name = str(card["name"])
			if not "+" in c_name:
				card["name"] = c_name + "+1" # Título verde +1 (según petición)
		
		print("Carta mejorada (+3): ", card.get("name", "Desconocida"))
	
	_finish_rest()

func _on_sacrifice_pressed() -> void:
	GameManager.player_max_energy += 1
	GameManager.player_max_hp -= 25
	GameManager.player_hp = min(GameManager.player_hp, GameManager.player_max_hp)
	_finish_rest()

func _finish_rest() -> void:
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("button_click")
	get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")

func _start_fire_effect(vp: Vector2) -> void:
	for i in range(40):
		var p = ColorRect.new()
		p.size = Vector2(randf_range(2, 5), randf_range(2, 5))
		p.color = Color(0.4, 0.7, 0.9, randf_range(0.1, 0.4)) # Fuego azul frio
		p.position = Vector2(randf_range(0, vp.x), vp.y + 10)
		add_child(p)
		var dur = randf_range(2.0, 4.0)
		var tw = create_tween().set_loops()
		tw.tween_property(p, "position:y", -20, dur).from(vp.y + 10)
		tw.parallel().tween_property(p, "position:x", p.position.x + randf_range(-100, 100), dur)
