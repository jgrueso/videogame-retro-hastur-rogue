extends Panel

var card_name: String = ""
var attack: int = 0
var defense: int = 0
var cost: int = 1
var description: String = ""
var is_disabled: bool = false
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
}

signal card_played(card)
signal card_selected(card)

func _ready() -> void:
	custom_minimum_size = Vector2(130, 195)
	mouse_filter = MOUSE_FILTER_STOP
	pivot_offset = Vector2(65, 97)

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
	card_name = data.get("name", "").to_upper()
	attack = data.get("attack", 0)
	defense = data.get("defense", 0)
	cost = data.get("cost", 1)
	var real_name = data.get("name", "")
	description = DESCRIPTIONS.get(real_name, "Sin descripcion.")
	requires_target = attack > 0 or real_name == "Jaque Eterno"
	update_display()

func update_display() -> void:
	if not label_name:
		return
	label_name.text = card_name
	label_attack.text = "⚔ ATK: " + str(attack) if attack > 0 else ""
	label_defense.text = "🛡 DEF: " + str(defense) if defense > 0 else ""
	tooltip_panel.get_node("TooltipLabel").text = description
	_update_cost_label()

func _update_cost_label() -> void:
	var effective = cost + cost_modifier
	if cost_modifier > 0:
		label_cost.text = "COSTO: " + str(effective) + " (!)"
		label_cost.modulate = Color(1.0, 0.3, 0.3)
	elif cost_modifier < 0:
		label_cost.text = "COSTO: " + str(effective) + " (*)"
		label_cost.modulate = Color(0.3, 1.0, 0.3)
	else:
		label_cost.text = "COSTO: " + str(cost)
		label_cost.modulate = Color(0.85, 0.75, 0.2)

func set_cost_modifier(mod: int) -> void:
	cost_modifier = mod
	_update_cost_label()

func set_disabled(value: bool) -> void:
	is_disabled = value
	_apply_style(Color(0.04, 0.04, 0.06) if value else Color(0.08, 0.08, 0.12))
	if value:
		tooltip_panel.visible = false
		if is_hovered:
			_animate_hover(false)

func _apply_style(color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.45, 0.4, 0.25) # Tono metal oxidado / hueso
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
		_apply_style(Color(0.2, 0.2, 0.3))
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

func play_attack_animation() -> void:
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("card_play")
	# Lanzarse hacia arriba (hacia el enemigo) y volver
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.06)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
