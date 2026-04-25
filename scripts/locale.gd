## Tiny i18n autoload. Loads locale dictionaries from data/locale_<code>.json
## and exposes `t(key, args)` for string interpolation. Locale choice is
## persisted to user://settings.cfg between sessions so the player only has
## to pick a language once.
extends Node

signal locale_changed(code: String)

const SETTINGS_PATH := "user://settings.cfg"

const LOCALES := {
	"en": "res://data/locale_en.json",
	"ru": "res://data/locale_ru.json",
}

var current: String = "en"
var _table: Dictionary = {}
var _fallback: Dictionary = {}

func _ready() -> void:
	_fallback = _load_locale_file("en")
	_load_persisted()
	set_locale(current)

func _load_locale_file(code: String) -> Dictionary:
	var path: String = String(LOCALES.get(code, ""))
	if path == "":
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Locale file missing: %s" % path)
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("Invalid JSON locale: %s" % path)
		return {}
	return parsed

func _load_persisted() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current = String(cfg.get_value("ui", "locale", "en"))

func _persist() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "locale", current)
	cfg.save(SETTINGS_PATH)

func set_locale(code: String) -> void:
	current = code
	_table = _load_locale_file(code)
	_persist()
	locale_changed.emit(code)

## Translate a key. Falls back to English, then to the raw key.
## If `args` is provided, the resulting string is formatted via `%`.
func t(key: String, args: Variant = null) -> String:
	var raw: String = String(_table.get(key, _fallback.get(key, key)))
	if args == null:
		return raw
	return raw % args

func locale_codes() -> Array:
	return LOCALES.keys()

func locale_label(code: String) -> String:
	match code:
		"en": return "English"
		"ru": return "Русский"
		_:    return code
