## Main menu: pick era + country, start game.
extends Control

var selected_era: String = "antiquity"
var selected_country: String = "ROM"
var country_grid: GridContainer
var era_buttons: Array[Button] = []
var country_buttons: Dictionary = {} # cid -> Button
var start_button: Button
var preview_label: RichTextLabel

const BG_COLOR := Color(0.07, 0.10, 0.16, 1.0)

func _ready() -> void:
	custom_minimum_size = Vector2(1600, 900)
	# Background panel
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "HISTORY OF THE WORLD"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title.position = Vector2(60, 40)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Geopolitical simulator across the ages"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	subtitle.position = Vector2(64, 110)
	add_child(subtitle)

	# Era selector
	var era_label := Label.new()
	era_label.text = "ERA"
	era_label.add_theme_font_size_override("font_size", 22)
	era_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	era_label.position = Vector2(60, 180)
	add_child(era_label)

	var era_row := HBoxContainer.new()
	era_row.position = Vector2(60, 220)
	era_row.size = Vector2(1480, 60)
	add_child(era_row)
	var eras_keys := ["antiquity", "medieval", "renaissance", "industrial", "modern"]
	for ek in eras_keys:
		var btn := Button.new()
		var def: Dictionary = GameState.eras_db.get(ek, {})
		btn.text = String(def.get("name", ek))
		btn.custom_minimum_size = Vector2(220, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_era_selected.bind(ek))
		era_row.add_child(btn)
		era_buttons.append(btn)

	# Country grid
	var c_label := Label.new()
	c_label.text = "PLAYABLE NATION"
	c_label.add_theme_font_size_override("font_size", 22)
	c_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	c_label.position = Vector2(60, 300)
	add_child(c_label)

	var grid_panel := PanelContainer.new()
	grid_panel.position = Vector2(60, 340)
	grid_panel.size = Vector2(900, 380)
	add_child(grid_panel)
	var grid_scroll := ScrollContainer.new()
	grid_panel.add_child(grid_scroll)
	grid_scroll.custom_minimum_size = Vector2(900, 380)
	country_grid = GridContainer.new()
	country_grid.columns = 4
	country_grid.add_theme_constant_override("h_separation", 8)
	country_grid.add_theme_constant_override("v_separation", 8)
	grid_scroll.add_child(country_grid)

	# Preview
	var preview_panel := PanelContainer.new()
	preview_panel.position = Vector2(990, 340)
	preview_panel.size = Vector2(560, 380)
	add_child(preview_panel)
	var pmargin := MarginContainer.new()
	pmargin.add_theme_constant_override("margin_top", 16)
	pmargin.add_theme_constant_override("margin_left", 16)
	pmargin.add_theme_constant_override("margin_right", 16)
	pmargin.add_theme_constant_override("margin_bottom", 16)
	preview_panel.add_child(pmargin)
	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.fit_content = true
	pmargin.add_child(preview_label)

	# Start
	start_button = Button.new()
	start_button.text = "BEGIN CAMPAIGN"
	start_button.add_theme_font_size_override("font_size", 26)
	start_button.position = Vector2(60, 760)
	start_button.size = Vector2(360, 80)
	start_button.pressed.connect(_on_start)
	add_child(start_button)

	var hint := Label.new()
	hint.text = "Controls: WASD/arrows = pan, wheel = zoom, click province, right-click = move/sail, Space = pause, +/- = speed, F1 = diplomacy, F2 = court, F3 = tech, H = help, F5 = save, F9 = load"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	hint.position = Vector2(60, 850)
	hint.size = Vector2(1480, 30)
	add_child(hint)

	_select_era(selected_era)

func _on_era_selected(era_id: String) -> void:
	_select_era(era_id)

func _select_era(era_id: String) -> void:
	selected_era = era_id
	for i in range(era_buttons.size()):
		var ek = ["antiquity", "medieval", "renaissance", "industrial", "modern"][i]
		era_buttons[i].modulate = Color(1.2, 1.1, 0.5) if ek == era_id else Color(1.0, 1.0, 1.0)
	# Rebuild country grid
	for child in country_grid.get_children():
		country_grid.remove_child(child)
		child.queue_free()
	country_buttons.clear()
	var era_def: Dictionary = GameState.eras_db.get(era_id, {})
	var starters: Array = era_def.get("starting_countries", [])
	for cid in starters:
		var def: Dictionary = GameState.countries_db.get(cid, {})
		if def.is_empty(): continue
		var btn := Button.new()
		btn.text = String(def.get("name", cid))
		btn.custom_minimum_size = Vector2(210, 60)
		btn.add_theme_font_size_override("font_size", 17)
		var col_arr: Array = def.get("color", [0.5, 0.5, 0.5])
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = Color(col_arr[0], col_arr[1], col_arr[2], 0.7)
		stylebox.border_color = Color(0.95, 0.95, 0.95, 0.5)
		stylebox.border_width_top = 2
		stylebox.border_width_bottom = 2
		stylebox.border_width_left = 2
		stylebox.border_width_right = 2
		stylebox.corner_radius_top_left = 6
		stylebox.corner_radius_top_right = 6
		stylebox.corner_radius_bottom_left = 6
		stylebox.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", stylebox)
		btn.pressed.connect(_on_country_selected.bind(cid))
		country_grid.add_child(btn)
		country_buttons[cid] = btn
	if starters.size() > 0:
		_on_country_selected(String(starters[0]))

func _on_country_selected(cid: String) -> void:
	selected_country = cid
	var def: Dictionary = GameState.countries_db.get(cid, {})
	var era_def: Dictionary = GameState.eras_db.get(selected_era, {})
	preview_label.text = "[b][color=#f4d35e]%s[/color][/b]\n[i]%s[/i]\n\n" % [String(def.get("name", cid)), String(era_def.get("name", selected_era))]
	preview_label.text += "Era: [b]%s[/b]\n" % String(def.get("era", selected_era)).capitalize()
	preview_label.text += "Government: [b]%s[/b]\n" % String(def.get("government", "?")).capitalize()
	preview_label.text += "Culture: [b]%s[/b]\n" % String(def.get("culture", "?")).capitalize()
	preview_label.text += "Religion: [b]%s[/b]\n" % String(def.get("religion", "?")).capitalize()
	preview_label.text += "Region: [b]%s[/b]\n\n" % String(def.get("region", "?")).capitalize()
	preview_label.text += "Lead this nation through diplomacy, intrigue, war, science and culture from %d to ~%d." % [int(era_def.get("year_start", 0)), int(era_def.get("year_end", 0))]

func _on_start() -> void:
	GameState.player_country_id = selected_country
	WorldGen.generate(selected_era)
	# Mark player country
	var pc: Country = GameState.countries.get(selected_country)
	if pc != null:
		pc.is_player = true
		pc.is_ai = false
	# Start paused
	GameState.paused = true
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
