# 🌑 GEMINI.md - BLACK HOLE SONG (checkmate-rogue)

Este archivo es el contexto fundacional para **BLACK HOLE SONG**, un roguelike de construcción de mazos basado en el lore de **Hastur** y el **Rey Amarillo**.

---

## 🕯️ Misión y Estética

- **Tono**: Horror cósmico medieval, grotesco, opresivo.
- **Mecánica Core**: Combate táctico por turnos (ajedrez) donde la **Cordura** es un recurso tan vital como la vida.
- **Visuales**: Pixel Art procedimental, efectos estroboscópicos, flashes subliminales.
- **Audio**: Generación procedural atmosférica.

## 🛠️ Stack Tecnológico

- **Motor**: Godot Engine 4.x.
- **Lenguaje**: GDScript (con tipado estático siempre que sea posible).
- **Estructura**:
  - `/scenes/combat`: Lógica de enfrentamientos.
  - `/scenes/ui`: Interfaz de usuario (Menú, Selección de Personaje, Inventario).
  - `/scripts/Combat.gd`: Núcleo de combate (80KB+, manejar con cuidado).
  - `/scripts/Card.gd`: Definición y lógica de cartas.
  - `/scripts/LoreData.gd`: Datos narrativos y secretos de Carcosa.

## 📜 Reglas de Implementación

1.  **Tipado Estático**: Usa `var nombre: Tipo = valor` en GDScript para evitar errores en tiempo de ejecución.
2.  **Organización de Scripts**:
    - `extends` -> `class_name` -> `signals` -> `enums` -> `constants` -> `variables (@onready / @export)` -> `_ready` -> `funciones públicas` -> `funciones privadas`.
3.  **Atmósfera**: Cualquier cambio en la UI o efectos visuales debe respetar la paleta de colores (Rojo/Verde/Azul según el personaje) y el tema de "El Rey Amarillo" (dorado, ceniza, lluvia).
4.  **Sistema de Cordura**: No es solo un número; afecta visualmente la UI y altera el texto de los nombres de los enemigos (LoreData).

## ♜ Personajes (The Pieces)

- **El Conquistador (Rojo)**: Agresivo, daño acumulativo por muertes.
- **El Estratega (Azul)**: Táctico, control del tablero y robo de cartas.
- **El Guardián (Verde)**: Defensivo, mecánica de furia (contraataque x2).

## 📍 Estado Actual (Marzo 2026)

- **Último hito**: Refactor masivo de combate, mejoras en la inmersión de cordura y balance de personajes.
- **Pendiente**: Afinar sinergias de reliquias y posiblemente nuevos "Augurios" (eventos) en `Event.gd`.

---

_"Dime, ¿has visto el Signo Amarillo?"_ 👑
