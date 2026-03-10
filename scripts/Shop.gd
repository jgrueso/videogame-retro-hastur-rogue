extends Node2D

var shop_items: Array = [
	{"label": "Astilla de Esperanza (Carta comun)", "cost": 5, "action": "draft_common", "desc": "Una pieza tallada en hueso que aun vibra."},
	{"label": "Sangre Embalsamada (+15 HP max)", "cost": 10, "action": "max_hp", "desc": "Sabe a ceniza y a un pasado que no es tuyo."},
	{"label": "Elixir de la Agonia (Cura 20 HP)", "cost": 7, "action": "heal", "desc": "Dormira tu dolor, pero no tus pesadillas."},
	{"label": "Sello de la Dama (Reliquia)", "cost": 14, "action": "relic", "desc": "Un objeto que el Rey dio por perdido."},
]

var greeting: String = ""
const GREETINGS = [
	"\"¿Que traes en tus bolsillos, pequeña pieza? ¿Oro o arrepentimiento?\"",
	"\"Valla, valla... hueles a alguien que aun cree que tiene salida.\"",
	"\"El Rey no me deja hablar contigo, pero el Rey no esta mirando ahora.\"",
	"\"Tengo cosas que te harian llorar sangre. ¿Quieres verlas?\""
]

func _ready() -> void:
	greeting = GREETINGS[randi() % GREETINGS.size()]
	
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	build_ui()

func build_ui() -> void:
	var vp = get_viewport_rect().size
	
	# --- MARCO DECORATIVO ---
	var border = ReferenceRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.editor_only = false; border.border_color = Color(0.2, 0.15, 0.05, 0.5); border.border_width = 10
	add_child(border)

	# Header
	var title = Label.new()
	title.text = "☤ EL BUHONERO SIN ROSTRO ☤"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.85, 0.75, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40); title.size = Vector2(vp.x, 60)
	add_child(title)

	# El Mercader (Area visual)
	var merchant_area = Panel.new()
	merchant_area.position = Vector2(vp.x * 0.1, 110); merchant_area.size = Vector2(vp.x * 0.8, 100)
	var ms = StyleBoxFlat.new(); ms.bg_color = Color(0.05, 0.04, 0.06); ms.set_corner_radius_all(10); ms.border_width_bottom = 2; ms.border_color = Color(0.3, 0.2, 0.4)
	merchant_area.add_theme_stylebox_override("panel", ms)
	add_child(merchant_area)

	var greet_lbl = Label.new()
	greet_lbl.text = greeting
	greet_lbl.add_theme_font_size_override("font_size", 18)
	greet_lbl.modulate = Color(0.7, 0.6, 0.8)
	greet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greet_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	greet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	greet_lbl.size = merchant_area.size
	merchant_area.add_child(greet_lbl)

	# Stats Info
	var info = Label.new()
	info.name = "PlayerInfo"
	info.text = "◈ MONEDAS: %d   ◈ VIDA: %d/%d   ◈ ENERGÍA: %d" % [GameManager.coins, GameManager.player_hp, GameManager.player_max_hp, GameManager.player_max_energy]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 220); info.size = Vector2(vp.x, 30)
	info.modulate = Color(0.9, 0.9, 0.9)
	add_child(info)

	# --- GRID DE ITEMS ---
	var grid = GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(vp.x * 0.1, 270)
	grid.size = Vector2(vp.x * 0.5, 300)
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 30)
	add_child(grid)

	for item in shop_items:
		var item_box = _create_shop_item_box(item)
		grid.add_child(item_box)

	# --- SECCION SACRIFICIO (Derecha) ---
	var sac_container = VBoxContainer.new()
	sac_container.position = Vector2(vp.x * 0.65, 270); sac_container.size = Vector2(300, 300)
	sac_container.add_theme_constant_override("separation", 20)
	add_child(sac_container)

	var sac_lbl = Label.new()
	sac_lbl.text = "✦  TRUEQUES OSCUROS  ✦"
	sac_lbl.modulate = Color(0.8, 0.2, 0.2)
	sac_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sac_container.add_child(sac_lbl)

	var btn_sell_mem = _create_sac_button("Vender un Recuerdo\n(+8 Monedas)", "Elimina una carta al azar de tu mazo.")
	btn_sell_mem.disabled = GameManager.player_deck.size() <= 3
	btn_sell_mem.pressed.connect(_on_sell_memory)
	sac_container.add_child(btn_sell_mem)

	var btn_sell_future = _create_sac_button("Vender tu Mañana\n(+15 Monedas)", "-10 Vida Máxima permanentemente.")
	btn_sell_future.disabled = GameManager.player_max_hp <= 20
	btn_sell_future.pressed.connect(_on_sell_future)
	sac_container.add_child(btn_sell_future)

	# Boton Salir
	var btn_exit = Button.new()
	btn_exit.text = "DEJAR EL MERCADO"
	btn_exit.position = Vector2(vp.x/2 - 120, 585); btn_exit.size = Vector2(240, 50)
	btn_exit.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/Map.tscn"))
	_style_main_button(btn_exit, Color(0.15, 0.1, 0.05))
	add_child(btn_exit)

func _create_shop_item_box(item: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(260, 120)
	btn.disabled = GameManager.coins < item["cost"]
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(vbox)
	
	var label = Label.new()
	label.text = item["label"].to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)
	
	var cost_lbl = Label.new()
	cost_lbl.text = "◈ " + str(item["cost"]) + " Monedas"
	cost_lbl.modulate = Color(1, 0.8, 0.2)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)
	
	btn.tooltip_text = item["desc"]
	if item["action"] == "relic":
		btn.tooltip_text += "\n[Contiene un misterio]"
	
	_style_item_button(btn)
	btn.pressed.connect(func(): _on_buy_pressed(item))
	return btn

func _create_sac_button(txt: String, tt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 80)
	btn.tooltip_text = tt
	_style_main_button(btn, Color(0.1, 0.02, 0.02))
	return btn

func _style_item_button(btn: Button) -> void:
	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.08, 0.08, 0.12); n.border_width_bottom = 3; n.border_color = Color(0.3, 0.3, 0.5); n.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", n)
	var h = n.duplicate(); h.bg_color = Color(0.15, 0.15, 0.25); h.border_color = Color(0.6, 0.6, 0.9)
	btn.add_theme_stylebox_override("hover", h)
	var d = n.duplicate()
	d.bg_color = Color(0.04, 0.04, 0.06)
	d.border_color = Color(0.15, 0.15, 0.2)
	btn.add_theme_stylebox_override("disabled", d)

func _style_main_button(btn: Button, color: Color) -> void:
	var n = StyleBoxFlat.new()
	n.bg_color = color; n.border_width_bottom = 2; n.border_color = color.lightened(0.2); n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", n)
	var h = n.duplicate(); h.bg_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", h)

func _on_buy_pressed(item: Dictionary) -> void:
	if GameManager.spend_coins(item["cost"]):
		match item["action"]:
			"draft_common":
				get_tree().change_scene_to_file("res://scenes/ui/CardDraft.tscn")
				return
			"max_hp":
				GameManager.player_max_hp += 15
				GameManager.player_hp += 15
			"heal":
				GameManager.heal(20)
			"relic":
				var available = GameManager.RELIC_DATA.keys().filter(func(r): return not GameManager.has_relic(r))
				if not available.is_empty():
					available.shuffle()
					GameManager.add_relic(available[0])
		
		if get_node_or_null("/root/AudioManager"):
			AudioManager.play("button_click")
		get_tree().change_scene_to_file("res://scenes/ui/Shop.tscn")

func _on_sell_memory() -> void:
	# Eliminar una carta aleatoria
	var idx = randi() % GameManager.player_deck.size()
	GameManager.player_deck.remove_at(idx)
	GameManager.add_coins(8)
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("button_click")
	get_tree().change_scene_to_file("res://scenes/ui/Shop.tscn")

func _on_sell_future() -> void:
	GameManager.player_max_hp -= 10
	GameManager.player_hp = min(GameManager.player_hp, GameManager.player_max_hp)
	GameManager.add_coins(15)
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play("button_click")
	get_tree().change_scene_to_file("res://scenes/ui/Shop.tscn")
