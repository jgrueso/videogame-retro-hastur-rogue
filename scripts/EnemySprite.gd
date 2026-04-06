extends Control
class_name EnemySprite

# ── Estado ─────────────────────────────────────────────────────────────────────
var _name: String = ""
var _c: Color
var _d: Color
var _breath: float = 0.0
var _dead: bool = false
var _aggressive: bool = false

func setup(enemy_name: String) -> void:
	_name  = enemy_name
	_c     = _color_for(enemy_name)
	_d     = Color(_c.r * 0.22, _c.g * 0.22, _c.b * 0.22, 1.0)
	mouse_filter = MOUSE_FILTER_IGNORE
	_start_breathing()

func _color_for(n: String) -> Color:
	match n:
		"EL REY AMARILLO":                          return Color(0.95, 0.82, 0.10)
		"Avatar de Hastur", "EL VERDADERO HASTUR":  return Color(0.92, 0.80, 0.06)
		"EL REY SIN CORONA":                        return Color(0.74, 0.68, 0.54)
		"EL CARCELERO":                             return Color(0.54, 0.50, 0.72)
		"EL CENTINELA ABISAL":                      return Color(0.18, 0.60, 0.90)
		"El Penitente":                             return Color(0.62, 0.50, 0.78)
		"Caballero de Carcosa":                     return Color(0.50, 0.56, 0.70)
		"Inquisidor Ciego":                         return Color(0.64, 0.59, 0.50)
		"Espectro del Vacio", "Espectro":           return Color(0.44, 0.72, 0.84)
		"Alfil Caido":                              return Color(0.66, 0.60, 0.52)
		"Torre Rota":                               return Color(0.58, 0.55, 0.50)
		_:                                          return Color(0.72, 0.64, 0.52)

# ── Helpers de dibujo ──────────────────────────────────────────────────────────
func _fc(pts: Array, col: Color) -> void:
	var arr = PackedVector2Array()
	for p in pts: arr.append(p)
	var cols: Array[Color] = []
	for i in arr.size(): cols.append(col)
	draw_polygon(arr, PackedColorArray(cols))

func _eye(pos: Vector2, radius: float, iris_col: Color, angry: bool = false) -> void:
	draw_circle(pos, radius + 1.5, _d)
	draw_circle(pos, radius, Color(0.92, 0.88, 0.82))
	var pupil_offset = Vector2(0, 2) if not angry else Vector2(0, -1)
	draw_circle(pos + pupil_offset, radius * 0.58, iris_col)
	draw_circle(pos + pupil_offset + Vector2(-radius * 0.22, -radius * 0.22), radius * 0.18, Color(1, 1, 1, 0.9))
	if angry:
		# Ceja enfadada
		draw_line(pos + Vector2(-radius * 0.8, -radius - 1), pos + Vector2(radius * 0.8, -radius + 3), _d, 2.5)

func _hollow_eye(pos: Vector2, radius: float) -> void:
	draw_circle(pos, radius + 1.5, _d)
	draw_circle(pos, radius, Color(0.06, 0.03, 0.06))
	draw_circle(pos + Vector2(-radius*0.25, -radius*0.2), radius * 0.25, Color(0.5, 0.4, 0.6, 0.4))

func _eye_x(pos: Vector2, radius: float) -> void:
	draw_circle(pos, radius + 1.5, _d)
	draw_circle(pos, radius, Color(0.85, 0.82, 0.78))
	draw_line(pos + Vector2(-radius*0.7, -radius*0.7), pos + Vector2(radius*0.7, radius*0.7), _d, 2.5)
	draw_line(pos + Vector2(radius*0.7, -radius*0.7), pos + Vector2(-radius*0.7, radius*0.7), _d, 2.5)

# ── Animaciones ────────────────────────────────────────────────────────────────
func set_aggressive(val: bool) -> void:
	_aggressive = val
	_c = Color(0.72, 0.22, 0.28) if val else _color_for(_name)
	_d = Color(_c.r * 0.22, _c.g * 0.22, _c.b * 0.22, 1.0)
	queue_redraw()

func _start_breathing() -> void:
	var tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "scale", Vector2(1.025, 1.025), 1.1)
	tw.tween_property(self, "scale", Vector2(1.0,   1.0  ), 1.1)

func play_hit() -> void:
	if _dead: return
	var tw = create_tween().set_trans(Tween.TRANS_QUART)
	tw.tween_property(self, "modulate", Color(2.5, 2.5, 2.5), 0.06)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.22)

func play_death() -> void:
	_dead = true
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale",    Vector2(1.1, 0.0), 0.45)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.45)

# ── Dispatch ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	if _dead: return
	var cx: float = size.x / 2.0
	match _name:
		"Siervo Rebelde":                   _draw_siervo(cx)
		"Peon Maldito":                     _draw_peon_maldito(cx)
		"Torre Rota":                       _draw_torre(cx)
		"Alfil Caido":                      _draw_alfil(cx)
		"Caballero de Carcosa":             _draw_caballero(cx)
		"Inquisidor Ciego":                 _draw_inquisidor(cx)
		"Espectro del Vacio", "Espectro":   _draw_espectro(cx)
		"El Penitente":                     _draw_penitente(cx)
		"EL CARCELERO":                     _draw_carcelero(cx)
		"EL REY SIN CORONA":                _draw_rey_sin_corona(cx)
		"EL REY AMARILLO":                  _draw_rey_amarillo(cx)
		"EL CENTINELA ABISAL":              _draw_centinela(cx)
		"Avatar de Hastur":                 _draw_avatar_hastur(cx)
		"EL VERDADERO HASTUR":              _draw_hastur_final(cx)
		_:                                  _draw_peon_base(cx, _c, _d)

# ══════════════════════════════════════════════════════════════════════════════
# SPRITES
# ══════════════════════════════════════════════════════════════════════════════

# ── Peón base (reutilizable) ───────────────────────────────────────────────────
func _draw_peon_base(cx: float, c: Color, d: Color) -> void:
	# Pedestal
	draw_rect(Rect2(cx-26, 115, 52, 12), d)
	draw_rect(Rect2(cx-21, 117, 42, 8),  c)
	# Cuerpo (trapezoide)
	_fc([Vector2(cx-22,44), Vector2(cx+22,44), Vector2(cx+15,116), Vector2(cx-15,116)], c)
	_fc([Vector2(cx-18,44), Vector2(cx+18,44), Vector2(cx+12,76),  Vector2(cx-12,76)],
		Color(c.r*1.08, c.g*1.08, c.b*1.08, 1.0))
	# Cuello
	draw_rect(Rect2(cx-7, 33, 14, 13), d)
	draw_rect(Rect2(cx-5, 34, 10, 10), c)
	# Cabeza
	draw_circle(Vector2(cx, 21), 14, d)
	draw_circle(Vector2(cx, 20), 12, c)

# ── Siervo Rebelde ─────────────────────────────────────────────────────────────
func _draw_siervo(cx: float) -> void:
	_draw_peon_base(cx, _c, _d)
	# Grieta principal
	draw_line(Vector2(cx+4, 44), Vector2(cx-5, 72),  Color(0,0,0,0.65), 2.5)
	draw_line(Vector2(cx-5, 72), Vector2(cx+3, 116),  Color(0,0,0,0.65), 2.5)
	# Fragmento suelto
	_fc([Vector2(cx+8,50), Vector2(cx+16,48), Vector2(cx+14,62), Vector2(cx+6,63)],
		Color(_c.r*0.85, _c.g*0.85, _c.b*0.85))
	# Ojos rebeldes
	_eye(Vector2(cx-4, 19), 4.5, Color(0.80, 0.10, 0.10), true)
	_eye(Vector2(cx+4, 19), 4.5, Color(0.80, 0.10, 0.10), true)

# ── Peón Maldito ───────────────────────────────────────────────────────────────
func _draw_peon_maldito(cx: float) -> void:
	var curse = Color(_c.r*0.6, _c.g*0.5, _c.b*0.8)
	_draw_peon_base(cx, _c, _d)
	# Manchas de maldición
	draw_circle(Vector2(cx-8,  62), 5, Color(curse.r, curse.g, curse.b, 0.5))
	draw_circle(Vector2(cx+10, 80), 4, Color(curse.r, curse.g, curse.b, 0.4))
	draw_circle(Vector2(cx-4,  95), 3, Color(curse.r, curse.g, curse.b, 0.35))
	# Goteo
	draw_line(Vector2(cx-8, 62), Vector2(cx-10, 85), Color(curse.r, curse.g, curse.b, 0.55), 2.0)
	# Ojos X (malditos)
	_eye_x(Vector2(cx-4, 19), 4.5)
	_eye_x(Vector2(cx+4, 19), 4.5)
	# Sonrisa torcida
	draw_arc(Vector2(cx+2, 26), 5, 0.2, PI - 0.2, 10, _d, 2.0)

# ── Torre Rota ─────────────────────────────────────────────────────────────────
func _draw_torre(cx: float) -> void:
	var lit = Color(_c.r*1.1, _c.g*1.1, _c.b*1.1)
	# Base
	draw_rect(Rect2(cx-26, 113, 52, 14), _d)
	draw_rect(Rect2(cx-22, 115, 44, 10), _c)
	# Cuerpo de la torre
	draw_rect(Rect2(cx-20, 20, 40, 95), _d)
	draw_rect(Rect2(cx-16, 22, 32, 89), _c)
	draw_rect(Rect2(cx-12, 24, 24, 85), lit)
	# Almenas: izq OK, centro ROTO, der OK
	draw_rect(Rect2(cx-20, 8,  13, 14), _d)
	draw_rect(Rect2(cx-17, 10, 9,  10), _c)
	draw_rect(Rect2(cx+7,  8,  13, 14), _d)
	draw_rect(Rect2(cx+9,  10, 9,  10), _c)
	# Escombros almena central
	_fc([Vector2(cx-4,14), Vector2(cx+4,14), Vector2(cx+6,20), Vector2(cx-2,20)], _d)
	_fc([Vector2(cx-2,20), Vector2(cx+5,20), Vector2(cx+3,22), Vector2(cx-4,22)], _d.darkened(0.3))
	# Ventana / ojo único
	draw_rect(Rect2(cx-10, 38, 20, 26), _d.darkened(0.4))
	draw_circle(Vector2(cx, 51), 8, Color(0.05, 0.03, 0.06))
	draw_circle(Vector2(cx, 51), 5, Color(0.70, 0.55, 0.10, 0.85))
	draw_circle(Vector2(cx-2, 49), 2, Color(1, 0.9, 0.3, 0.9))
	# Grieta diagonal
	draw_line(Vector2(cx+5, 22), Vector2(cx-4, 58),  Color(0,0,0,0.6), 2.5)
	draw_line(Vector2(cx-4, 58), Vector2(cx+6, 111), Color(0,0,0,0.6), 2.5)

# ── Alfil Caído ────────────────────────────────────────────────────────────────
func _draw_alfil(cx: float) -> void:
	var ox = 9.0  # inclinación
	# Pedestal
	draw_rect(Rect2(cx-20+ox, 112, 38, 12), _d)
	draw_rect(Rect2(cx-16+ox, 114, 30, 8), _c)
	# Túnica larga
	_fc([Vector2(cx-22+ox,46), Vector2(cx+22+ox,46),
		 Vector2(cx+26+ox,112), Vector2(cx-26+ox,112)], _c)
	_fc([Vector2(cx-16+ox,46), Vector2(cx+16+ox,46),
		 Vector2(cx+20+ox,80),  Vector2(cx-20+ox,80)],
		Color(_c.r*1.1, _c.g*1.1, _c.b*1.1))
	# Cuerpo superior
	draw_rect(Rect2(cx-10+ox, 30, 20, 18), _c)
	# Mitra (sombrero de obispo)
	_fc([Vector2(cx+ox, 6), Vector2(cx-12+ox, 30), Vector2(cx+12+ox, 30)], _c)
	_fc([Vector2(cx+ox, 9), Vector2(cx-9+ox, 29),  Vector2(cx+9+ox, 29)],
		Color(_c.r*1.12, _c.g*1.12, _c.b*1.12))
	draw_rect(Rect2(cx-16+ox, 28, 32, 5), _d)
	draw_rect(Rect2(cx-13+ox, 29, 26, 3), _c)
	# Hendidura de mitra
	draw_rect(Rect2(cx-3+ox, 24, 6, 8), _d)
	# Cruz en túnica
	draw_line(Vector2(cx+ox, 52),   Vector2(cx+ox,   80),   _d, 3.0)
	draw_line(Vector2(cx-10+ox, 63), Vector2(cx+10+ox, 63), _d, 3.0)
	# Ojo triste visible (caído, mira hacia abajo)
	_eye(Vector2(cx+ox, 38), 5.0, Color(0.30, 0.55, 0.75), false)
	# Bastón roto al suelo
	draw_line(Vector2(cx+28+ox, 30), Vector2(cx+22+ox, 112), _d, 3.5)
	draw_line(Vector2(cx+22+ox, 30), Vector2(cx+18+ox, 22),  _d, 2.5)
	draw_circle(Vector2(cx+18+ox, 20), 4, _d)
	# Grieta de caída
	draw_line(Vector2(cx-8+ox, 46), Vector2(cx+4+ox, 70), Color(0,0,0,0.45), 1.5)

# ── Caballero de Carcosa ───────────────────────────────────────────────────────
func _draw_caballero(cx: float) -> void:
	var void_c = Color(0.12, 0.05, 0.22)
	# Cuerpo/armadura
	draw_rect(Rect2(cx-22, 60, 44, 56), _d)
	draw_rect(Rect2(cx-18, 62, 36, 50), _c)
	# Hombreras pronunciadas
	_fc([Vector2(cx-32,58), Vector2(cx-14,58), Vector2(cx-10,72), Vector2(cx-28,72)], _d)
	_fc([Vector2(cx+14,58), Vector2(cx+32,58), Vector2(cx+28,72), Vector2(cx+10,72)], _d)
	_fc([Vector2(cx-28,60), Vector2(cx-14,60), Vector2(cx-11,70), Vector2(cx-26,70)], _c)
	_fc([Vector2(cx+14,60), Vector2(cx+28,60), Vector2(cx+26,70), Vector2(cx+11,70)], _c)
	# Cuello
	draw_rect(Rect2(cx-8, 46, 16, 16), _c)
	# Cabeza de caballo estilizada (perfil 3/4)
	_fc([
		Vector2(cx-10,12), Vector2(cx+8, 12),
		Vector2(cx+8,  22), Vector2(cx+26,26),
		Vector2(cx+26,38), Vector2(cx+8, 40),
		Vector2(cx+8,  46), Vector2(cx-10,46)
	], _c)
	_fc([
		Vector2(cx-10,14), Vector2(cx+6, 14),
		Vector2(cx+6,  22), Vector2(cx+24,26),
		Vector2(cx+24,36), Vector2(cx+6, 38),
		Vector2(cx+6,  44), Vector2(cx-8, 44)
	], Color(_c.r*1.1, _c.g*1.1, _c.b*1.1))
	# Crin oscura
	_fc([
		Vector2(cx-10,12), Vector2(cx-20,18),
		Vector2(cx-22,28), Vector2(cx-16,34),
		Vector2(cx-10,32), Vector2(cx-10,12)
	], _d)
	# Fosas nasales
	draw_circle(Vector2(cx+22, 34), 2.5, _d.darkened(0.3))
	# Ojo del caballo (corrompido por Carcosa)
	_eye(Vector2(cx+16, 24), 4.5, Color(0.55, 0.0, 0.80), false)
	# Manchas del vacío en armadura
	draw_circle(Vector2(cx,    75), 7, Color(void_c.r, void_c.g, void_c.b, 0.5))
	draw_circle(Vector2(cx-12, 88), 4, Color(void_c.r, void_c.g, void_c.b, 0.35))
	draw_circle(Vector2(cx+10, 95), 3, Color(void_c.r, void_c.g, void_c.b, 0.3))
	# Grietas de vacío en armadura
	draw_line(Vector2(cx, 68), Vector2(cx-6, 82),   Color(void_c.r, void_c.g, void_c.b, 0.6), 1.5)
	draw_line(Vector2(cx, 68), Vector2(cx+4, 80),   Color(void_c.r, void_c.g, void_c.b, 0.6), 1.5)

# ── Inquisidor Ciego ───────────────────────────────────────────────────────────
func _draw_inquisidor(cx: float) -> void:
	var robe_lit = Color(_c.r*1.08, _c.g*1.08, _c.b*1.08)
	# Túnica larga y pesada
	_fc([Vector2(cx-32,116), Vector2(cx+32,116),
		 Vector2(cx+22,38),  Vector2(cx-22,38)], _c)
	_fc([Vector2(cx-26,114), Vector2(cx+26,114),
		 Vector2(cx+18,40),  Vector2(cx-18,40)], robe_lit)
	draw_rect(Rect2(cx-32, 113, 64, 14), _d)
	# Hombros/manto
	_fc([Vector2(cx-24,38), Vector2(cx+24,38),
		 Vector2(cx+16,24), Vector2(cx-16,24)], _c)
	# Capucha
	draw_circle(Vector2(cx, 16), 16, _d)
	draw_circle(Vector2(cx, 15), 14, _c)
	# Interior oscuro de la capucha (cara en sombra)
	draw_circle(Vector2(cx, 18), 11, Color(0.05, 0.04, 0.06))
	# Ojos ciegos (X)
	_eye_x(Vector2(cx-5, 15), 5.0)
	_eye_x(Vector2(cx+5, 15), 5.0)
	# Cruz en la túnica
	draw_line(Vector2(cx, 44),    Vector2(cx, 96),    _d, 4.0)
	draw_line(Vector2(cx-14, 64), Vector2(cx+14, 64), _d, 4.0)
	# Bordado de la cruz
	draw_line(Vector2(cx, 46),    Vector2(cx, 94),    Color(_d.r*1.6, _d.g*1.4, _d.b*1.0), 1.5)
	# Bastón (derecha)
	draw_line(Vector2(cx+34, 22), Vector2(cx+38, 122), _d, 4.0)
	draw_circle(Vector2(cx+33, 19), 6, _d)
	draw_circle(Vector2(cx+33, 19), 4, robe_lit)

# ── Espectro del Vacío ─────────────────────────────────────────────────────────
func _draw_espectro(cx: float) -> void:
	var gc = Color(_c.r, _c.g, _c.b, 0.78)
	var gd = Color(_d.r, _d.g, _d.b, 0.62)
	# Cola espectral ondulante
	_fc([
		Vector2(cx-26,50),  Vector2(cx+26,50),
		Vector2(cx+20,70),  Vector2(cx+12,60),
		Vector2(cx+6,  88), Vector2(cx-6, 76),
		Vector2(cx-14, 96), Vector2(cx-20,74)
	], gc)
	# Ligero brillo interior de la cola
	_fc([
		Vector2(cx-18,52),  Vector2(cx+18,52),
		Vector2(cx+13,68),  Vector2(cx+8, 60),
		Vector2(cx+3,  80), Vector2(cx-3, 72)
	], Color(gc.r*1.12, gc.g*1.12, gc.b*1.12, 0.45))
	# Torso
	draw_circle(Vector2(cx, 42), 20, gd)
	draw_circle(Vector2(cx, 41), 18, gc)
	draw_circle(Vector2(cx, 40), 14, Color(gc.r*1.1, gc.g*1.1, gc.b*1.1, 0.8))
	# Cabeza
	draw_circle(Vector2(cx, 20), 15, gd)
	draw_circle(Vector2(cx, 19), 13, gc)
	draw_circle(Vector2(cx, 18), 10, Color(gc.r*1.1, gc.g*1.1, gc.b*1.1, 0.85))
	# Ojos huecos y vacíos
	_hollow_eye(Vector2(cx-5, 17), 4.5)
	_hollow_eye(Vector2(cx+5, 17), 4.5)
	# Boca (línea triste)
	draw_arc(Vector2(cx, 25), 5, PI*0.15, PI*0.85, 8, Color(gd.r, gd.g, gd.b, 0.8), 2.0)
	# Cadenas (4 eslabones a cada lado)
	var chain_c = Color(0.40, 0.40, 0.52, 0.7)
	for i in 4:
		var yy = float(i)
		draw_rect(Rect2(cx-36, 48 + yy*10, 9, 6), chain_c)
		draw_rect(Rect2(cx-33, 50 + yy*10, 5, 3), Color(chain_c.r*1.2, chain_c.g*1.2, chain_c.b*1.3, 0.5))
		draw_rect(Rect2(cx+27, 50 + yy*10, 9, 6), chain_c)
		draw_rect(Rect2(cx+29, 52 + yy*10, 5, 3), Color(chain_c.r*1.2, chain_c.g*1.2, chain_c.b*1.3, 0.5))

# ── El Penitente ───────────────────────────────────────────────────────────────
func _draw_penitente(cx: float) -> void:
	if _aggressive:
		_draw_penitente_evil(cx)
	else:
		_draw_penitente_passive(cx)

func _draw_penitente_passive(cx: float) -> void:
	var purple = Color(0.50, 0.28, 0.70)
	# Aura suave
	draw_circle(Vector2(cx, 72), 46, Color(purple.r, purple.g, purple.b, 0.08))
	# Piernas arrodilladas
	draw_rect(Rect2(cx-22, 74, 16, 28), _d)
	draw_rect(Rect2(cx-19, 76, 12, 22), _c)
	draw_rect(Rect2(cx+6,  74, 16, 28), _d)
	draw_rect(Rect2(cx+8,  76, 12, 22), _c)
	# Pies (en el suelo)
	draw_rect(Rect2(cx-24, 98, 20, 8), _d)
	draw_rect(Rect2(cx+4,  98, 20, 8), _d)
	# Cuerpo encorvado hacia adelante
	_fc([Vector2(cx-20,34), Vector2(cx+12,26),
		 Vector2(cx+18,46), Vector2(cx+10,74),
		 Vector2(cx-10,74), Vector2(cx-20,52)], _c)
	_fc([Vector2(cx-16,36), Vector2(cx+10,28),
		 Vector2(cx+14,46), Vector2(cx+8, 70),
		 Vector2(cx-8, 70), Vector2(cx-16,50)],
		Color(_c.r*1.1, _c.g*1.1, _c.b*1.1))
	# Brazos cruzados (sometidos)
	_fc([Vector2(cx-20,34), Vector2(cx-4,28),
		 Vector2(cx+12,26), Vector2(cx+10,38),
		 Vector2(cx-4, 40), Vector2(cx-18,46)], _d)
	# Cadena en muñecas
	draw_line(Vector2(cx-5, 32), Vector2(cx+10, 34), Color(0.52, 0.42, 0.30), 5.0)
	draw_line(Vector2(cx-5, 32), Vector2(cx+10, 34), Color(0.68, 0.58, 0.40), 2.5)
	# Cabeza inclinada hacia abajo
	draw_circle(Vector2(cx+6, 18), 13, _d)
	draw_circle(Vector2(cx+5, 17), 11, _c)
	# Un ojo visible (mirando hacia arriba con remordimiento)
	_eye(Vector2(cx+8, 18), 4.5, Color(0.55, 0.30, 0.75), false)
	# El otro ojo cerrado/oculto
	draw_line(Vector2(cx+1, 16), Vector2(cx+6, 16), _d, 2.5)
	# Lágrimas
	draw_line(Vector2(cx+8, 22), Vector2(cx+7, 30), Color(0.5, 0.35, 0.75, 0.8), 1.5)

func _draw_penitente_evil(cx: float) -> void:
	var blood = Color(0.72, 0.12, 0.12)
	var dark  = Color(0.14, 0.04, 0.04)
	# Aura amenazante (rojo oscuro)
	draw_circle(Vector2(cx, 62), 52, Color(blood.r, blood.g, blood.b, 0.12))
	draw_circle(Vector2(cx, 62), 36, Color(blood.r, blood.g, blood.b, 0.07))
	# Piernas — todavía arrodillado pero tensas, levantadas del suelo
	draw_rect(Rect2(cx-22, 68, 16, 34), dark)
	draw_rect(Rect2(cx-19, 70, 12, 28), _c)
	draw_rect(Rect2(cx+6,  68, 16, 34), dark)
	draw_rect(Rect2(cx+8,  70, 12, 28), _c)
	draw_rect(Rect2(cx-24, 98, 20, 8), dark)
	draw_rect(Rect2(cx+4,  98, 20, 8), dark)
	# Cuerpo erguido y agresivo (más vertical, inclinado hacia el jugador)
	_fc([Vector2(cx-18,16), Vector2(cx+18,16),
		 Vector2(cx+22,50), Vector2(cx+14,68),
		 Vector2(cx-14,68), Vector2(cx-22,50)], _c)
	_fc([Vector2(cx-14,18), Vector2(cx+14,18),
		 Vector2(cx+17,48), Vector2(cx+10,65),
		 Vector2(cx-10,65), Vector2(cx-17,48)],
		Color(_c.r*1.15, _c.g*1.0, _c.b*1.0))
	# Brazos abiertos hacia los lados (amenazantes)
	_fc([Vector2(cx-18,18), Vector2(cx-38,32),
		 Vector2(cx-36,44), Vector2(cx-20,36)], dark)
	_fc([Vector2(cx-19,20), Vector2(cx-36,33),
		 Vector2(cx-34,42), Vector2(cx-19,34)], _c)
	_fc([Vector2(cx+18,18), Vector2(cx+38,32),
		 Vector2(cx+36,44), Vector2(cx+20,36)], dark)
	_fc([Vector2(cx+19,20), Vector2(cx+36,33),
		 Vector2(cx+34,42), Vector2(cx+19,34)], _c)
	# Cadenas rotas colgando de las muñecas
	var chain = Color(0.52, 0.42, 0.30)
	draw_line(Vector2(cx-36, 42), Vector2(cx-40, 52), chain, 4.0)
	draw_line(Vector2(cx-40, 52), Vector2(cx-36, 58), chain, 3.5)
	draw_line(Vector2(cx-36, 58), Vector2(cx-42, 64), chain, 3.0)
	draw_line(Vector2(cx+36, 42), Vector2(cx+40, 52), chain, 4.0)
	draw_line(Vector2(cx+40, 52), Vector2(cx+36, 58), chain, 3.5)
	draw_line(Vector2(cx+36, 58), Vector2(cx+42, 64), chain, 3.0)
	# Fragmentos rotos de cadena (dispersos)
	draw_line(Vector2(cx-38, 38), Vector2(cx-32, 34), chain, 2.5)
	draw_line(Vector2(cx+38, 38), Vector2(cx+32, 34), chain, 2.5)
	# Cabeza erguida y mirando al frente
	draw_circle(Vector2(cx, 7), 13, dark)
	draw_circle(Vector2(cx, 6), 11, _c)
	draw_circle(Vector2(cx, 5), 8, Color(_c.r*1.12, _c.g*0.9, _c.b*0.9))
	# Ambos ojos abiertos y furiosos (rojo sangre)
	_eye(Vector2(cx-4, 5), 4.5, blood, true)
	_eye(Vector2(cx+4, 5), 4.5, blood, true)
	# Boca: mueca dentada
	draw_arc(Vector2(cx, 13), 6, PI*0.15, PI*0.85, 10, dark, 2.0)
	for i in 3:
		draw_line(Vector2(cx - 4 + i*4, 13), Vector2(cx - 3 + i*4, 17), dark, 1.5)
	# Grietas en el cuerpo (marca de la transformación)
	draw_line(Vector2(cx-4, 20), Vector2(cx+2, 38), Color(blood.r, blood.g, blood.b, 0.7), 2.0)
	draw_line(Vector2(cx+2, 38), Vector2(cx-3, 55), Color(blood.r, blood.g, blood.b, 0.5), 1.5)

# ── EL CARCELERO (boss) ────────────────────────────────────────────────────────
func _draw_carcelero(cx: float) -> void:
	var iron = Color(0.42, 0.40, 0.56)
	var rust = Color(0.52, 0.28, 0.10)
	# Corona de barrotes de prisión
	for i in 6:
		var bx = cx - 25 + i * 10
		draw_rect(Rect2(bx, 4,  6, 22), _d)
		draw_rect(Rect2(bx+1, 5, 4, 20), iron)
	draw_rect(Rect2(cx-27, 24, 54, 5), _d)
	draw_rect(Rect2(cx-25, 25, 50, 3), iron)
	# Cabeza cuadrada y masiva
	draw_rect(Rect2(cx-20, 27, 40, 30), _d)
	draw_rect(Rect2(cx-16, 29, 32, 26), _c)
	draw_rect(Rect2(cx-12, 31, 24, 22), Color(_c.r*1.08, _c.g*1.08, _c.b*1.08))
	# Ojos encendidos (naranja amenazante)
	draw_rect(Rect2(cx-14, 34, 11, 8), _d.darkened(0.3))
	draw_rect(Rect2(cx+3,  34, 11, 8), _d.darkened(0.3))
	draw_circle(Vector2(cx-8,  38), 3.5, Color(0.92, 0.40, 0.02, 0.95))
	draw_circle(Vector2(cx+8,  38), 3.5, Color(0.92, 0.40, 0.02, 0.95))
	draw_circle(Vector2(cx-9,  37), 1.5, Color(1.0,  0.85, 0.50, 0.9))
	draw_circle(Vector2(cx+9,  37), 1.5, Color(1.0,  0.85, 0.50, 0.9))
	# Boca (rejilla)
	for i in 3:
		draw_line(Vector2(cx-10, 48+i*3), Vector2(cx+10, 48+i*3), _d, 1.5)
	draw_line(Vector2(cx-10, 48), Vector2(cx-10, 54), _d, 1.5)
	draw_line(Vector2(cx+10, 48), Vector2(cx+10, 54), _d, 1.5)
	# Hombreras enormes
	_fc([Vector2(cx-44,56), Vector2(cx-16,56), Vector2(cx-12,72), Vector2(cx-36,72)], _d)
	_fc([Vector2(cx-40,58), Vector2(cx-16,58), Vector2(cx-13,70), Vector2(cx-34,70)], iron)
	_fc([Vector2(cx+16,56), Vector2(cx+44,56), Vector2(cx+36,72), Vector2(cx+12,72)], _d)
	_fc([Vector2(cx+16,58), Vector2(cx+40,58), Vector2(cx+34,70), Vector2(cx+13,70)], iron)
	# Torso acorazado
	draw_rect(Rect2(cx-20, 56, 40, 48), _d)
	draw_rect(Rect2(cx-16, 58, 32, 42), _c)
	draw_rect(Rect2(cx-12, 60, 24, 36), Color(_c.r*1.06, _c.g*1.06, _c.b*1.06))
	# Símbolo del ojo de cerradura en el pecho
	draw_circle(Vector2(cx, 72), 8, _d)
	draw_circle(Vector2(cx, 72), 5, rust)
	draw_rect(Rect2(cx-3, 76, 6, 12), _d)
	draw_rect(Rect2(cx-2, 77, 4, 10), rust)
	# Cadenas colgantes (ambos lados)
	var cc = Color(0.44, 0.42, 0.32, 0.92)
	for i in 5:
		var yy = float(i)
		draw_rect(Rect2(cx-44, 58 + yy*8, 12, 6), cc)
		draw_rect(Rect2(cx-41, 60 + yy*8, 7,  3), Color(cc.r*1.2, cc.g*1.2, cc.b*1.1, 0.6))
		draw_rect(Rect2(cx+32, 60 + yy*8, 12, 6), cc)
		draw_rect(Rect2(cx+34, 62 + yy*8, 7,  3), Color(cc.r*1.2, cc.g*1.2, cc.b*1.1, 0.6))
	# Piernas
	draw_rect(Rect2(cx-20, 102, 18, 24), _d)
	draw_rect(Rect2(cx-17, 104, 14, 20), _c)
	draw_rect(Rect2(cx+2,  102, 18, 24), _d)
	draw_rect(Rect2(cx+4,  104, 14, 20), _c)

# ── EL REY SIN CORONA (boss final mundo 0) ────────────────────────────────────
func _draw_rey_sin_corona(cx: float) -> void:
	var bone  = Color(0.82, 0.76, 0.62)
	var robe  = Color(_c.r*1.0, _c.g*0.96, _c.b*0.88)
	# Túnica real, muy amplia en la base
	_fc([Vector2(cx-36,122), Vector2(cx+36,122),
		 Vector2(cx+24,46),  Vector2(cx-24,46)], _d)
	_fc([Vector2(cx-30,120), Vector2(cx+30,120),
		 Vector2(cx+20,48),  Vector2(cx-20,48)], robe)
	# Borde dorado de la túnica
	draw_line(Vector2(cx-20,48),  Vector2(cx-30,120), Color(bone.r, bone.g, bone.b*0.5, 0.6), 2.0)
	draw_line(Vector2(cx+20,48),  Vector2(cx+30,120), Color(bone.r, bone.g, bone.b*0.5, 0.6), 2.0)
	# Cuerpo / torso
	draw_rect(Rect2(cx-18, 30, 36, 20), _d)
	draw_rect(Rect2(cx-14, 32, 28, 16), robe)
	# Cuello / mandíbula esquelética
	draw_rect(Rect2(cx-8, 22, 16, 10), _d)
	draw_rect(Rect2(cx-6, 23, 12, 8),  bone)
	# Cabeza (calavera real)
	draw_circle(Vector2(cx, 13), 15, _d)
	draw_circle(Vector2(cx, 12), 13, bone)
	draw_circle(Vector2(cx, 11), 10, Color(bone.r*1.08, bone.g*1.05, bone.b*0.95))
	# Cuencas oculares profundas (vacías)
	_hollow_eye(Vector2(cx-5, 10), 5.0)
	_hollow_eye(Vector2(cx+5, 10), 5.0)
	# Nariz esquelética (dos huecos)
	draw_circle(Vector2(cx-1, 17), 2, _d.darkened(0.3))
	draw_circle(Vector2(cx+1, 17), 2, _d.darkened(0.3))
	# Dientes
	for i in 4:
		draw_rect(Rect2(cx - 7 + i*4, 21, 3, 5), bone)
	# Donde estuvo la corona: fragmentos rotos
	var frags = [Vector2(cx-10,0), Vector2(cx-4,-2), Vector2(cx+2,1), Vector2(cx+8,-1)]
	for j in frags.size():
		var f = frags[j]
		draw_line(f, f + Vector2(randf_range(-3,3), 6), bone, 2.5)
	draw_line(Vector2(cx-10, 2), Vector2(cx+10, 2), bone, 1.5)
	# Cetro roto (derecha)
	draw_line(Vector2(cx+28, 30), Vector2(cx+26, 90), _d, 4.0)
	draw_line(Vector2(cx+22, 40), Vector2(cx+32, 40), _d, 3.5)
	draw_line(Vector2(cx+26, 30), Vector2(cx+22, 22), _d, 2.5)

# ── EL REY AMARILLO (boss final mundo 1) ──────────────────────────────────────
func _draw_rey_amarillo(cx: float) -> void:
	var gold  = Color(0.95, 0.82, 0.10)
	var dgold = Color(0.36, 0.26, 0.00)
	var mask  = Color(0.88, 0.76, 0.08)
	# Aura exterior
	draw_circle(Vector2(cx, 65), 58, Color(gold.r, gold.g, gold.b, 0.06))
	draw_circle(Vector2(cx, 65), 50, Color(gold.r, gold.g, gold.b, 0.04))
	# Túnica masiva, bordes irregulares
	_fc([Vector2(cx-44,122), Vector2(cx+44,122),
		 Vector2(cx+26,36),  Vector2(cx-26,36)], gold)
	# Harapos izquierda (Simplificados para evitar fallos de triangulación)
	_fc([Vector2(cx-44,122), Vector2(cx-50,106), Vector2(cx-30,114)], dgold)
	_fc([Vector2(cx-50,106), Vector2(cx-26,36), Vector2(cx-30,114)], dgold)
	# Harapos derecha
	_fc([Vector2(cx+44,122), Vector2(cx+50,106), Vector2(cx+30,114)], dgold)
	_fc([Vector2(cx+50,106), Vector2(cx+26,36), Vector2(cx+30,114)], dgold)
	# Pecho/manto superior
	draw_rect(Rect2(cx-20, 22, 40, 16), dgold)
	draw_rect(Rect2(cx-16, 24, 32, 12), gold)
	# Máscara (cara sin facciones excepto los ojos)
	draw_circle(Vector2(cx, 12), 16, dgold)
	draw_circle(Vector2(cx, 11), 14, mask)
	draw_circle(Vector2(cx, 10), 11, Color(mask.r*1.06, mask.g*1.04, mask.b*0.94))
	# Agujeros de ojos (oscuridad absoluta + brillo interno)
	draw_circle(Vector2(cx-5, 9), 4, dgold.darkened(0.6))
	draw_circle(Vector2(cx+5, 9), 4, dgold.darkened(0.6))
	draw_circle(Vector2(cx-5, 9), 2, Color(gold.r, gold.g, gold.b, 0.7))
	draw_circle(Vector2(cx+5, 9), 2, Color(gold.r, gold.g, gold.b, 0.7))
	# Corona de tres puntas (cada una con un ojo)
	for i in 3:
		var sx = cx - 12 + i * 12
		_fc([Vector2(sx, -4), Vector2(sx-7, 10), Vector2(sx+7, 10)], gold)
		draw_circle(Vector2(sx, 4), 2.5, dgold)
		draw_circle(Vector2(sx, 4), 1.5, Color(0.8, 0.0, 0.0, 0.85))
	# Brazos/mangas (tentáculos que emergen de los costados)
	draw_line(Vector2(cx-26, 44), Vector2(cx-46, 54), dgold, 5.0)
	draw_line(Vector2(cx-46, 54), Vector2(cx-44, 70), dgold, 4.0)
	draw_line(Vector2(cx-44, 70), Vector2(cx-48, 80), dgold, 3.0)
	draw_line(Vector2(cx+26, 44), Vector2(cx+46, 54), dgold, 5.0)
	draw_line(Vector2(cx+46, 54), Vector2(cx+44, 70), dgold, 4.0)
	draw_line(Vector2(cx+44, 70), Vector2(cx+48, 80), dgold, 3.0)

# ── EL CENTINELA ABISAL (boss void) ───────────────────────────────────────────
func _draw_centinela(cx: float) -> void:
	var vblue = Color(0.16, 0.56, 0.88)
	var dvoid = Color(0.03, 0.08, 0.22)
	var glow  = Color(0.20, 0.82, 1.00)
	# Aura del vacío
	draw_circle(Vector2(cx, 62), 52, Color(vblue.r, vblue.g, vblue.b, 0.08))
	draw_circle(Vector2(cx, 62), 42, Color(vblue.r, vblue.g, vblue.b, 0.06))
	# Tentáculos del vacío (6 en total)
	draw_line(Vector2(cx-18,48), Vector2(cx-50,28), dvoid, 4.0)
	draw_line(Vector2(cx-50,28), Vector2(cx-56,40), dvoid, 2.5)
	draw_line(Vector2(cx-20,66), Vector2(cx-52,68), dvoid, 3.5)
	draw_line(Vector2(cx-52,68), Vector2(cx-56,80), dvoid, 2.5)
	draw_line(Vector2(cx+18,48), Vector2(cx+50,28), dvoid, 4.0)
	draw_line(Vector2(cx+50,28), Vector2(cx+56,40), dvoid, 2.5)
	draw_line(Vector2(cx+20,66), Vector2(cx+52,68), dvoid, 3.5)
	draw_line(Vector2(cx+52,68), Vector2(cx+56,80), dvoid, 2.5)
	draw_line(Vector2(cx, 108),  Vector2(cx-20,120), dvoid, 3.0)
	draw_line(Vector2(cx, 108),  Vector2(cx+20,120), dvoid, 3.0)
	# Armadura de caballero
	draw_rect(Rect2(cx-22,48, 44,58), dvoid)
	draw_rect(Rect2(cx-18,50, 36,52), vblue)
	draw_rect(Rect2(cx-14,52, 28,46), Color(vblue.r*1.1, vblue.g*1.1, vblue.b*1.12))
	# Hombreras
	draw_rect(Rect2(cx-34,48, 14,18), dvoid)
	draw_rect(Rect2(cx-30,50, 10,14), vblue)
	draw_rect(Rect2(cx+20,48, 14,18), dvoid)
	draw_rect(Rect2(cx+22,50, 10,14), vblue)
	# Núcleo brillante en el pecho
	draw_circle(Vector2(cx, 74), 12, dvoid)
	draw_circle(Vector2(cx, 74),  9, Color(glow.r, glow.g, glow.b, 0.95))
	draw_circle(Vector2(cx, 74),  6, Color(0.7, 1.0, 1.0, 0.95))
	draw_circle(Vector2(cx, 74),  3, Color(1.0, 1.0, 1.0, 1.0))
	# Cabeza / yelmo de caballero
	draw_rect(Rect2(cx-16,18, 32,32), dvoid)
	draw_rect(Rect2(cx-12,20, 24,28), vblue)
	draw_rect(Rect2(cx-9, 22, 18,24), Color(vblue.r*1.12, vblue.g*1.12, vblue.b*1.15))
	# Visera (ranura)
	draw_rect(Rect2(cx-10,30, 20, 5), dvoid)
	draw_circle(Vector2(cx-5, 32), 2.5, glow)
	draw_circle(Vector2(cx+5, 32), 2.5, glow)
	draw_circle(Vector2(cx-5, 32), 1.2, Color(0.8, 1.0, 1.0, 1.0))
	draw_circle(Vector2(cx+5, 32), 1.2, Color(0.8, 1.0, 1.0, 1.0))
	# Penacho
	_fc([Vector2(cx, 8), Vector2(cx-10,20), Vector2(cx+10,20)], vblue)
	_fc([Vector2(cx, 11), Vector2(cx-7, 20), Vector2(cx+7, 20)],
		Color(vblue.r*1.2, vblue.g*1.2, vblue.b*1.25))
	# Piernas
	draw_rect(Rect2(cx-18,104, 16,20), dvoid)
	draw_rect(Rect2(cx-15,106, 12,16), vblue)
	draw_rect(Rect2(cx+2, 104, 16,20), dvoid)
	draw_rect(Rect2(cx+4, 106, 12,16), vblue)

# ── Avatar de Hastur ───────────────────────────────────────────────────────────
func _draw_avatar_hastur(cx: float) -> void:
	var yel  = Color(0.90, 0.78, 0.05)
	var dyel = Color(0.28, 0.20, 0.00)
	# Aura exterior
	draw_circle(Vector2(cx, 62), 56, Color(yel.r, yel.g, yel.b, 0.07))
	# Forma principal (amorfa)
	_fc([Vector2(cx-32,110), Vector2(cx+32,110),
		 Vector2(cx+30, 44), Vector2(cx+12, 28),
		 Vector2(cx-12, 28), Vector2(cx-30, 44)], dyel)
	_fc([Vector2(cx-26,108), Vector2(cx+26,108),
		 Vector2(cx+25, 46), Vector2(cx+10, 30),
		 Vector2(cx-10, 30), Vector2(cx-25, 46)], yel)
	_fc([Vector2(cx-18,106), Vector2(cx+18,106),
		 Vector2(cx+18, 50), Vector2(cx+6,  34),
		 Vector2(cx-6,  34), Vector2(cx-18, 50)],
		Color(yel.r*1.08, yel.g*1.06, yel.b*0.95))
	# Tentáculos (3 a cada lado)
	draw_line(Vector2(cx-25, 54), Vector2(cx-50, 38), dyel, 5.0)
	draw_line(Vector2(cx-50, 38), Vector2(cx-55, 52), dyel, 3.5)
	draw_line(Vector2(cx-25, 70), Vector2(cx-52, 72), dyel, 4.5)
	draw_line(Vector2(cx-52, 72), Vector2(cx-56, 86), dyel, 3.0)
	draw_line(Vector2(cx-22, 88), Vector2(cx-46, 96), dyel, 3.5)
	draw_line(Vector2(cx+25, 54), Vector2(cx+50, 38), dyel, 5.0)
	draw_line(Vector2(cx+50, 38), Vector2(cx+55, 52), dyel, 3.5)
	draw_line(Vector2(cx+25, 70), Vector2(cx+52, 72), dyel, 4.5)
	draw_line(Vector2(cx+52, 72), Vector2(cx+56, 86), dyel, 3.0)
	draw_line(Vector2(cx+22, 88), Vector2(cx+46, 96), dyel, 3.5)
	# Cara (máscara con múltiples ojos)
	draw_circle(Vector2(cx, 20), 16, dyel)
	draw_circle(Vector2(cx, 19), 14, yel)
	draw_circle(Vector2(cx, 18), 11, Color(yel.r*1.06, yel.g*1.04, yel.b*0.92))
	# 5 ojos (2 principales + 3 secundarios pequeños)
	_eye(Vector2(cx-5, 16), 4.5, Color(0.80, 0.0, 0.0, 0.9), false)
	_eye(Vector2(cx+5, 16), 4.5, Color(0.80, 0.0, 0.0, 0.9), false)
	draw_circle(Vector2(cx,    22), 2.5, dyel.darkened(0.2))
	draw_circle(Vector2(cx,    22), 1.5, Color(1.0, 0.9, 0.0, 0.9))
	draw_circle(Vector2(cx-10, 20), 2.0, dyel.darkened(0.2))
	draw_circle(Vector2(cx-10, 20), 1.2, Color(1.0, 0.9, 0.0, 0.9))
	draw_circle(Vector2(cx+10, 20), 2.0, dyel.darkened(0.2))
	draw_circle(Vector2(cx+10, 20), 1.2, Color(1.0, 0.9, 0.0, 0.9))

# ── EL VERDADERO HASTUR (forma final) ─────────────────────────────────────────
func _draw_hastur_final(cx: float) -> void:
	_draw_avatar_hastur(cx)
	# Arcos de distorsión caótica
	draw_arc(Vector2(cx, 62), 50, 0.28,      2.48,     24, Color(0.92, 0.80, 0.05, 0.24), 3.0)
	draw_arc(Vector2(cx, 62), 44, PI+0.4,    PI+2.3,   20, Color(0.92, 0.80, 0.05, 0.20), 2.5)
	draw_arc(Vector2(cx, 62), 38, 0.1,       1.2,      14, Color(0.92, 0.80, 0.05, 0.18), 2.0)
	# Gran ojo central en el pecho
	draw_circle(Vector2(cx, 62), 14, Color(0.25, 0.18, 0.00))
	draw_circle(Vector2(cx, 62), 11, Color(0.95, 0.85, 0.02, 0.95))
	draw_circle(Vector2(cx, 62),  7, Color(0.20, 0.05, 0.00, 0.98))
	draw_circle(Vector2(cx, 62),  4, Color(0.95, 0.85, 0.02, 0.90))
	draw_circle(Vector2(cx, 62),  2, Color(0.00, 0.00, 0.00, 0.98))
