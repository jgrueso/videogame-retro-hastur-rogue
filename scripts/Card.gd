extends Panel

var card_name: String = ""
var attack: int = 0
var defense: int = 0
var cost: int = 1
var description: String = ""
var flavor: String = ""
var exhaust: bool = false
var card_data: Dictionary = {}
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
var is_marked: bool = false
var requires_target: bool = true
var base_scale: Vector2 = Vector2(1.0, 1.0)
var hover_scale_enabled: bool = true
var glow_enabled: bool = false

const DESCRIPTIONS = {
	"Siervo Quebrado":    "Carne de cañón. Hace daño básico mientras espera su final.",
	"Baluarte de Hueso":   "Una defensa tallada en restos. Daño y proteccion.",
	"Cabalgante del Vacio": "No conoce muros. Ignora el escudo del enemigo.",
	"Inquisidor Ciego":    "Fé retorcida. Devuelve el ultimo ataque sufrido.",
	"Dama del Tablero":    "La favorita. Daño, escudo y energia extra.",
	"Idolo Inerte":        "Un trono vacio. Escudo masivo y recupera cordura.",
	"Ofrenda de Carne":    "Daño brutal, pero te cuesta vida jugarla.",
	"Formacion":         "Muro de escudos. Sin capacidad ofensiva.",
	"Gambito":           "Apuesta arriesgada. Mas energia gastada, más daño.",
	"Enroque":           "Equilibrio entre ataque y defensa.",
	"Peso de la Verdad":   "CONOCIMIENTO PROHIBIDO. Pierdes 6 HP al usarla.",
	"Contraataque":      "REACCIÓN. Devuelve parte del golpe sufrido con furia acumulada.",
	"Analisis Profundo":  "LÓGICA. Observas el patrón. Robas 2 cartas adicionales.",
	"Pawn Promocionado":  "PODER. Un peón que alcanzó el final del tablero. Daño y defensa equilibrados.",
	"Gambito de Dama":    "ESTRATEGIA. Gran daño a cambio de una posición arriesgada.",
	# Mahar, el Cruzado
	"Golpe del Cruzado":  "6 ATK. Un golpe directo, sin adornos.",
	"Escudo de la Fe":    "8 Escudo. La defensa como acto de devocion.",
	"Reliquia Rota":      "4 ATK + 4 Escudo. Aun sirve. Aun duele.",
	# Principe de Carcosa
	"Susurro del Vacio":  "ABISAL. Escala con tu LOCURA. Daño x2 si tienes menos de 35 Cordura.",
	"Daga de Cristal":    "ABISAL. Un golpe rápido que ignora parte del escudo.",
	"Espejo Roto":        "ABISAL. Defensa que escala con tu LOCURA. El doble de efectiva en trance.",
	"Abrazo de la Locura": "ABISAL. Gran daño pero te cuesta 10 de Cordura al usarla.",
	# Epicas
	"Jaque Eterno":        "ÉPICA. Canaliza tu dolor. Daño segun HP perdido.",
	"Rompetablero":        "ÉPICA. Aniquila escudos y golpea el alma enemiga.",
	"Gran Maestro":        "ÉPICA. La jugada perfecta. Daño, escudo y energia.",
	"Sacrificio del Rey":  "ÉPICA. Golpe desesperado. Daño masivo a un alto coste.",
	"Susurro Debilitante": "NEUTRAL. Debilita a TODOS. Poder x2 si es tu ULTIMA carta. Si no, descarta otra pieza al azar.",
	"Maldición de Ceniza": "MALDICIÓN. Una pieza corrompida por el Avatar. No tiene efecto, solo ocupa espacio.",
	"Plegaria de Ceniza":  "ÚNICA. Un susurro de paz en el tablero. Otorga 12 de Escudo por Coste 0.",
	"Eco del Vacío":       "NEUTRAL. Golpe de ceniza que afecta a TODOS los enemigos simultaneamente.",
	"Apocalipsis":        "LEGENDARIA. Daño colosal (30) a TODOS. Cuesta 5 de Cordura.",
	"Signo Amarillo":     "LEGENDARIA. Una bendición maldita. +50 Cordura.\n[Efecto ACUMULATIVO: +1 Energía Max | +25% daño recibido]",
	"Trono de Carcosa":    "LEGENDARIA. 10 Daño y 12 Escudo. ATURDE al enemigo golpeado.",
}

signal card_played(card)
signal card_selected(card)

func _ready() -> void:
	# Capturar la escala actual como la base (importante para el visor de mazo)
	base_scale = scale
	custom_minimum_size = Vector2(130, 195)
	mouse_filter = MOUSE_FILTER_STOP
	pivot_offset = Vector2(65, 97)
	z_index = 5

	# Nombre (header)
	label_name = Label.new()
	label_name.position = Vector2(8, 8); label_name.size = Vector2(114, 40)
	label_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_name.add_theme_font_size_override("font_size", 13)
	label_name.modulate = Color(0.9, 0.85, 0.6)
	add_child(label_name)

	var sep = ColorRect.new()
	sep.position = Vector2(8, 48); sep.size = Vector2(114, 1)
	sep.color = Color(0.5, 0.45, 0.2, 0.6)
	add_child(sep)

	label_attack = Label.new()
	label_attack.position = Vector2(8, 55); label_attack.add_theme_font_size_override("font_size", 13)
	label_attack.modulate = Color(0.8, 0.3, 0.3)
	add_child(label_attack)

	label_defense = Label.new()
	label_defense.position = Vector2(8, 78); label_defense.add_theme_font_size_override("font_size", 13)
	label_defense.modulate = Color(0.4, 0.6, 0.8)
	add_child(label_defense)

	var sep2 = ColorRect.new()
	sep2.position = Vector2(8, 145); sep2.size = Vector2(114, 1)
	sep2.color = Color(0.5, 0.45, 0.2, 0.6)
	add_child(sep2)

	label_cost = Label.new()
	label_cost.position = Vector2(8, 152); label_cost.add_theme_font_size_override("font_size", 13)
	add_child(label_cost)

	var icon_lbl = Label.new()
	icon_lbl.name = "IconLabel"
	icon_lbl.add_theme_font_size_override("font_size", 54)
	icon_lbl.modulate = Color(1, 1, 1, 0.15)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.position = Vector2(0, 50); icon_lbl.size = Vector2(130, 100)
	add_child(icon_lbl)

	tooltip_panel = Panel.new()
	tooltip_panel.size = Vector2(200, 140); tooltip_panel.position = Vector2(135, -5)
	tooltip_panel.visible = false; tooltip_panel.z_index = 10
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	style.set_corner_radius_all(6)
	style.border_width_left = 2; style.border_color = Color(0.7, 0.6, 0.2)
	tooltip_panel.add_theme_stylebox_override("panel", style)

	var tooltip_label = RichTextLabel.new()
	tooltip_label.name = "TooltipLabel"
	tooltip_label.position = Vector2(10, 8); tooltip_label.size = Vector2(180, 124)
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = false # Cambiamos a false para controlar el tamaño nosotros
	tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	tooltip_panel.add_child(tooltip_label)
	add_child(tooltip_panel)

	var fervor_badge = Label.new()
	fervor_badge.name = "FervorBadge"
	fervor_badge.position = Vector2(8, 100)
	fervor_badge.size = Vector2(114, 18)
	fervor_badge.add_theme_font_size_override("font_size", 10)
	fervor_badge.visible = false
	add_child(fervor_badge)

	var ctx_badge = Label.new()
	ctx_badge.name = "ContextBadge"
	ctx_badge.position = Vector2(8, 118)
	ctx_badge.size = Vector2(114, 18)
	ctx_badge.add_theme_font_size_override("font_size", 10)
	ctx_badge.visible = false
	add_child(ctx_badge)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	_apply_style(Color(0.08, 0.08, 0.12))
	if card_name != "": update_display()

func setup(data: Dictionary) -> void:
	card_data = data
	var raw_name = data.get("name", "")
	card_name = raw_name.to_upper()
	attack = data.get("attack", 0)
	defense = data.get("defense", 0)
	cost = data.get("cost", 1)
	exhaust = data.get("exhaust", false)
	is_upgraded = data.get("upgraded", false) or "+" in raw_name
	
	var real_name = raw_name.split("+")[0].strip_edges()
	if data.has("description"):
		description = data.get("description")
	else:
		description = DESCRIPTIONS.get(real_name, "Sin descripcion.")

	if description == "Sin descripcion.":
		for key in DESCRIPTIONS.keys():
			if key.to_lower() == real_name.to_lower():
				description = DESCRIPTIONS[key]
				break

	flavor = data.get("flavor", "")
	
	if GameManager.selected_character == "estratega" and "INQUISIDOR" in card_name:
		description += "\n\n[LÓGICA: Coste -1]"
	
	requires_target = (attack > 0 or "JAQUE ETERNO" in card_name or "INCISION PRECISA" in card_name or "MIRADA QUE DEVORA" in card_name) and not ("ECO DEL VAC" in card_name or "POSICION VENTAJOSA" in card_name)
	update_display()

func update_display(force_upgrade_style: bool = false) -> void:
	if not label_name: return
	label_name.text = card_name
	var active_upgraded = is_upgraded or force_upgrade_style
	
	# Detectar tipo de carta para el color del texto base
	var is_curse = "MALDICIÓN" in description or "PESO DE LA VERDAD" in card_name or "MALDICIÓN DE CENIZA" in card_name
	var is_legendary = "LEGENDARIA" in description
	
	if is_curse:
		label_name.modulate = Color(0.7, 0.3, 0.8) # Purpura para maldiciones
	elif is_legendary:
		label_name.modulate = Color(1.0, 0.9, 0.4) # Dorado para leyendas
	elif active_upgraded:
		label_name.modulate = Color(0.2, 1.0, 0.2) # Verde para mejoradas
	else:
		label_name.modulate = Color(0.9, 0.85, 0.6) # Pergamino para normales
	
	var jaque_dmg = 0
	if "JAQUE ETERNO" in card_name:
		var health_lost = GameManager.player_max_hp - GameManager.player_hp
		jaque_dmg = clamp(15 + int(health_lost * 0.4), 15, 40)
		description = "ÉPICA. Canaliza tu dolor.\nDaño actual: " + str(jaque_dmg)
	elif "OFRENDA DE CARNE" in card_name.to_upper():
		description = "PODER. Pagas con sangre.\nDaño: " + str(attack) + " | Coste: 4 HP"
	
	if active_upgraded:
		label_name.modulate = Color(0.2, 1.0, 0.2)
		if "SUSURRO DEBILITANTE" in card_name:
			label_attack.text = "✖ DEB: " + str(6 + attack)
			label_attack.modulate = Color(0.3, 0.9, 0.3)
		elif "JAQUE ETERNO" in card_name:
			label_attack.text = "⚔ ATK: " + str(jaque_dmg)
			label_attack.modulate = Color(0.3, 0.9, 0.3)
		elif "OFRENDA DE CARNE" in card_name.to_upper():
			label_attack.text = "⚔ ATK: " + str(attack)
			label_attack.modulate = Color(0.3, 0.9, 0.3)
		elif "ECO" in card_name:
			label_attack.text = "⚔ ATK: " + str(4 + attack)
			label_attack.modulate = Color(0.3, 0.9, 0.3)
		else:
			if attack > 0:
				label_attack.text = "⚔ ATK: " + str(attack)
				if GameManager.selected_character == "mahar":
					_update_fervor_badge()
				label_attack.modulate = Color(0.3, 0.9, 0.3)
			if defense > 0:
				label_defense.text = "🛡 DEF: " + str(defense)
				label_defense.modulate = Color(0.3, 0.9, 0.3)
	else:
		label_name.modulate = Color(0.9, 0.85, 0.6)
		if "SUSURRO DEBILITANTE" in card_name:
			label_attack.text = "✖ DEB: 6"
			label_attack.modulate = Color(0.6, 0.4, 0.7)
		elif "JAQUE ETERNO" in card_name:
			label_attack.text = "⚔ ATK: " + str(jaque_dmg)
			label_attack.modulate = Color(0.8, 0.3, 0.3)
		elif "OFRENDA DE CARNE" in card_name.to_upper():
			label_attack.text = "⚔ ATK: " + str(attack)
			label_attack.modulate = Color(0.8, 0.3, 0.3)
		elif "ECO" in card_name:
			label_attack.text = "⚔ ATK: 4"
			label_attack.modulate = Color(0.8, 0.3, 0.3)
		else:
			if attack > 0:
				label_attack.text = "⚔ ATK: " + str(attack)
				if GameManager.selected_character == "mahar":
					_update_fervor_badge()
			else:
				label_attack.text = ""
			label_attack.modulate = Color(0.8, 0.3, 0.3)
			label_defense.text = "🛡 DEF: " + str(defense) if defense > 0 else ""
			label_defense.modulate = Color(0.4, 0.6, 0.8)

	var has_real_desc = description != "" and description != "Sin descripcion."
	var tooltip_text = description if has_real_desc else ""
	if flavor != "":
		if has_real_desc:
			tooltip_text += "\n\n"
		tooltip_text += "[color=#8a7a5a][font_size=10][i]" + flavor + "[/i][/font_size][/color]"
	elif not has_real_desc:
		tooltip_text = "Sin descripcion."

	if is_marked:
		var curse_cost = _get_mark_curse_cost()
		tooltip_text += "\n\n[color=#cc44ff]✦ MARCADA DEL VACÍO[/color]\n"
		tooltip_text += "[color=#ff66ff]Jugar cuesta " + str(curse_cost) + " Cordura.[/color]\n"
		tooltip_text += "[color=#777777][font_size=10]Si Cordura insuficiente, el exceso daña tu Vida.[/font_size][/color]"

	var _tlabel = tooltip_panel.get_node("TooltipLabel")
	_tlabel.text = tooltip_text
	_tlabel.modulate = Color.WHITE
	# Expandir el panel para cartas marcadas — el contenido extra no cabe en 140px
	var _panel_h = 220 if is_marked else 140
	tooltip_panel.size.y = _panel_h
	_tlabel.size.y = _panel_h - 16
	var icon_lbl = get_node("IconLabel")
	if "LEGENDARIA" in description:
		icon_lbl.text = "👑"; icon_lbl.modulate = Color(1, 0.9, 0.4, 0.4)
	else:
		match card_name:
			"SIERVO QUEBRADO":    icon_lbl.text = "♙"
			"BALUARTE DE HUESO":   icon_lbl.text = "♖"
			"CABALGANTE DEL VACIO": icon_lbl.text = "♘"
			"INQUISIDOR CIEGO":    icon_lbl.text = "♗"
			"DAMA DEL TABLERO":    icon_lbl.text = "♕"
			"IDOLO INERTE":        icon_lbl.text = "♔"
			"OFRENDA DE CARNE":    icon_lbl.text = "🥩"
			"SUSURRO DEL VACIO", "DAGA DE CRISTAL", "ESPEJO ROTO", "ABRAZO DE LA LOCURA":
				icon_lbl.text = "✨"; icon_lbl.modulate = Color(0.6, 0.4, 1.0, 0.4)
			_: icon_lbl.text = "✦"
		
		if not "LEGENDARIA" in description:
			icon_lbl.modulate = Color(1, 1, 1, 0.15)
	
	_update_cost_label()
	
	# Aplicar el estilo visual (color de borde/fondo) inmediatamente
	_apply_style(Color(0.35, 0.35, 0.1) if is_hovered else Color(0.12, 0.12, 0.15))

func get_effective_cost() -> int:
	return max(0, cost + cost_modifier)

func _update_cost_label() -> void:
	var effective = max(0, cost + cost_modifier)
	label_cost.text = "COSTO: " + str(effective)
	if cost_modifier < 0: label_cost.modulate = Color(0.3, 1.0, 0.3)
	elif cost_modifier > 0: label_cost.modulate = Color(1.0, 0.3, 0.3)
	else: label_cost.modulate = Color(0.85, 0.75, 0.2)

func set_cost_modifier(mod: int) -> void:
	cost_modifier = mod; _update_cost_label()

func set_disabled(value: bool) -> void:
	is_disabled = value
	if value:
		_apply_style(Color(0.04, 0.04, 0.06)); tooltip_panel.visible = false
		if is_hovered: _animate_hover(false)
	else:
		_apply_style(Color(0.12, 0.12, 0.15))

func _update_fervor_badge() -> void:
	var badge = get_node_or_null("FervorBadge")
	if not badge: return
	var san = GameManager.sanity
	var combat = get_tree().get_root().get_node_or_null("Combat") if get_tree() else null
	var spent = combat != null and "mahar_guided_struck" in combat and combat.mahar_guided_struck
	if san >= 60:
		if spent:
			badge.text = "✦ FERVOR (usado)"; badge.modulate = Color(0.5, 0.4, 0.2, 0.6)
		else:
			badge.text = "✦ FERVOR +4"; badge.modulate = Color(1.0, 0.75, 0.15)
		badge.visible = true
	elif san < 40:
		badge.text = "✦ FE ROTA +2"; badge.modulate = Color(0.85, 0.35, 0.35)
		badge.visible = true
	else:
		badge.visible = false

func _refresh_context(hand_size: int = -1) -> void:
	var badge = get_node_or_null("ContextBadge")
	if not badge: return
	var san = GameManager.sanity

	# scaling_sanity — actualizar label_attack y badge con efecto real
	if card_data.get("scaling_sanity", false) and attack > 0:
		var mult = 2.0 if san < 35 else (1.5 if san < 60 else 1.0)
		label_attack.text = "⚔ ATK: %d" % int(attack * mult)
		if mult >= 2.0:
			badge.text = "✦ TRANCE ×2"
			badge.modulate = Color(0.55, 0.25, 0.85)
			badge.visible = true
		elif mult > 1.0:
			badge.text = "✦ ABISMO ×1.5"
			badge.modulate = Color(0.35, 0.25, 0.75, 0.85)
			badge.visible = true
		else:
			badge.visible = false
		return

	# coste de sanidad — advertencia de peligro
	var sc = card_data.get("sanity_cost", 0)
	if sc > 0:
		if san <= sc:
			badge.text = "⚠ CORD FATAL"
			badge.modulate = Color(1.0, 0.15, 0.15)
		else:
			badge.text = "⚠ −%d CORD" % sc
			badge.modulate = Color(0.85, 0.5, 0.15) if san < sc + 20 else Color(0.65, 0.45, 0.75)
		badge.visible = true
		return

	# coste de HP
	var hc = card_data.get("hp_cost", 0)
	if hc > 0:
		var php = GameManager.player_hp
		if php <= hc + 1:
			badge.text = "⚠ HP FATAL"
			badge.modulate = Color(1.0, 0.15, 0.15)
		else:
			badge.text = "⚠ −%d HP" % hc
			badge.modulate = Color(0.85, 0.35, 0.35)
		badge.visible = true
		return

	# Susurro Debilitante — bonus de última carta
	if "SUSURRO DEBILITANTE" in card_name and hand_size == 1:
		badge.text = "✦ ÚLTIMA ×2"
		badge.modulate = Color(0.5, 0.35, 0.85)
		badge.visible = true
		return

	badge.visible = false

func _apply_style(color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color; style.set_corner_radius_all(4)
	style.border_width_left = 3; style.border_width_right = 3
	style.border_width_top = 3; style.border_width_bottom = 3
	
	var is_curse = "MALDICIÓN" in description or "PESO DE LA VERDAD" in card_name or "MALDICIÓN DE CENIZA" in card_name
	var is_legendary = "LEGENDARIA" in description
	
	if is_curse:
		style.bg_color = Color(0.02, 0.0, 0.03)
		style.border_color = Color(0.6, 0.2, 0.8) # Purpura constante
	elif is_legendary:
		style.bg_color = Color(0.01, 0.01, 0.02); style.border_color = Color(1.0, 0.85, 0.2)
		style.border_width_left = 4; style.border_width_right = 4
		style.border_width_top = 4; style.border_width_bottom = 4
	elif "SUSURRO" in card_name or "ECO" in card_name:
		style.border_color = Color(0.5, 0.4, 0.6)
	elif cost == 0:
		style.border_color = Color(0.5, 0.5, 0.5)
	else:
		style.border_color = Color(0.45, 0.4, 0.25)
	
	# Ajustar opacidad del color base si es hover
	if color.r > 0.3: # Si es el color de hover amarillento
		style.border_color = style.border_color.lightened(0.2)

	# Borde FERVOR para cartas de ataque de Mahar
	if GameManager.selected_character == "mahar" and attack > 0:
		var san = GameManager.sanity
		var combat = get_tree().get_root().get_node_or_null("Combat") if get_tree() else null
		var spent = combat != null and "mahar_guided_struck" in combat and combat.mahar_guided_struck
		if san >= 60 and not spent:
			style.border_color = Color(1.0, 0.75, 0.15)
		elif san >= 60 and spent:
			style.border_color = Color(0.4, 0.35, 0.2)
		elif san < 40:
			style.border_color = Color(0.75, 0.25, 0.25)

	add_theme_stylebox_override("panel", style)

func _animate_hover(entering: bool) -> void:
	is_hovered = entering
	if hover_scale_enabled:
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		if entering:
			tween.tween_property(self, "scale", base_scale * 1.05, 0.1)
			z_index = 50
		else:
			tween.tween_property(self, "scale", base_scale, 0.1)
			z_index = 5
	else:
		z_index = 50 if entering else 5
		if glow_enabled:
			_animate_glow(entering)

func _on_mouse_entered() -> void:
	if not is_disabled:
		_apply_style(Color(0.35, 0.35, 0.1)); _animate_hover(true)
		var vp_x = get_viewport_rect().size.x
		if global_position.x > vp_x * 0.65: tooltip_panel.position = Vector2(-tooltip_panel.size.x - 5, -5)
		else: tooltip_panel.position = Vector2(size.x + 5, -5)
		tooltip_panel.visible = true
		if get_node_or_null("/root/AudioManager"): AudioManager.play("card_hover")

func _on_mouse_exited() -> void:
	if not is_disabled: _apply_style(Color(0.12, 0.12, 0.15)); _animate_hover(false)
	tooltip_panel.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if is_disabled: return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tooltip_panel.visible = false
			if requires_target: card_selected.emit(self)
			else: card_played.emit(self)

func set_marked(value: bool) -> void:
	is_marked = value
	update_display()

func _get_mark_curse_cost() -> int:
	var san = GameManager.sanity
	var c: int
	if san >= 25: c = 4
	elif san >= 10: c = 5
	else: c = 6
	if GameManager.selected_character == "prince":
		c = max(1, c / 2)
	return c

func set_display_scale(s: Vector2) -> void:
	scale = s
	base_scale = s

func _animate_glow(entering: bool) -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if entering:
		tw.tween_property(self, "modulate", Color(1.15, 1.1, 0.9), 0.12)
	else:
		tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15)

func flash_new_card() -> void:
	modulate = Color(1.6, 1.4, 0.6)
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.45)

func animate_draw(start_pos: Vector2, delay: float) -> void:
	var parent_node = get_parent()
	var local_start = start_pos - parent_node.global_position
	position = local_start; modulate.a = 0.0; scale = Vector2(0.1, 0.1); rotation = randf_range(-0.4, 0.4)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_delay(delay)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_delay(delay)
	tw.tween_property(self, "rotation", 0.0, 0.6).set_delay(delay)

func play_attack_animation(target_pos: Vector2 = Vector2.ZERO) -> void:
	if get_node_or_null("/root/AudioManager"): AudioManager.play("card_play")
	_spawn_play_burst()
	if exhaust:
		modulate = Color(1.4, 0.5, 0.1)
		await get_tree().create_timer(0.07).timeout
	var tw = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	if target_pos != Vector2.ZERO:
		tw.tween_property(self, "global_position", target_pos, 0.2); tw.tween_property(self, "scale", Vector2(0.4, 0.4), 0.2)
	else:
		tw.tween_property(self, "position:y", position.y - 150, 0.25); tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
		tw.chain().tween_property(self, "scale", Vector2(0.0, 0.0), 0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished

func _spawn_play_burst() -> void:
	var gpu = GPUParticles2D.new()
	gpu.global_position = global_position + Vector2(65, 97)
	gpu.z_index = 100
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.spread = 180.0
	mat.initial_velocity_min = 55.0
	mat.initial_velocity_max = 160.0
	mat.gravity = Vector3(0, 220, 0)
	mat.scale_min = 2.0
	mat.scale_max = 6.0
	var g = Gradient.new()
	if exhaust:
		g.set_color(0, Color(1.0, 0.5, 0.1, 1.0))
		g.set_color(1, Color(0.6, 0.1, 0.0, 0.0))
	else:
		g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
		g.set_color(1, Color(0.7, 0.35, 0.0, 0.0))
	var gt = GradientTexture1D.new(); gt.gradient = g
	mat.color_ramp = gt
	gpu.process_material = mat
	gpu.amount = 12
	gpu.lifetime = 0.5
	gpu.one_shot = true
	gpu.explosiveness = 0.9
	get_tree().root.add_child(gpu)
	gpu.emitting = true
	get_tree().create_timer(1.0).timeout.connect(gpu.queue_free)
