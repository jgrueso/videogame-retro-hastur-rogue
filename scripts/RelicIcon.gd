extends Panel

var relic_id: String = ""

const RELIC_COLORS = {
	"ficha_marfil":     Color(0.9, 0.85, 0.4),
	"escudo_astillado": Color(0.4, 0.6, 0.9),
	"ojo_oraculo":      Color(0.7, 0.3, 0.9),
	"sangre_caido":     Color(0.8, 0.2, 0.2),
	"velo_dama":        Color(0.8, 0.5, 0.9),
	"espejo_fragmentado": Color(0.5, 0.9, 0.9),
	"corona_espinas":   Color(0.6, 0.15, 0.15),
	"reloj_roto":       Color(0.6, 0.8, 0.5),
}

const RELIC_ICONS = {
	"ficha_marfil":     "F",
	"escudo_astillado": "E",
	"ojo_oraculo":      "O",
	"sangre_caido":     "S",
	"velo_dama":        "V",
	"espejo_fragmentado": "M",
	"corona_espinas":   "C",
	"reloj_roto":       "R",
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

	# Tooltip
	tooltip_panel = Panel.new()
	tooltip_panel.size = Vector2(180, 70)
	tooltip_panel.position = Vector2(0, 48)
	tooltip_panel.visible = false
	tooltip_panel.z_index = 20

	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	ts.set_corner_radius_all(5)
	ts.border_width_left = 1
	ts.border_width_right = 1
	ts.border_width_top = 1
	ts.border_width_bottom = 1
	ts.border_color = color
	tooltip_panel.add_theme_stylebox_override("panel", ts)

	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = color.lightened(0.3)
	name_lbl.position = Vector2(8, 5)
	name_lbl.size = Vector2(164, 20)
	tooltip_panel.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.position = Vector2(8, 26)
	desc_lbl.size = Vector2(164, 40)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_panel.add_child(desc_lbl)

	add_child(tooltip_panel)

	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(func(): tooltip_panel.visible = true)
	mouse_exited.connect(func(): tooltip_panel.visible = false)
