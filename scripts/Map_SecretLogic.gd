	var situations = [
		{
			"header": "✦  CRIATURA AFFERADA  ✦",
			"text": "Una masa de carne palida abraza el objeto. Sus cientos de bocas susurran tu nombre.\nDebes alimentarla con tu propia sangre para que lo suelte.",
			"cost_label": "Alimentar ( -20% HP )",
			"type": "blood"
		},
		{
			"header": "✦  EL VACIO DEL OLVIDO  ✦",
			"text": "El objeto flota en un portal de ceniza. Sientes que si metes la mano,\nparte de lo que eres se perdera para siempre en el otro lado.",
			"cost_label": "Meter la mano ( -6 HP MAX )",
			"type": "max_hp"
		},
		{
			"header": "✦  EL SUSURRO PROHIBIDO  ✦",
			"text": "El artefacto vibra con una melodia que te hiela los huesos.\nSi decides tomarlo, su verdad pesara en tu mente hasta el final.",
			"cost_label": "Escuchar ( + Maldicion )",
			"type": "curse"
		}
	]
	
	var sit = situations[randi() % situations.size()]
	var item_data = GameManager.SECRET_ITEM_DATA[item_id]
	var vp = get_viewport_rect().size

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.92)
	dim.position = Vector2.ZERO; dim.size = vp
	dim.z_index = 20; dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel = Panel.new()
	panel.position = Vector2(276, 80); panel.size = Vector2(600, 420)
	panel.z_index = 21
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.03, 0.01, 0.98); ps.set_corner_radius_all(10)
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = item_data["color"]
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var header = Label.new()
	header.text = sit["header"]
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = Color(0.6, 0.5, 0.2)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 18); header.size = Vector2(600, 24)
	panel.add_child(header)

	var icon_lbl = Label.new()
	icon_lbl.text = item_data["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 84)
	icon_lbl.modulate = item_data["color"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.position = Vector2(0, 44); icon_lbl.size = Vector2(600, 110)
	panel.add_child(icon_lbl)

	var name_lbl = Label.new()
	name_lbl.text = item_data["name"]
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.modulate = Color(0.95, 0.85, 0.3)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 158); name_lbl.size = Vector2(600, 34)
	panel.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = sit["text"]
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.modulate = Color(0.7, 0.7, 0.75)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.position = Vector2(40, 205); desc_lbl.size = Vector2(520, 90)
	panel.add_child(desc_lbl)

	var leave_btn = Button.new()
	leave_btn.text = "Retroceder"
	leave_btn.position = Vector2(80, 340); leave_btn.size = Vector2(210, 48)
	panel.add_child(leave_btn)

	var take_btn = Button.new()
	take_btn.text = sit["cost_label"]
	take_btn.position = Vector2(310, 340); take_btn.size = Vector2(210, 48)
	take_btn.modulate = Color(1.0, 0.4, 0.4) if sit["type"] != "curse" else Color(0.8, 0.4, 1.0)
	panel.add_child(take_btn)

	if already_have:
		take_btn.disabled = true; take_btn.text = "Ya lo posees"

	var picked = false
	leave_btn.pressed.connect(func():
		if picked: return
		picked = true
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)

	take_btn.pressed.connect(func():
		if picked: return
		picked = true
		match sit["type"]:
			"blood": GameManager.player_hp = max(1, GameManager.player_hp * 0.8)
			"max_hp": 
				GameManager.player_max_hp = max(10, GameManager.player_max_hp - 6)
				GameManager.player_hp = min(GameManager.player_hp, GameManager.player_max_hp)
			"curse": 
				GameManager.add_card({"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true})
		
		GameManager.add_secret_item(item_id)
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)
