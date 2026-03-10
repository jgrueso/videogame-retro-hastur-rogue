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
	
	# Header
	var title = Label.new()
	title.text = "☤ EL BUHONERO SIN ROSTRO ☤"
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(0.65, 0.55, 0.15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30); title.size = Vector2(vp.x, 50)
	add_child(title)

	var greet_lbl = Label.new()
	greet_lbl.text = greeting
	greet_lbl.add_theme_font_size_override("font_size", 16)
	greet_lbl.modulate = Color(0.5, 0.5, 0.6)
	greet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greet_lbl.position = Vector2(0, 85); greet_lbl.size = Vector2(vp.x, 30)
	add_child(greet_lbl)

	# Stats Info
	var info = Label.new()
	info.name = "PlayerInfo"
	info.text = "Tus Monedas: " + str(GameManager.coins) + "   |   Vida: " + str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp) + "   |   Energia: " + str(GameManager.player_max_energy)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 120); info.size = Vector2(vp.x, 30)
	add_child(info)

	# --- SECCION COMPRA ---
	var buy_lbl = Label.new()
	buy_lbl.text = "ADQUIRIR"
	buy_lbl.modulate = Color(0.4, 0.7, 0.4)
	buy_lbl.position = Vector2(176, 160)
	add_child(buy_lbl)

	for i in range(shop_items.size()):
		var item = shop_items[i]
		var btn = Button.new()
		btn.text = item["label"] + " (" + str(item["cost"]) + " monedas)"
		btn.position = Vector2(176, 190 + i * 65)
		btn.size = Vector2(500, 50)
		btn.tooltip_text = item["desc"]
		if item["action"] == "relic":
			btn.tooltip_text += "\n[!] Nota: Las reliquias pueden contener maldiciones."
		btn.disabled = GameManager.coins < item["cost"]
		btn.pressed.connect(func(): _on_buy_pressed(item))
		add_child(btn)
		
		var d = Label.new()
		d.text = item["desc"]
		d.add_theme_font_size_override("font_size", 12)
		d.modulate = Color(0.4, 0.4, 0.45)
		d.position = Vector2(182, 232 + i * 65)
		add_child(d)

	# --- SECCION TRUEQUE (Venta) ---
	var sell_panel = Panel.new()
	sell_panel.position = Vector2(720, 190); sell_panel.size = Vector2(300, 310)
	var sp = StyleBoxFlat.new()
	sp.bg_color = Color(0.08, 0.05, 0.05); sp.set_corner_radius_all(8)
	sp.border_width_left = 1; sp.border_color = Color(0.4, 0.2, 0.2)
	sell_panel.add_theme_stylebox_override("panel", sp)
	add_child(sell_panel)

	var sell_lbl = Label.new()
	sell_lbl.text = "VENDER"
	sell_lbl.modulate = Color(0.8, 0.3, 0.3)
	sell_lbl.position = Vector2(20, 15)
	sell_panel.add_child(sell_lbl)

	var btn_sell_mem = Button.new()
	btn_sell_mem.text = "Vender un Recuerdo\n(Borrar carta aleatoria)\n+8 monedas"
	btn_sell_mem.position = Vector2(20, 50); btn_sell_mem.size = Vector2(260, 80)
	btn_sell_mem.disabled = GameManager.player_deck.size() <= 3
	btn_sell_mem.pressed.connect(_on_sell_memory)
	sell_panel.add_child(btn_sell_mem)

	var btn_sell_future = Button.new()
	btn_sell_future.text = "Vender tu Mañana\n(-10 Vida Maxima)\n+15 monedas"
	btn_sell_future.position = Vector2(20, 150); btn_sell_future.size = Vector2(260, 80)
	btn_sell_future.disabled = GameManager.player_max_hp <= 20
	btn_sell_future.pressed.connect(_on_sell_future)
	sell_panel.add_child(btn_sell_future)

	# Boton Salir
	var btn_exit = Button.new()
	btn_exit.text = "CONTINUAR EL VIAJE"
	btn_exit.position = Vector2(vp.x/2 - 100, 580); btn_exit.size = Vector2(200, 50)
	btn_exit.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/Map.tscn"))
	add_child(btn_exit)

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
