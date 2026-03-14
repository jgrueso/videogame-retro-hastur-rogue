extends Panel

var relic_id: String = ""

const RELIC_COLORS = {
	"ficha_marfil":       Color(0.9, 0.85, 0.4),
	"escudo_astillado":   Color(0.4, 0.6, 0.9),
	"ojo_oraculo":        Color(0.7, 0.3, 0.9),
	"sangre_caido":       Color(0.8, 0.2, 0.2),
	"velo_dama":          Color(0.8, 0.5, 0.9),
	"espejo_fragmentado": Color(0.5, 0.9, 0.9),
	"corona_espinas":     Color(0.6, 0.15, 0.15),
	"reloj_roto":         Color(0.6, 0.8, 0.5),
	"ojo_grito":          Color(0.8, 0.2, 0.3),
	"manual_anatomista":  Color(0.55, 0.75, 0.55),
	"ojo_arrancado":      Color(0.9, 0.55, 0.1),
}

const RELIC_ICONS = {
	"ficha_marfil":       "F",
	"escudo_astillado":   "E",
	"ojo_oraculo":        "O",
	"sangre_caido":       "S",
	"velo_dama":          "V",
	"espejo_fragmentado": "M",
	"corona_espinas":     "C",
	"reloj_roto":         "R",
	"ojo_grito":          "G",
	"manual_anatomista":  "A",
	"ojo_arrancado":      "J",
}

var tooltip_panel: Panel

func setup(id: String) -> void:
	relic_id = id
	var data = GameManager.RELIC_DATA[id]

	custom_minimum_size = Vector2(44, 44)
	size = Vector2(44, 44)

	# Circulo de fondo
	var color = RELIC_COLORS.get(id, Color(0.5, 0.5, 0.5))
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color.lightened(0.4)
	add_theme_stylebox_override("panel", style)

	# Letra del icono centrada
	var icon_lbl = Label.new()
	icon_lbl.text = RELIC_ICONS.get(id, "?")
	icon_lbl.add_theme_font_size_override("font_size", 18)
	icon_lbl.modulate = Color(0.05, 0.05, 0.05)
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(icon_lbl)

	# Detectar si es el Velo y está roto
	if id == "velo_dama" and GameManager.velo_broken:
		modulate = Color(0.4, 0.4, 0.4, 0.7) # Oscurecer
		var cross = Label.new()
		cross.text = "✕"
		cross.modulate = Color(1, 0, 0)
		cross.add_theme_font_size_override("font_size", 32)
		cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(cross)

	# Tooltip
	tooltip_panel = Panel.new()
	var tw = 240 # Un poco más ancho para mejor lectura
	
	# Configurar labels primero para medir el contenido
	var name_lbl = Label.new()
	name_lbl.text = data["name"].to_upper()
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.modulate = color.lightened(0.4)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.size = Vector2(tw - 20, 25)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size = Vector2(tw - 20, 10) # Altura inicial pequeña, crecerá con autowrap si se usa en contenedor o calculamos
	
	# Cálculo de altura manual más robusto
	var lines = desc_lbl.text.length() / 28.0 + desc_lbl.text.count("\n") + 1
	var th = max(80, lines * 16 + 45)
	
	tooltip_panel.size = Vector2(tw, th)
	tooltip_panel.z_index = 600 # Por encima de todo
	tooltip_panel.visible = false
	
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.02, 0.02, 0.04, 0.98)
	ts.set_corner_radius_all(6)
	ts.set_border_width_all(2)
	ts.border_color = color
	ts.shadow_size = 15
	tooltip_panel.add_theme_stylebox_override("panel", ts)

	name_lbl.position = Vector2(10, 10)
	desc_lbl.position = Vector2(10, 35)
	desc_lbl.size.y = th - 45
	
	tooltip_panel.add_child(name_lbl)
	tooltip_panel.add_child(desc_lbl)
	add_child(tooltip_panel)

	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(_show_tooltip)
	mouse_exited.connect(func(): tooltip_panel.visible = false)

func mark_broken() -> void:
	modulate = Color(0.4, 0.4, 0.4, 0.7)
	if not get_node_or_null("BrokenCross"):
		var cross = Label.new()
		cross.name = "BrokenCross"
		cross.text = "✕"
		cross.modulate = Color(1, 0, 0)
		cross.add_theme_font_size_override("font_size", 32)
		cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(cross)

func _show_tooltip() -> void:
	var vp = get_viewport_rect().size
	var global_pos = global_position
	
	# Posición base: encima de la reliquia
	var target_pos = Vector2(-tooltip_panel.size.x / 2 + size.x / 2, -tooltip_panel.size.y - 10)
	
	# Ajuste de bordes laterales (evitar que se salga por los lados)
	var final_global_x = global_pos.x + target_pos.x
	if final_global_x < 10:
		target_pos.x += (10 - final_global_x)
	elif final_global_x + tooltip_panel.size.x > vp.x - 10:
		target_pos.x -= (final_global_x + tooltip_panel.size.x - (vp.x - 10))
		
	# Si se sale por arriba, mostrarlo debajo
	if global_pos.y + target_pos.y < 10:
		target_pos.y = size.y + 10
		
	tooltip_panel.position = target_pos
	tooltip_panel.visible = true
