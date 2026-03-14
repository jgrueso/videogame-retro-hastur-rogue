extends Node2D

const VOID_ROOMS = [
	{"name": "Grieta del Vacío", "type": "combat"},
	{"name": "Grieta del Vacío", "type": "combat"},
	{"name": "Centinela del Abismo", "type": "boss"},
	{"name": "Bóveda de la Verdad", "type": "treasure"}
]

func _ready() -> void:
	var vp = get_viewport_rect().size
	
	# Fondo abisal profundo
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.0, 0.02)
	bg.size = vp
	add_child(bg)
	
	_create_nebula(vp)
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.stop_all()
		AudioManager.play_loop("Glith_distorsion_noised_sound")
		AudioManager.update_loop_params("Glith_distorsion_noised_sound", -15.0, 0.8)
	
	_build_map_ui(vp)

func _build_map_ui(vp: Vector2) -> void:
	var title = Label.new()
	title.text = "--- EL CAMINO DEL VACÍO ---"
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(0.2, 0.8, 1.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60); title.size = Vector2(vp.x, 50)
	add_child(title)

	var spacing = 200
	var start_x = (vp.x - (VOID_ROOMS.size() - 1) * spacing) / 2
	
	# Dibujar líneas primero
	for i in range(VOID_ROOMS.size() - 1):
		var p0 = Vector2(start_x + i * spacing, vp.y/2)
		var p1 = Vector2(start_x + (i + 1) * spacing, vp.y/2)
		var l = Line2D.new()
		l.add_point(p0); l.add_point(p1)
		l.width = 2.0
		l.default_color = Color(0.2, 0.6, 0.8, 0.3)
		l.z_index = 1
		add_child(l)

	# Dibujar nodos
	for i in range(VOID_ROOMS.size()):
		var room = VOID_ROOMS[i]
		var pos = Vector2(start_x + i * spacing, vp.y/2)
		
		var btn = Button.new()
		btn.text = room["name"]
		btn.size = Vector2(140, 45)
		btn.position = pos - btn.size / 2
		btn.add_theme_font_size_override("font_size", 11)
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_border_width_all(2)
		
		# Lógica de estado del nodo
		if i < GameManager.void_path_step:
			# Ya superado
			style.bg_color = Color(0.1, 0.1, 0.15)
			style.border_color = Color(0.3, 0.3, 0.4)
			btn.modulate.a = 0.5
			btn.disabled = true
		elif i == GameManager.void_path_step:
			# Nodo actual
			style.bg_color = Color(0.05, 0.3, 0.5)
			style.border_color = Color(0.4, 0.9, 1.0)
			_add_pulse_effect(btn)
		else:
			# Futuro
			style.bg_color = Color(0.02, 0.02, 0.05)
			style.border_color = Color(0.2, 0.2, 0.3)
			btn.disabled = true
			btn.modulate.a = 0.7

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		add_child(btn)
		
		if i == GameManager.void_path_step:
			var idx = i
			btn.pressed.connect(func(): _on_node_selected(idx))

func _on_node_selected(idx: int) -> void:
	if idx == 3: # El Tesoro final
		GameManager.is_in_void_path = false
		GameManager.is_vault_room = true
		GameManager.go_to_scene("res://scenes/ui/Treasure.tscn")
	else:
		# Combate o Jefe
		GameManager.go_to_scene("res://scenes/combat/Combat.tscn")

func _add_pulse_effect(node: Control) -> void:
	var tw = node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(1.05, 1.05), 0.6)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.6)

func _create_nebula(vp: Vector2) -> void:
	for i in range(15):
		var p = ColorRect.new()
		p.size = Vector2(randf_range(200, 500), randf_range(200, 500))
		p.color = Color(0.1, 0.0, 0.2, 0.05)
		p.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		var tw = p.create_tween().set_loops()
		tw.tween_property(p, "modulate:a", 0.15, 3.0)
		tw.tween_property(p, "modulate:a", 0.05, 3.0)
