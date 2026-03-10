extends Panel

var card_name: String = ""
var attack: int = 0
var defense: int = 0
var cost: int = 1
var description: String = ""
var is_disabled: bool = false
var is_upgraded: bool = false
var cost_modifier: int = 0

var label_name: Label
var label_attack: Label
var label_defense: Label
var label_cost: Label
var tooltip_panel: Panel

var base_y: float = 0.0
var is_hovered: bool = false
var requires_target: bool = true

const DESCRIPTIONS = {
	"Siervo Quebrado":    "Carne de canon. Hace dano basico mientras espera su final.",
	"Baluarte de Hueso":   "Una defensa tallada en restos. Dano y proteccion.",
	"Cabalgante del Vacio": "No conoce muros. Ignora el escudo del enemigo.",
	"Inquisidor Ciego":    "Fe retorcida. Devuelve el ultimo ataque sufrido.",
	"Dama del Tablero":    "La favorita. Dano, escudo y energia extra.",
	"Idolo Inerte":        "Un trono vacio. Escudo masivo y recupera cordura.",
	"Ofrenda de Carne":    "Dano brutal, pero te cuesta vida jugarla.",
	"Formacion":         "Muro de escudos. Sin capacidad ofensiva.",
	"Gambito":           "Apuesta arriesgada. Mas energia gastada, mas dano.",
	"Enroque":           "Equilibrio entre ataque y defensa.",
	"Peso de la Verdad":   "CONOCIMIENTO PROHIBIDO. Te drena la vida al usarla.",
	# Epicas
	"Jaque Eterno":        "EPICA. Canaliza tu dolor. Dano segun HP perdido.",
	"Rompetablero":        "EPICA. Aniquila escudos y golpea el alma enemiga.",
	"Gran Maestro":        "EPICA. La jugada perfecta. Dano, escudo y energia.",
	"Sacrificio del Rey":  "EPICA. Golpe desesperado. Dano masivo a un alto coste.",
	"Susurro Debilitante": "NEUTRAL. Reduce el proximo ataque enemigo. Poder x2 si es tu ULTIMA carta.",
	"Maldición de Ceniza": "MALDICIÓN. Una pieza corrompida por el Avatar. No tiene efecto, solo ocupa espacio.",
	"Eco del Vacío":       "NEUTRAL. Golpe de ceniza que afecta a TODOS los enemigos simultaneamente.",
	"Eco del Vacio":       "NEUTRAL. Golpe de ceniza que afecta a TODOS los enemigos simultaneamente.",
	"Ecos del Vacío":      "NEUTRAL. Golpe de ceniza que afecta a TODOS los enemigos simultaneamente.",
	"Ecos del Vacio":      "NEUTRAL. Golpe de ceniza que afecta a TODOS los enemigos simultaneamente.",

}

signal card_played(card)
signal card_selected(card)

func _ready() -> void:
	custom_minimum_size = Vector2(130, 195)
	mouse_filter = MOUSE_FILTER_STOP
	pivot_offset = Vector2(65, 97)
	z_index = 5 # Siempre sobre el fondo

	# Nombre (header)
	label_name = Label.new()
	label_name.position = Vector2(8, 8)
	label_name.size = Vector2(114, 40)
	label_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_name.add_theme_font_size_override("font_size", 13)
	label_name.modulate = Color(0.9, 0.85, 0.6) # Tono pergamino
	add_child(label_name)

	# Separador bajo el nombre
	var sep = ColorRect.new()
	sep.position = Vector2(8, 48)
	sep.size = Vector2(114, 1)
	sep.color = Color(0.5, 0.45, 0.2, 0.6)
	add_child(sep)

	# ATK en rojo oscuro
	label_attack = Label.new()
	label_attack.position = Vector2(8, 55)
	label_attack.add_theme_font_size_override("font_size", 13)
	label_attack.modulate = Color(0.8, 0.3, 0.3)
	add_child(label_attack)

	# DEF en azul acero
	label_defense = Label.new()
	label_defense.position = Vector2(8, 78)
	label_defense.add_theme_font_size_override("font_size", 13)
	label_defense.modulate = Color(0.4, 0.6, 0.8)
	add_child(label_defense)

	# Separador sobre el costo
	var sep2 = ColorRect.new()
	sep2.position = Vector2(8, 145)
	sep2.size = Vector2(114, 1)
	sep2.color = Color(0.5, 0.45, 0.2, 0.6)
	add_child(sep2)

	label_cost = Label.new()
	label_cost.position = Vector2(8, 152)
	label_cost.add_theme_font_size_override("font_size", 13)
	add_child(label_cost)

	# Icono Central de la Carta
	var icon_lbl = Label.new()
	icon_lbl.name = "IconLabel"
	icon_lbl.add_theme_font_size_override("font_size", 54)
	icon_lbl.modulate = Color(1, 1, 1, 0.15) # Muy sutil, como una marca de agua
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.position = Vector2(0, 50); icon_lbl.size = Vector2(130, 100)
	add_child(icon_lbl)

	tooltip_panel = Panel.new()
	tooltip_panel.size = Vector2(180, 110)
	tooltip_panel.position = Vector2(135, -5)
	tooltip_panel.visible = false
	tooltip_panel.z_index = 10
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	style.set_corner_radius_all(6)
	style.border_width_left = 2; style.border_color = Color(0.7, 0.6, 0.2)
	tooltip_panel.add_theme_stylebox_override("panel", style)

	var tooltip_label = Label.new()
	tooltip_label.name = "TooltipLabel"
	tooltip_label.position = Vector2(10, 8)
	tooltip_label.size = Vector2(160, 94)
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_label.add_theme_font_size_override("font_size", 12)
	tooltip_panel.add_child(tooltip_label)
	add_child(tooltip_panel)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	_apply_style(Color(0.08, 0.08, 0.12))

func setup(data: Dictionary) -> void:
	var raw_name = data.get("name", "")
	card_name = raw_name.to_upper()
	attack = data.get("attack", 0)
	defense = data.get("defense", 0)
	cost = data.get("cost", 1)
	
	# Detectar y guardar mejora
	is_upgraded = data.get("upgraded", false) or "+" in raw_name
	
	# Limpiar el nombre base para buscar la descripcion (ej: "Siervo Quebrado+1" -> "Siervo Quebrado")
	var real_name = raw_name
	if "+" in real_name:
		real_name = real_name.split("+")[0].strip_edges()
	
	description = DESCRIPTIONS.get(real_name, "Sin descripcion.")
	
	# Pasiva Estratega (Tooltip)
	if GameManager.selected_character == "estratega" and "INQUISIDOR" in card_name:
		description += "\n\n[LÓGICA: Coste -1]"
	
	requires_target = (attack > 0 or real_name == "Jaque Eterno") and real_name != "Eco del Vacio" and real_name != "Eco del Vacío"
	update_display()

func update_display(force_upgrade_style: bool = false) -> void:
	if not label_name:
		return
	label_name.text = card_name
	
	var active_upgraded = is_upgraded or force_upgrade_style
	
	if active_upgraded:
		label_name.modulate = Color(0.2, 1.0, 0.2) # Verde brillante
		
		# Mostrar mejora segun tipo de carta
		if "SUSURRO" in card_name:
			label_attack.text = "✖ DEB: " + str(6 + attack)
			label_attack.modulate = Color(0.3, 0.9, 0.3)
		elif "ECO" in card_name:
			label_attack.text = "⚔ ATK: " + str(4 + attack)
			label_attack.modulate = Color(0.3, 0.9, 0.3)
		else:
			if attack > 0:
				var total_atk = attack
				if GameManager.selected_character == "conquistador" and "SIERVO" in card_name:
					total_atk += GameManager.siervo_atk_bonus_perm
				label_attack.text = "⚔ ATK: " + str(total_atk)
				label_attack.modulate = Color(0.3, 0.9, 0.3)
			if defense > 0:
				label_defense.text = "🛡 DEF: " + str(defense)
				label_defense.modulate = Color(0.3, 0.9, 0.3)
	else:
		label_name.modulate = Color(0.9, 0.85, 0.6)
		
		if "SUSURRO" in card_name:
			label_attack.text = "✖ DEB: 6"
			label_attack.modulate = Color(0.6, 0.4, 0.7)
		elif "ECO" in card_name:
			label_attack.text = "⚔ ATK: 4"
			label_attack.modulate = Color(0.8, 0.3, 0.3)
		else:
			var total_atk = attack
			if GameManager.selected_character == "conquistador" and "SIERVO" in card_name:
				total_atk += GameManager.siervo_atk_bonus_perm
			
			label_attack.text = "⚔ ATK: " + str(total_atk) if total_atk > 0 else ""
			label_attack.modulate = Color(0.8, 0.3, 0.3)
			label_defense.text = "🛡 DEF: " + str(defense) if defense > 0 else ""
			label_defense.modulate = Color(0.4, 0.6, 0.8)

	tooltip_panel.get_node("TooltipLabel").text = description
	
	# Actualizar Icono Central
	var icon_lbl = get_node("IconLabel")
	match card_name:
		"SIERVO QUEBRADO":    icon_lbl.text = "♙"
		"BALUARTE DE HUESO":   icon_lbl.text = "♖"
		"CABALGANTE DEL VACIO": icon_lbl.text = "♘"
		"INQUISIDOR CIEGO":    icon_lbl.text = "♗"
		"DAMA DEL TABLERO":    icon_lbl.text = "♕"
		"IDOLO INERTE":        icon_lbl.text = "♔"
		"OFRENDA DE CARNE":    icon_lbl.text = "🥩"
		_: icon_lbl.text = "✦"
	
	_update_cost_label()

func get_effective_cost() -> int:
	return max(0, cost + cost_modifier)

func _update_cost_label() -> void:
	var effective = max(0, cost + cost_modifier)
	label_cost.text = "COSTO: " + str(effective)
	
	if cost_modifier < 0:
		label_cost.modulate = Color(0.3, 1.0, 0.3)
	elif cost_modifier > 0:
		label_cost.modulate = Color(1.0, 0.3, 0.3)
	else:
		label_cost.modulate = Color(0.85, 0.75, 0.2)

func set_cost_modifier(mod: int) -> void:
	cost_modifier = mod
	# No sumamos el coste aqui, se calcula en effective arriba
	_update_cost_label()

func set_disabled(value: bool) -> void:
	is_disabled = value
	if value:
		_apply_style(Color(0.04, 0.04, 0.06)) # Muy oscuro (desactivado)
		tooltip_panel.visible = false
		if is_hovered:
			_animate_hover(false)
	else:
		_apply_style(Color(0.12, 0.12, 0.15)) # Color base (activado)

func _apply_style(color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	
	# Borde segun tipo de carta
	if "SUSURRO" in card_name or "ECO" in card_name:
		style.border_color = Color(0.5, 0.4, 0.6) # Purpura místico para especiales
	elif cost == 0:
		style.border_color = Color(0.5, 0.5, 0.5) # Gris para coste 0
	else:
		style.border_color = Color(0.45, 0.4, 0.25) # Hueso/Oxido normal
		
	add_theme_stylebox_override("panel", style)

func _animate_hover(entering: bool) -> void:
	is_hovered = entering
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if entering:
		tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.15)
	else:
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)

func _on_mouse_entered() -> void:
	if not is_disabled:
		_apply_style(Color(0.35, 0.35, 0.1))
		_animate_hover(true)
		tooltip_panel.visible = true
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("card_hover")

func _on_mouse_exited() -> void:
	if not is_disabled:
		_apply_style(Color(0.12, 0.12, 0.15))
		_animate_hover(false)
	tooltip_panel.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if is_disabled:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tooltip_panel.visible = false
			is_disabled = true
			if requires_target:
				card_selected.emit(self)
			else:
				await play_attack_animation()
				card_played.emit(self)

func animate_draw(start_pos: Vector2, delay: float) -> void:
	# Convertir start_pos (global mazo) a local del contenedor
	var parent_node = get_parent()
	var local_start = start_pos - parent_node.global_position
	
	# Colocar inicialmente en el mazo (coordenadas locales)
	position = local_start
	modulate.a = 0.0
	scale = Vector2(0.1, 0.1)
	rotation = randf_range(-0.4, 0.4)
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# No animamos 'position' aqui porque reorganize_hand lo hará simultáneamente
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_delay(delay)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_delay(delay)
	tw.tween_property(self, "rotation", 0.0, 0.6).set_delay(delay)
func play_attack_animation(target_pos: Vector2 = Vector2.ZERO) -> void:
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("card_play")
	
	var tw = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	if target_pos != Vector2.ZERO:
		# Volar hacia el enemigo
		tw.tween_property(self, "global_position", target_pos, 0.2)
		tw.tween_property(self, "scale", Vector2(0.4, 0.4), 0.2)
	else:
		# Efecto de "gasto" hacia el centro/arriba
		tw.tween_property(self, "position:y", position.y - 150, 0.25)
		tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
		tw.chain().tween_property(self, "scale", Vector2(0.0, 0.0), 0.1)
	
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
