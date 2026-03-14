extends Node2D

func _ready() -> void:
	pass

func setup_item_event(item_id: String) -> void:
	var item_data = GameManager.SECRET_ITEM_DATA.get(item_id, {})
	if item_data.is_empty():
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
		return

	var vp = get_viewport_rect().size
	var already_have = GameManager.has_secret_item(item_id)

	var situations = [
		{
			"header": "✦ CRIATURA AFERRADA ✦",
			"text": "Una masa de carne palida abraza el objeto. Sus cientos de bocas susurran tu nombre.\nDebes alimentarla con tu propia sangre para que lo suelte.",
			"cost_label": "Alimentar (-20% HP)",
			"type": "blood"
		},
		{
			"header": "✦ EL VACIO DEL OLVIDO ✦",
			"text": "El objeto flota en un portal de ceniza. Sientes que si metes la mano,\nparte de lo que eres se perdera para siempre en el otro lado.",
			"cost_label": "Meter la mano (-6 HP MAX)",
			"type": "max_hp"
		},
		{
			"header": "✦ EL SUSURRO PROHIBIDO ✦",
			"text": "El artefacto vibra con una melodia que te hiela los huesos.\nSi decides tomarlo, su verdad pesara en tu mente hasta el final.",
			"cost_label": "Escuchar (+ Maldicion)",
			"type": "curse"
		}
	]
	
	var sit = situations.pick_random()

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 20
	add_child(dim)

	var panel = Panel.new()
	panel.size = Vector2(600, 400)
	panel.position = (vp - panel.size) / 2
	panel.z_index = 21
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.02, 0.98); ps.set_corner_radius_all(8)
	ps.border_width_all = 2; ps.border_color = item_data.get("color", Color.YELLOW)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var name_lbl = Label.new()
	name_lbl.text = item_data.get("name", "Fragmento")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 40); name_lbl.size = Vector2(600, 40)
	name_lbl.modulate = item_data.get("color", Color.YELLOW)
	panel.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = sit["text"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.position = Vector2(50, 120); desc_lbl.size = Vector2(500, 100)
	panel.add_child(desc_lbl)

	var take_btn = Button.new()
	take_btn.text = sit["cost_label"]
	take_btn.position = Vector2(320, 300); take_btn.size = Vector2(200, 50)
	panel.add_child(take_btn)

	var back_btn = Button.new()
	back_btn.text = "Retroceder"
	back_btn.position = Vector2(80, 300); back_btn.size = Vector2(200, 50)
	panel.add_child(back_btn)

	if already_have:
		take_btn.disabled = true; take_btn.text = "Ya lo posees"

	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/Map.tscn"))
	take_btn.pressed.connect(func():
		match sit["type"]:
			"blood": GameManager.player_hp = max(1, GameManager.player_hp * 0.8)
			"max_hp": GameManager.player_max_hp = max(10, GameManager.player_max_hp - 6)
			"curse": GameManager.add_card({"name": "Peso de la Verdad", "attack": 0, "defense": 0, "cost": 1, "curse": true})
		GameManager.add_secret_item(item_id)
		get_tree().change_scene_to_file("res://scenes/ui/Map.tscn")
	)
