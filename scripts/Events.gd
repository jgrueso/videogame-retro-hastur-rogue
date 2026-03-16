extends Node

# Este script Autoload (Singleton) actúa como un bus de eventos global.
# Permite que diferentes partes del juego se comuniquen sin tener dependencias directas.

# --- Eventos de Combate ---
signal relic_was_chosen(relic_id: String)
signal combat_ended

# --- Eventos Generales del Juego ---
signal scene_change_requested(scene_path: String)
signal player_hp_changed(new_hp: int)
signal player_sanity_changed(new_sanity: int)
