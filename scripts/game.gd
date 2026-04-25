## Main gameplay scene: builds map, camera, UI, panels.
extends Node2D

const MovementBattleScript = preload("res://scripts/movement_battle.gd")

var camera: Camera2D
var map: Node2D
var ui_layer: CanvasLayer

var top_bar: PanelContainer
var top_bar_label: RichTextLabel
var date_label: Label
var pause_label: Label

var province_panel: PanelContainer
var province_panel_text: RichTextLabel
var province_panel_recruit: Button
var province_panel_recruit_navy: Button
var province_panel_move_to: Button
var province_panel_assign_general: Button
var province_panel_convert_religion: Button
var province_panel_convert_culture: Button
var province_panel_close: Button
var province_panel_build_btns: HBoxContainer

var minimap_panel: PanelContainer
var minimap_view: Control
var help_panel: PanelContainer
var help_panel_text: RichTextLabel
var help_panel_close: Button
var hotkey_hint: Label

var diplomacy_panel: PanelContainer
var diplomacy_list: VBoxContainer
var diplomacy_title: Label
var diplomacy_close: Button
var character_panel: PanelContainer
var character_text: RichTextLabel
var character_title: Label
var character_close: Button
var tech_panel: PanelContainer
var tech_list: VBoxContainer
var tech_title: Label
var tech_close: Button
var save_panel: PanelContainer
var save_title: Label
var save_btn: Button
var load_btn: Button
var save_close: Button
var event_log_label: RichTextLabel

var hovered_province: int = -1
var move_mode_unit: int = -1

var movement_battle: Node

func _ready() -> void:
	# Add the movement/battle controller as a child node so its _ready connects signals.
	movement_battle = MovementBattleScript.new()
	add_child(movement_battle)

	map = Node2D.new()
	map.name = "Map"
	map.set_script(load("res://scripts/map_view.gd"))
	add_child(map)

	camera = Camera2D.new()
	camera.set_script(load("res://scripts/camera_controller.gd"))
	camera.position = Vector2(GameState.MAP_W / 2.0, GameState.MAP_H / 2.0)
	camera.zoom = Vector2(0.55, 0.55)
	camera.enabled = true
	add_child(camera)

	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_build_ui()

	GameState.country_state_changed.connect(_on_country_state_changed)
	GameState.date_changed.connect(_on_date_changed)
	GameState.selection_changed.connect(_on_selection_changed)
	GameState.log_message.connect(_on_log_message)
	Locale.locale_changed.connect(func(_c): _apply_locale())
	_apply_locale()
	_refresh_top_bar()
	_refresh_event_log()

# ---------- UI BUILD ----------

func _build_ui() -> void:
	# Top bar
	top_bar = PanelContainer.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1600, 56)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.92)
	sb.border_color = Color(0.4, 0.5, 0.7, 0.8)
	sb.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(top_bar)

	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 24)
	top_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_bar.add_child(top_h)
	top_bar_label = RichTextLabel.new()
	top_bar_label.bbcode_enabled = true
	top_bar_label.fit_content = true
	top_bar_label.scroll_active = false
	top_bar_label.custom_minimum_size = Vector2(1100, 50)
	top_h.add_child(top_bar_label)

	date_label = Label.new()
	date_label.add_theme_font_size_override("font_size", 18)
	date_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	date_label.custom_minimum_size = Vector2(220, 50)
	top_h.add_child(date_label)

	pause_label = Label.new()
	pause_label.add_theme_font_size_override("font_size", 18)
	pause_label.text = "[ PAUSED ]"
	pause_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	pause_label.custom_minimum_size = Vector2(160, 50)
	top_h.add_child(pause_label)

	# Right-side hint hotkeys
	var hk := Label.new()
	hotkey_hint = hk
	hk.text = _hotkey_hint_text()
	hk.add_theme_font_size_override("font_size", 13)
	hk.add_theme_color_override("font_color", Color(0.65, 0.7, 0.85))
	hk.position = Vector2(1180, 18)
	top_bar.add_child(hk)

	# Province panel
	province_panel = PanelContainer.new()
	province_panel.position = Vector2(20, 70)
	province_panel.size = Vector2(360, 380)
	province_panel.visible = false
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.08, 0.13, 0.92)
	psb.border_color = Color(0.5, 0.6, 0.85, 0.7)
	psb.border_width_left = 2
	psb.border_width_right = 2
	psb.border_width_top = 2
	psb.border_width_bottom = 2
	psb.corner_radius_top_left = 8
	psb.corner_radius_top_right = 8
	psb.corner_radius_bottom_left = 8
	psb.corner_radius_bottom_right = 8
	province_panel.add_theme_stylebox_override("panel", psb)
	ui_layer.add_child(province_panel)
	var pmargin := MarginContainer.new()
	pmargin.add_theme_constant_override("margin_top", 12)
	pmargin.add_theme_constant_override("margin_left", 14)
	pmargin.add_theme_constant_override("margin_right", 14)
	pmargin.add_theme_constant_override("margin_bottom", 12)
	province_panel.add_child(pmargin)
	var pvb := VBoxContainer.new()
	pmargin.add_child(pvb)
	province_panel_text = RichTextLabel.new()
	province_panel_text.bbcode_enabled = true
	province_panel_text.fit_content = true
	province_panel_text.custom_minimum_size = Vector2(330, 240)
	pvb.add_child(province_panel_text)
	province_panel_recruit = Button.new()
	province_panel_recruit.pressed.connect(_on_recruit_pressed)
	pvb.add_child(province_panel_recruit)
	province_panel_recruit_navy = Button.new()
	province_panel_recruit_navy.pressed.connect(_on_recruit_navy_pressed)
	pvb.add_child(province_panel_recruit_navy)
	province_panel_build_btns = HBoxContainer.new()
	province_panel_build_btns.add_theme_constant_override("separation", 4)
	pvb.add_child(province_panel_build_btns)
	province_panel_convert_religion = Button.new()
	province_panel_convert_religion.pressed.connect(_on_convert_religion_pressed)
	pvb.add_child(province_panel_convert_religion)
	province_panel_convert_culture = Button.new()
	province_panel_convert_culture.pressed.connect(_on_convert_culture_pressed)
	pvb.add_child(province_panel_convert_culture)
	province_panel_move_to = Button.new()
	province_panel_move_to.pressed.connect(_on_move_to_pressed)
	pvb.add_child(province_panel_move_to)
	province_panel_assign_general = Button.new()
	province_panel_assign_general.pressed.connect(_on_assign_general_pressed)
	pvb.add_child(province_panel_assign_general)
	province_panel_close = Button.new()
	province_panel_close.pressed.connect(_close_province_panel)
	pvb.add_child(province_panel_close)

	# Diplomacy panel
	diplomacy_panel = _build_panel(Vector2(420, 70), Vector2(900, 700))
	diplomacy_panel.visible = false
	var dpm := MarginContainer.new()
	dpm.add_theme_constant_override("margin_top", 12)
	dpm.add_theme_constant_override("margin_left", 14)
	dpm.add_theme_constant_override("margin_right", 14)
	dpm.add_theme_constant_override("margin_bottom", 12)
	diplomacy_panel.add_child(dpm)
	var dpv := VBoxContainer.new()
	dpm.add_child(dpv)
	diplomacy_title = Label.new()
	var dh := diplomacy_title
	dh.text = "DIPLOMACY"
	dh.add_theme_font_size_override("font_size", 24)
	dh.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	dpv.add_child(dh)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(870, 580)
	dpv.add_child(scroll)
	diplomacy_list = VBoxContainer.new()
	diplomacy_list.add_theme_constant_override("separation", 6)
	scroll.add_child(diplomacy_list)
	diplomacy_close = Button.new()
	var d_close := diplomacy_close
	d_close.pressed.connect(func(): diplomacy_panel.visible = false)
	dpv.add_child(d_close)

	# Character panel
	character_panel = _build_panel(Vector2(420, 70), Vector2(900, 700))
	character_panel.visible = false
	var cpm := MarginContainer.new()
	cpm.add_theme_constant_override("margin_top", 12)
	cpm.add_theme_constant_override("margin_left", 14)
	cpm.add_theme_constant_override("margin_right", 14)
	cpm.add_theme_constant_override("margin_bottom", 12)
	character_panel.add_child(cpm)
	var cvb := VBoxContainer.new()
	cpm.add_child(cvb)
	character_title = Label.new()
	var ch := character_title
	ch.text = "COURT & MILITARY"
	ch.add_theme_font_size_override("font_size", 24)
	ch.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	cvb.add_child(ch)
	character_text = RichTextLabel.new()
	character_text.bbcode_enabled = true
	character_text.fit_content = true
	character_text.custom_minimum_size = Vector2(870, 580)
	character_text.scroll_active = true
	cvb.add_child(character_text)
	character_close = Button.new()
	var c_close := character_close
	c_close.pressed.connect(func(): character_panel.visible = false)
	cvb.add_child(c_close)

	# Tech panel
	tech_panel = _build_panel(Vector2(420, 70), Vector2(900, 700))
	tech_panel.visible = false
	var tpm := MarginContainer.new()
	tpm.add_theme_constant_override("margin_top", 12)
	tpm.add_theme_constant_override("margin_left", 14)
	tpm.add_theme_constant_override("margin_right", 14)
	tpm.add_theme_constant_override("margin_bottom", 12)
	tech_panel.add_child(tpm)
	var tvb := VBoxContainer.new()
	tpm.add_child(tvb)
	tech_title = Label.new()
	var th := tech_title
	th.text = "TECHNOLOGY"
	th.add_theme_font_size_override("font_size", 24)
	th.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	tvb.add_child(th)
	var t_scroll := ScrollContainer.new()
	t_scroll.custom_minimum_size = Vector2(870, 580)
	tvb.add_child(t_scroll)
	tech_list = VBoxContainer.new()
	tech_list.add_theme_constant_override("separation", 4)
	t_scroll.add_child(tech_list)
	tech_close = Button.new()
	var t_close := tech_close
	t_close.pressed.connect(func(): tech_panel.visible = false)
	tvb.add_child(t_close)

	# Save/load mini panel
	save_panel = _build_panel(Vector2(640, 280), Vector2(380, 220))
	save_panel.visible = false
	var spm := MarginContainer.new()
	spm.add_theme_constant_override("margin_top", 16)
	spm.add_theme_constant_override("margin_left", 16)
	spm.add_theme_constant_override("margin_right", 16)
	spm.add_theme_constant_override("margin_bottom", 16)
	save_panel.add_child(spm)
	var spv := VBoxContainer.new()
	spm.add_child(spv)
	save_title = Label.new()
	var slbl := save_title
	slbl.text = "Save / Load"
	slbl.add_theme_font_size_override("font_size", 22)
	slbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	spv.add_child(slbl)
	save_btn = Button.new()
	save_btn.pressed.connect(func(): SaveLoad.save("main"); save_panel.visible = false)
	spv.add_child(save_btn)
	load_btn = Button.new()
	load_btn.pressed.connect(_on_load_pressed)
	spv.add_child(load_btn)
	save_close = Button.new()
	save_close.pressed.connect(func(): save_panel.visible = false)
	spv.add_child(save_close)

	# Event log (bottom-right)
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(1100, 700)
	log_panel.size = Vector2(490, 200)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.04, 0.07, 0.12, 0.85)
	lsb.border_color = Color(0.4, 0.5, 0.7, 0.4)
	lsb.border_width_top = 1
	lsb.border_width_left = 1
	lsb.border_width_right = 1
	lsb.border_width_bottom = 1
	lsb.corner_radius_top_left = 6
	lsb.corner_radius_top_right = 6
	lsb.corner_radius_bottom_left = 6
	lsb.corner_radius_bottom_right = 6
	log_panel.add_theme_stylebox_override("panel", lsb)
	ui_layer.add_child(log_panel)
	var lmm := MarginContainer.new()
	lmm.add_theme_constant_override("margin_top", 8)
	lmm.add_theme_constant_override("margin_left", 10)
	lmm.add_theme_constant_override("margin_right", 10)
	lmm.add_theme_constant_override("margin_bottom", 8)
	log_panel.add_child(lmm)
	event_log_label = RichTextLabel.new()
	event_log_label.bbcode_enabled = true
	event_log_label.scroll_active = true
	event_log_label.scroll_following = true
	event_log_label.fit_content = false
	event_log_label.custom_minimum_size = Vector2(470, 184)
	lmm.add_child(event_log_label)
	_build_minimap()
	_build_help_panel()

func _build_panel(pos: Vector2, sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.95)
	sb.border_color = Color(0.5, 0.6, 0.85, 0.7)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	p.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(p)
	return p

# ---------- INPUT ----------

func _input(event: InputEvent) -> void:
	# Use _input (not _unhandled_input) so global hotkeys still fire even
	# when a Button or panel has keyboard focus.
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match event.keycode:
			KEY_SPACE:
				GameState.paused = not GameState.paused
				_refresh_top_bar()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				GameState.speed = min(5, GameState.speed + 1)
				_refresh_top_bar()
			KEY_MINUS, KEY_KP_SUBTRACT:
				GameState.speed = max(1, GameState.speed - 1)
				_refresh_top_bar()
			KEY_F1:
				diplomacy_panel.visible = not diplomacy_panel.visible
				if diplomacy_panel.visible:
					_refresh_diplomacy()
			KEY_F2:
				character_panel.visible = not character_panel.visible
				if character_panel.visible:
					_refresh_characters()
			KEY_F3:
				tech_panel.visible = not tech_panel.visible
				if tech_panel.visible:
					_refresh_tech()
			KEY_H, KEY_QUESTION:
				_toggle_help_panel()
			KEY_F5:
				SaveLoad.save("main")
			KEY_F9:
				if SaveLoad.load_save("main"):
					get_tree().reload_current_scene()
			KEY_ESCAPE:
				diplomacy_panel.visible = false
				character_panel.visible = false
				tech_panel.visible = false
				save_panel.visible = false
				help_panel.visible = false
				province_panel.visible = false
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()

# ---------- SIGNAL HANDLERS ----------

func _on_date_changed(_y: int, _m: int, _d: int) -> void:
	_refresh_top_bar()

func _on_country_state_changed(cid: String) -> void:
	if cid == GameState.player_country_id:
		_refresh_top_bar()

func _on_selection_changed(pid: int) -> void:
	if pid >= 0:
		province_panel.visible = true
		_refresh_province_panel()
	else:
		province_panel.visible = false

func _on_log_message(_text: String, _color: Color) -> void:
	_refresh_event_log()

# ---------- REFRESH ----------

func _refresh_top_bar() -> void:
	var c: Country = GameState.countries.get(GameState.player_country_id)
	if c == null:
		return
	var income_estimate: float = 0.0
	for pid in c.province_ids:
		income_estimate += GameState.provinces[pid].base_tax()
	top_bar_label.text = "[b][color=#f1c40f]%s[/color][/b]   " % c.name
	top_bar_label.text += "[color=#f1c40f]%s[/color]: %d (%+.1f/m)   " % [Locale.t("TOP_GOLD"), int(c.gold), income_estimate]
	top_bar_label.text += "[color=#e74c3c]%s[/color]: %d   " % [Locale.t("TOP_MANPOWER"), int(c.manpower_pool)]
	top_bar_label.text += "[color=#3498db]%s[/color]: %d   " % [Locale.t("TOP_RESEARCH"), int(c.research_points)]
	top_bar_label.text += "[color=#9b59b6]%s[/color]: %d   " % [Locale.t("TOP_CULTURE_PT"), int(c.culture_points)]
	top_bar_label.text += "[color=#2ecc71]%s[/color]: %.1f   " % [Locale.t("TOP_STABILITY"), c.stability]
	top_bar_label.text += "[color=#f39c12]%s[/color]: %d   " % [Locale.t("TOP_PRESTIGE"), int(c.prestige)]
	# Religious + cultural unity (% of own provinces matching state religion / culture)
	var ru: float = _religious_unity(c)
	var cu: float = _cultural_unity(c)
	top_bar_label.text += "[color=#e8c39a]%s[/color]: %d%%   " % [Locale.t("TOP_RELIGIOUS_UNITY"), int(round(ru * 100.0))]
	top_bar_label.text += "[color=#e8c39a]%s[/color]: %d%%" % [Locale.t("TOP_CULTURAL_UNITY"), int(round(cu * 100.0))]
	date_label.text = GameState.date_string()
	if GameState.paused:
		pause_label.text = "[ %s ]" % Locale.t("TOP_PAUSED")
		pause_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	else:
		pause_label.text = ">> %s %d" % [Locale.t("TOP_SPEED"), GameState.speed]
		pause_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))

func _refresh_province_panel() -> void:
	var pid := GameState.selected_province_id
	if pid < 0:
		province_panel.visible = false
		return
	var p: Province = GameState.get_province(pid)
	if p == null: return
	var owner_name := Locale.t("PANEL_UNCLAIMED")
	var owner_color := "#888888"
	if p.owner_id != "":
		var oc: Country = GameState.countries.get(p.owner_id)
		if oc != null:
			owner_name = oc.name
			owner_color = "#%02x%02x%02x" % [int(oc.color.r * 255), int(oc.color.g * 255), int(oc.color.b * 255)]
	var t := "[b][color=#f1c40f]%s[/color][/b]" % p.name
	if p.is_capital:
		t += "  [color=#f4d35e]★ %s[/color]" % Locale.t("PANEL_CAPITAL")
	t += "\n"
	t += "[color=%s]%s[/color]\n" % [owner_color, owner_name]
	t += "%s: %s\n" % [Locale.t("PANEL_TERRAIN"), _terrain_name(p)]
	if not p.is_sea:
		t += "%s: [b]%d[/b]    %s: %d\n" % [Locale.t("PANEL_DEVELOPMENT"), p.development, Locale.t("PANEL_POPULATION"), p.population]
		t += "%s: %s    %s: %s\n" % [Locale.t("PANEL_CULTURE"), p.culture, Locale.t("PANEL_RELIGION"), p.religion]
		var res_label := Locale.t("RESOURCE_NONE") if p.resource == "" else _resource_label(p.resource)
		t += "%s: [color=#e0c080]%s[/color]\n" % [Locale.t("PANEL_RESOURCE"), res_label]
		t += "%s: %d   %s: %.1f\n" % [Locale.t("PANEL_GARRISON"), p.garrison, Locale.t("PANEL_UNREST"), p.unrest]
		# Buildings
		var bld_text := ""
		if p.buildings.size() > 0:
			var parts: Array[String] = []
			for b_id in p.buildings:
				parts.append(_building_name(b_id))
			bld_text = ", ".join(parts)
		else:
			bld_text = Locale.t("PANEL_BUILDINGS_NONE")
		t += "%s: %s\n" % [Locale.t("PANEL_BUILDINGS"), bld_text]
		# Active building
		if p.build_id != "":
			var bdef: Dictionary = GameState.buildings_db.get(p.build_id, {})
			var months: int = int(bdef.get("build_months", 1))
			var pct: int = int(round((p.build_progress_months / max(1.0, float(months))) * 100.0))
			t += "[color=#a0c0ff]%s: %s[/color]\n" % [Locale.t("PANEL_BUILDING_AT"), Locale.t("PANEL_BUILDING_IN_PROGRESS") % [_building_name(p.build_id), pct]]
		# Active conversions
		if p.convert_religion_to != "":
			t += "[color=#d0a0e8]→ %s (%d mo)[/color]\n" % [p.convert_religion_to, int(p.convert_religion_months)]
		if p.convert_culture_to != "":
			t += "[color=#a0e8d0]→ %s (%d mo)[/color]\n" % [p.convert_culture_to, int(p.convert_culture_months)]
	# Units in province
	var present_units := []
	for uid in GameState.units.keys():
		var u: ArmyUnit = GameState.units[uid]
		if u.province_id == pid:
			present_units.append(u)
	if present_units.size() > 0:
		t += "\n[b]%s:[/b]\n" % Locale.t("PANEL_ARMIES_PRESENT")
		for u in present_units:
			var oc2: Country = GameState.countries.get(u.owner_id)
			var ut: Dictionary = GameState.unit_types.get(u.type_id, {})
			var o_color: String = "#%02x%02x%02x" % [int(oc2.color.r * 255), int(oc2.color.g * 255), int(oc2.color.b * 255)] if oc2 != null else "#888888"
			t += "  • [color=%s]%s[/color] %s (str %d, mor %.1f)\n" % [o_color, oc2.name if oc2 != null else u.owner_id, ut.get("name", u.type_id), u.strength, u.morale]
	province_panel_text.text = t

	# Buttons enabled depending on selection
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	var owns_province: bool = pc != null and pc.province_ids.has(pid)
	province_panel_recruit.visible = owns_province and not p.is_sea
	province_panel_recruit_navy.visible = owns_province and p.is_coast
	province_panel_move_to.visible = move_mode_unit != -1
	province_panel_assign_general.visible = move_mode_unit != -1 and pc != null and pc.general_ids.size() > 0
	# Conversion / culture buttons.
	province_panel_convert_religion.visible = owns_province and not p.is_sea and pc != null and p.religion != pc.state_religion
	province_panel_convert_culture.visible = owns_province and not p.is_sea and pc != null and p.culture != pc.primary_culture
	# Building buttons.
	_rebuild_building_buttons(p, owns_province)

func _refresh_event_log() -> void:
	if event_log_label == null:
		return
	var lines: Array = []
	var start: int = maxi(0, GameState.event_log.size() - 30)
	for i in range(start, GameState.event_log.size()):
		lines.append(GameState.event_log[i])
	event_log_label.text = "\n".join(lines)

func _refresh_diplomacy() -> void:
	for child in diplomacy_list.get_children():
		diplomacy_list.remove_child(child)
		child.queue_free()
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null:
		return
	for cid in GameState.countries.keys():
		if cid == pc.id: continue
		var oc: Country = GameState.countries[cid]
		if not oc.is_alive: continue
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(oc.color.r, oc.color.g, oc.color.b, 0.18)
		sb.border_color = Color(0.6, 0.7, 0.9, 0.4)
		sb.border_width_left = 4
		sb.corner_radius_top_left = 4
		sb.corner_radius_bottom_left = 4
		row.add_theme_stylebox_override("panel", sb)
		diplomacy_list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)
		var rel := GameState.relations_score(pc.id, cid)
		var status := Locale.t("DIPLO_NEUTRAL")
		if pc.at_war_with.has(cid): status = Locale.t("DIPLO_AT_WAR")
		elif pc.allies.has(cid): status = Locale.t("DIPLO_ALLIED")
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.scroll_active = false
		lbl.custom_minimum_size = Vector2(360, 50)
		var rel_color := "#2ecc71" if rel > 30 else ("#e74c3c" if rel < -30 else "#cccccc")
		lbl.text = "[b]%s[/b]  [color=#aaaaaa](%s)[/color]\n[color=%s]%s: %+d[/color]   [color=#cccccc]%s: %s[/color]" % [oc.name, oc.era.capitalize(), rel_color, Locale.t("DIPLO_RELATIONS"), rel, Locale.t("DIPLO_STATUS"), status]
		hb.add_child(lbl)
		# Action buttons
		var b_imp := Button.new()
		b_imp.text = "%s (-30g)" % Locale.t("DIPLO_IMPROVE")
		b_imp.pressed.connect(func(): AI.improve_relations(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
		hb.add_child(b_imp)
		var b_gift := Button.new()
		b_gift.text = Locale.t("DIPLO_GIFT")
		b_gift.pressed.connect(_on_gift.bind(cid))
		hb.add_child(b_gift)
		if pc.at_war_with.has(cid):
			var b_peace := Button.new()
			b_peace.text = Locale.t("DIPLO_MAKE_PEACE")
			b_peace.pressed.connect(func(): AI.make_peace(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_peace)
		else:
			var b_war := Button.new()
			b_war.text = Locale.t("DIPLO_DECLARE_WAR")
			b_war.pressed.connect(func(): AI.declare_war(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_war)
		if pc.allies.has(cid):
			var b_break := Button.new()
			b_break.text = Locale.t("DIPLO_BREAK_ALLIANCE")
			b_break.pressed.connect(func(): AI.break_alliance(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_break)
		elif not pc.at_war_with.has(cid):
			var b_ally := Button.new()
			b_ally.text = Locale.t("DIPLO_FORM_ALLIANCE")
			b_ally.pressed.connect(func(): AI.form_alliance(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_ally)
		var b_spy := Button.new()
		b_spy.text = Locale.t("DIPLO_SPY")
		b_spy.pressed.connect(func(): AI.send_spy(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
		hb.add_child(b_spy)
		var b_kill := Button.new()
		b_kill.text = Locale.t("DIPLO_ASSASSIN")
		b_kill.pressed.connect(func(): AI.attempt_assassination(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
		hb.add_child(b_kill)

func _refresh_characters() -> void:
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null: return
	var t := "[b][color=#f1c40f]%s — Court[/color][/b]\n\n" % pc.name
	var ruler: Character = GameState.characters.get(pc.ruler_id)
	if ruler != null:
		t += "[b]RULER[/b]: %s, age %d  [color=#aaaaaa](%s)[/color]\n" % [ruler.name, ruler.age, ruler.role_name()]
		t += "  Mar %d  Dip %d  Stew %d  Intr %d  Learn %d  ([color=#f4d35e]Power %d[/color])\n" % [ruler.martial, ruler.diplomacy, ruler.stewardship, ruler.intrigue, ruler.learning, ruler.power_level()]
		t += "  Traits: %s\n\n" % _trait_string(ruler)
	t += "[b]ADVISORS[/b]\n"
	for aid in pc.advisor_ids:
		var a: Character = GameState.characters.get(aid)
		if a == null or not a.alive: continue
		t += "  • %s, age %d. M%d D%d S%d I%d L%d. Traits: %s\n" % [a.name, a.age, a.martial, a.diplomacy, a.stewardship, a.intrigue, a.learning, _trait_string(a)]
	t += "\n[b]GENERALS[/b]\n"
	for gid in pc.general_ids:
		var g: Character = GameState.characters.get(gid)
		if g == null or not g.alive: continue
		t += "  • %s, age %d. Martial [color=#f1c40f]%d[/color]. Traits: %s\n" % [g.name, g.age, g.martial, _trait_string(g)]
	character_text.text = t

func _trait_string(c: Character) -> String:
	if c.traits.is_empty(): return "none"
	var parts := []
	for tid in c.traits:
		var td: Dictionary = GameState.traits_db.get(tid, {})
		parts.append(String(td.get("name", tid)))
	return ", ".join(parts)

func _refresh_tech() -> void:
	for child in tech_list.get_children():
		tech_list.remove_child(child)
		child.queue_free()
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null: return
	var era_order := ["antiquity", "medieval", "renaissance", "industrial", "modern"]
	for ek in era_order:
		var era_lbl := Label.new()
		var era_def: Dictionary = GameState.eras_db.get(ek, {})
		era_lbl.text = "—— " + String(era_def.get("name", ek.capitalize())) + " ——"
		era_lbl.add_theme_font_size_override("font_size", 18)
		era_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
		tech_list.add_child(era_lbl)
		for tid in GameState.tech_tree.keys():
			var t: Dictionary = GameState.tech_tree[tid]
			if String(t.get("era", "")) != ek: continue
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 8)
			tech_list.add_child(hb)
			var status := "—"
			var color := Color(0.8, 0.8, 0.8)
			if pc.researched_techs.has(tid):
				status = "DONE"
				color = Color(0.5, 0.95, 0.5)
			elif pc.current_research == tid:
				status = "RESEARCHING"
				color = Color(0.95, 0.95, 0.5)
			else:
				var prereqs: Array = t.get("prereq", [])
				var ok := true
				for pr in prereqs:
					if not pc.researched_techs.has(pr):
						ok = false; break
				if not ok:
					status = "LOCKED"
					color = Color(0.7, 0.5, 0.5)
				else:
					status = "AVAILABLE"
					color = Color(0.7, 0.85, 1.0)
			var lbl := RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.fit_content = true
			lbl.scroll_active = false
			lbl.custom_minimum_size = Vector2(560, 26)
			var eff: Dictionary = t.get("effects", {})
			var eff_str := []
			for k in eff.keys():
				eff_str.append("%s: %s" % [k, str(eff[k])])
			lbl.text = "[color=#%02x%02x%02x][b]%s[/b][/color] (cost %d) — %s" % [int(color.r*255), int(color.g*255), int(color.b*255), String(t.get("name", tid)), int(t.get("cost", 0)), ", ".join(eff_str)]
			# Hover tooltip with prereqs, unlocks, and effects.
			var prereq_arr: Array = t.get("prereq", [])
			var unlock_arr: Array = t.get("unlocks", [])
			var tip_lines: Array = [String(t.get("name", tid))]
			tip_lines.append("Era: " + String(t.get("era", "")).capitalize())
			tip_lines.append("Cost: " + str(int(t.get("cost", 0))) + " research")
			if prereq_arr.size() > 0:
				tip_lines.append("Requires: " + ", ".join(prereq_arr))
			if unlock_arr.size() > 0:
				tip_lines.append("Unlocks: " + ", ".join(unlock_arr))
			if eff_str.size() > 0:
				tip_lines.append("Effects: " + ", ".join(eff_str))
			lbl.tooltip_text = "\n".join(tip_lines)
			hb.add_child(lbl)
			var status_lbl := Label.new()
			status_lbl.text = status
			status_lbl.add_theme_color_override("font_color", color)
			status_lbl.custom_minimum_size = Vector2(120, 26)
			hb.add_child(status_lbl)
			if status == "AVAILABLE":
				var rb := Button.new()
				rb.text = "Research"
				rb.pressed.connect(func(): pc.current_research = tid; _refresh_tech())
				hb.add_child(rb)

# ---------- ACTIONS ----------

## Pick the best (latest-era) unlocked unit type for this country, optionally
## restricted to naval-only or land-only units.
func _best_unit_for(pc: Country, naval: bool) -> String:
	var best: String = ""
	for uid in GameState.unit_types.keys():
		var ut: Dictionary = GameState.unit_types[uid]
		if bool(ut.get("naval", false)) != naval:
			continue
		var req := String(ut.get("tech", ""))
		if req == "" or pc.researched_techs.has(req):
			best = uid
	if best == "":
		# Fallback: era-appropriate default
		best = "galley" if naval else "levy"
	return best

func _on_recruit_pressed() -> void:
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null: return
	var pid := GameState.selected_province_id
	if pid < 0: return
	if not pc.province_ids.has(pid): return
	var best_type: String = _best_unit_for(pc, false)
	var ut: Dictionary = GameState.unit_types[best_type]
	var cg: float = float(ut.get("cost_gold", 30))
	var cm: float = float(ut.get("cost_manpower", 1000))
	if pc.gold < cg or pc.manpower_pool < cm:
		GameState.log_event("Not enough gold/manpower to recruit %s." % String(ut.get("name", best_type)), Color(1.0, 0.5, 0.5))
		return
	pc.gold -= cg
	pc.manpower_pool -= cm
	var u := ArmyUnit.new()
	u.owner_id = pc.id
	u.type_id = best_type
	u.name = "%s %s" % [pc.name, String(ut.get("name", best_type))]
	u.province_id = pid
	u.strength = 5000
	u.max_strength = 5000
	GameState.add_unit(u)
	GameState.log_event("Recruited %s in %s." % [String(ut.get("name", best_type)), GameState.provinces[pid].name], Color(0.8, 1.0, 0.8))
	_refresh_top_bar()
	_refresh_province_panel()

## Build a fleet at the selected coastal province. The new naval unit spawns
## on the adjacent sea hex (since naval units only travel on sea).
func _on_recruit_navy_pressed() -> void:
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null: return
	var pid := GameState.selected_province_id
	if pid < 0: return
	if not pc.province_ids.has(pid): return
	var port: Province = GameState.provinces[pid]
	if not port.is_coast:
		GameState.log_event("Cannot build fleet: not a coastal province.", Color(1.0, 0.7, 0.5))
		return
	var sea_id: int = -1
	for nb in port.neighbors:
		var np: Province = GameState.provinces[int(nb)]
		if np != null and np.is_sea:
			sea_id = int(nb)
			break
	if sea_id == -1:
		GameState.log_event("Cannot build fleet: no adjacent sea tile.", Color(1.0, 0.7, 0.5))
		return
	var best_type: String = _best_unit_for(pc, true)
	var ut: Dictionary = GameState.unit_types[best_type]
	var cg: float = float(ut.get("cost_gold", 80))
	var cm: float = float(ut.get("cost_manpower", 500))
	if pc.gold < cg or pc.manpower_pool < cm:
		GameState.log_event("Not enough gold/manpower to build %s." % String(ut.get("name", best_type)), Color(1.0, 0.5, 0.5))
		return
	pc.gold -= cg
	pc.manpower_pool -= cm
	var u := ArmyUnit.new()
	u.owner_id = pc.id
	u.type_id = best_type
	u.name = "%s %s" % [pc.name, String(ut.get("name", best_type))]
	u.province_id = sea_id
	u.strength = 4000
	u.max_strength = 4000
	GameState.add_unit(u)
	GameState.log_event("Launched %s from %s." % [String(ut.get("name", best_type)), port.name], Color(0.6, 0.85, 1.0))
	_refresh_top_bar()
	_refresh_province_panel()

func _on_move_to_pressed() -> void:
	if move_mode_unit == -1: return
	var pid := GameState.selected_province_id
	if pid < 0: return
	var u: ArmyUnit = GameState.units.get(move_mode_unit)
	if u == null: return
	if pid == u.province_id:
		return
	var ut: Dictionary = GameState.unit_types.get(u.type_id, {})
	var is_naval: bool = bool(ut.get("naval", false))
	var dest_p: Province = GameState.provinces[pid]
	if dest_p == null:
		return
	# Validate destination matches unit class.
	if is_naval and not dest_p.is_sea:
		GameState.log_event("Fleets can only sail to sea tiles.", Color(1.0, 0.7, 0.5))
		return
	if not is_naval and dest_p.is_sea:
		GameState.log_event("Land armies cannot enter open sea.", Color(1.0, 0.7, 0.5))
		return
	var passable := func(np: Province) -> bool:
		if is_naval:
			return np.is_sea
		return not np.is_sea
	var path: Array[int] = GameState.find_path(u.province_id, pid, passable)
	if path.size() < 2:
		GameState.log_event("No path to %s." % dest_p.name, Color(1.0, 0.7, 0.5))
		return
	# First entry is current province; subsequent entries are the route hexes.
	u.path = path.slice(1)
	u.dest_province_id = int(u.path[0])
	u.path.remove_at(0)
	u.orders = "move"
	u.move_progress = 0.0
	var hops: int = path.size() - 1
	GameState.log_event("%s ordered to %s (%d hexes)." % [u.name, dest_p.name, hops], Color(0.7, 0.95, 1.0))
	move_mode_unit = -1
	province_panel_move_to.visible = false
	province_panel_assign_general.visible = false

## Cycle through the player's generals and attach the next available one to
## the selected unit. A general boosts combat power and triggers their traits
## (e.g. Brilliant Strategist) in battle.
func _on_assign_general_pressed() -> void:
	if move_mode_unit == -1: return
	var u: ArmyUnit = GameState.units.get(move_mode_unit)
	if u == null: return
	var pc: Country = GameState.countries.get(u.owner_id)
	if pc == null or pc.general_ids.is_empty(): return
	# Choose a general not currently assigned to another unit, falling back
	# to cycling if all are taken.
	var taken: Dictionary = {}
	for ouid in GameState.units.keys():
		var ou: ArmyUnit = GameState.units[ouid]
		if ou.owner_id == pc.id and ou.general_id != -1 and ou.id != u.id:
			taken[ou.general_id] = true
	var picked: int = -1
	for gid in pc.general_ids:
		if not taken.has(gid):
			picked = int(gid)
			break
	if picked == -1:
		# All taken; rotate to next
		var idx: int = pc.general_ids.find(u.general_id)
		idx = (idx + 1) % pc.general_ids.size()
		picked = int(pc.general_ids[idx])
	u.general_id = picked
	var gen: Character = GameState.characters.get(picked)
	if gen != null:
		GameState.log_event("%s assigned to %s (Mar %d)." % [gen.name, u.name, gen.martial], Color(1.0, 0.9, 0.6))
	_refresh_province_panel()

# Called by map_view when user clicks a province
func on_province_clicked(pid: int) -> void:
	GameState.selected_province_id = pid
	GameState.selection_changed.emit(pid)

# Called by map_view when user right-clicks (for unit move)
func on_province_right_clicked(pid: int) -> void:
	# Right-click while a unit is selected = move
	if move_mode_unit != -1:
		GameState.selected_province_id = pid
		_on_move_to_pressed()

# Called by map_view when user clicks a unit
func _on_load_pressed() -> void:
	if SaveLoad.load_save("main"):
		get_tree().reload_current_scene()
	save_panel.visible = false

func _on_gift(target_cid: String) -> void:
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null: return
	if AI.send_gift(pc.id, target_cid, 100.0):
		_refresh_diplomacy()
		_refresh_top_bar()

func _close_province_panel() -> void:
	province_panel.visible = false
	GameState.selected_province_id = -1

func on_unit_clicked(uid: int) -> void:
	var u: ArmyUnit = GameState.units.get(uid)
	if u == null: return
	if u.owner_id != GameState.player_country_id: return
	move_mode_unit = uid
	GameState.log_event("Selected %s. Click target province → 'Move selected army here', or right-click adjacent province." % u.name, Color(0.7, 0.95, 1.0))
	GameState.selected_province_id = u.province_id
	GameState.selection_changed.emit(u.province_id)

# ---------- MINIMAP & HELP ----------

const MINIMAP_W: int = 260
const MINIMAP_H: int = 130

func _build_minimap() -> void:
	minimap_panel = PanelContainer.new()
	minimap_panel.position = Vector2(20, 86)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.10, 0.88)
	sb.border_color = Color(0.45, 0.55, 0.75, 0.7)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	minimap_panel.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(minimap_panel)
	minimap_view = Control.new()
	minimap_view.custom_minimum_size = Vector2(MINIMAP_W, MINIMAP_H)
	minimap_view.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap_view.draw.connect(_draw_minimap)
	minimap_view.gui_input.connect(_on_minimap_input)
	minimap_panel.add_child(minimap_view)
	# Refresh minimap on world events.
	GameState.world_ready.connect(func(): minimap_view.queue_redraw())
	GameState.country_state_changed.connect(func(_cid): minimap_view.queue_redraw())
	GameState.selection_changed.connect(func(_pid): minimap_view.queue_redraw())
	# Periodic redraw to keep viewport rect + units fresh.
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(func(): if minimap_view: minimap_view.queue_redraw())
	add_child(t)

func _draw_minimap() -> void:
	if minimap_view == null:
		return
	var sx: float = float(MINIMAP_W) / GameState.MAP_W
	var sy: float = float(MINIMAP_H) / GameState.MAP_H
	# Sea background
	minimap_view.draw_rect(Rect2(0, 0, MINIMAP_W, MINIMAP_H), Color(0.08, 0.16, 0.26), true)
	# Provinces (one pixel per province, owner-colored)
	for p in GameState.provinces:
		if p.is_sea:
			continue
		var col: Color = Color(0.40, 0.45, 0.32)
		if p.owner_id != "":
			var c: Country = GameState.countries.get(p.owner_id)
			if c != null:
				col = c.color
		var rx: float = p.center.x * sx
		var ry: float = p.center.y * sy
		minimap_view.draw_rect(Rect2(rx - 1.2, ry - 1.0, 2.4, 2.0), col, true)
	# Capitals
	for p in GameState.provinces:
		if p.is_capital:
			minimap_view.draw_circle(Vector2(p.center.x * sx, p.center.y * sy), 1.6, Color(1, 0.95, 0.4))
	# Player viewport rectangle.
	if camera != null:
		var vp_size: Vector2 = get_viewport_rect().size / camera.zoom
		var vp_pos: Vector2 = camera.global_position - vp_size * 0.5
		var rect := Rect2(vp_pos.x * sx, vp_pos.y * sy, vp_size.x * sx, vp_size.y * sy)
		minimap_view.draw_rect(rect, Color(1, 1, 1, 0.8), false, 1.5)

func _on_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_minimap_jump(event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_minimap_jump(event.position)

func _minimap_jump(pos: Vector2) -> void:
	if camera == null:
		return
	var sx: float = float(MINIMAP_W) / GameState.MAP_W
	var sy: float = float(MINIMAP_H) / GameState.MAP_H
	camera.global_position = Vector2(pos.x / sx, pos.y / sy).clamp(Vector2.ZERO, Vector2(GameState.MAP_W, GameState.MAP_H))

func _build_help_panel() -> void:
	help_panel = _build_panel(Vector2(440, 180), Vector2(560, 540))
	help_panel.visible = false
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_top", 16)
	hm.add_theme_constant_override("margin_left", 18)
	hm.add_theme_constant_override("margin_right", 18)
	hm.add_theme_constant_override("margin_bottom", 16)
	help_panel.add_child(hm)
	var hvb := VBoxContainer.new()
	hvb.add_theme_constant_override("separation", 6)
	hm.add_child(hvb)
	help_panel_text = RichTextLabel.new()
	help_panel_text.bbcode_enabled = true
	help_panel_text.fit_content = true
	help_panel_text.custom_minimum_size = Vector2(520, 480)
	hvb.add_child(help_panel_text)
	help_panel_close = Button.new()
	help_panel_close.pressed.connect(func(): help_panel.visible = false)
	hvb.add_child(help_panel_close)
	# Note: help_panel is already parented to ui_layer by _build_panel().

func _help_panel_text() -> String:
	return "[b][color=#f1c40f]%s[/color][/b]\n\n" % Locale.t("HELP_TITLE") \
		+ "[b]%s[/b]\n" % Locale.t("HELP_CAMERA") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_PAN") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_ZOOM") \
		+ "  [color=#aae]%s[/color]\n\n" % Locale.t("HELP_MINIMAP") \
		+ "[b]%s[/b]\n" % Locale.t("HELP_TIME") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_PAUSE") \
		+ "  [color=#aae]%s[/color]\n\n" % Locale.t("HELP_SPEED") \
		+ "[b]%s[/b]\n" % Locale.t("HELP_PANELS") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_F1") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_F2") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_F3") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_H") \
		+ "  [color=#aae]%s[/color]\n\n" % Locale.t("HELP_ESC") \
		+ "[b]%s[/b]\n" % Locale.t("HELP_UNITS") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_SELECT") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_RIGHT_CLICK") \
		+ "  %s\n" % Locale.t("HELP_PROVINCE_PANEL") \
		+ "  %s\n\n" % Locale.t("HELP_TOKENS") \
		+ "[b]%s[/b]\n" % Locale.t("HELP_SAVELOAD") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_SAVE") \
		+ "  [color=#aae]%s[/color]\n" % Locale.t("HELP_LOAD")

func _hotkey_hint_text() -> String:
	return "F1=%s  F2=%s  F3=%s  H=?  F5=Save  F9=Load" % [Locale.t("DIPLO_TITLE"), Locale.t("COURT_TITLE"), Locale.t("TECH_TITLE")]

func _apply_locale() -> void:
	if hotkey_hint != null:
		hotkey_hint.text = _hotkey_hint_text()
	if help_panel_text != null:
		help_panel_text.text = _help_panel_text()
	if help_panel_close != null:
		help_panel_close.text = Locale.t("HELP_CLOSE")
	if province_panel_recruit != null:
		province_panel_recruit.text = Locale.t("PANEL_RECRUIT_LAND")
		province_panel_recruit_navy.text = Locale.t("PANEL_RECRUIT_NAVY")
		province_panel_move_to.text = Locale.t("PANEL_MOVE_HERE")
		province_panel_assign_general.text = Locale.t("PANEL_ASSIGN_GENERAL")
		province_panel_convert_religion.text = Locale.t("PANEL_CONVERT_RELIGION")
		province_panel_convert_culture.text = Locale.t("PANEL_CULTIVATE_CULTURE")
		province_panel_close.text = Locale.t("PANEL_CLOSE")
	if diplomacy_title != null:
		diplomacy_title.text = Locale.t("DIPLO_TITLE").to_upper()
		diplomacy_close.text = "%s (F1)" % Locale.t("PANEL_CLOSE")
	if character_title != null:
		character_title.text = Locale.t("COURT_TITLE").to_upper()
		character_close.text = "%s (F2)" % Locale.t("PANEL_CLOSE")
	if tech_title != null:
		tech_title.text = Locale.t("TECH_TITLE").to_upper()
		tech_close.text = "%s (F3)" % Locale.t("PANEL_CLOSE")
	if save_title != null:
		save_title.text = Locale.t("ACT_SAVELOAD")
		save_btn.text = "%s [F5]" % Locale.t("ACT_SAVE")
		load_btn.text = "%s [F9]" % Locale.t("ACT_LOAD")
		save_close.text = Locale.t("PANEL_CLOSE")
	# Re-render dynamic panels that may already be open.
	_refresh_top_bar()
	if province_panel != null and province_panel.visible:
		_refresh_province_panel()
	if diplomacy_panel != null and diplomacy_panel.visible:
		_refresh_diplomacy()
	if character_panel != null and character_panel.visible:
		_refresh_characters()
	if tech_panel != null and tech_panel.visible:
		_refresh_tech()

func _toggle_help_panel() -> void:
	if help_panel == null:
		return
	help_panel.visible = not help_panel.visible

# ---------- HELPERS: i18n labels ----------

const _TERRAIN_KEYS := [
	"TERR_PLAINS", "TERR_FOREST", "TERR_HILLS", "TERR_MOUNTAINS", "TERR_DESERT",
	"TERR_STEPPE", "TERR_JUNGLE", "TERR_TUNDRA", "TERR_COAST", "TERR_SEA",
]

func _terrain_name(p: Province) -> String:
	var idx: int = clamp(p.terrain, 0, _TERRAIN_KEYS.size() - 1)
	return Locale.t(_TERRAIN_KEYS[idx])

func _resource_label(rid: String) -> String:
	var key := "RESOURCE_" + rid.to_upper()
	return Locale.t(key)

func _building_name(bid: String) -> String:
	var bdef: Dictionary = GameState.buildings_db.get(bid, {})
	var k := String(bdef.get("name_key", ""))
	if k == "": return bid.capitalize()
	return Locale.t(k)

func _building_desc(bid: String) -> String:
	var bdef: Dictionary = GameState.buildings_db.get(bid, {})
	var k := String(bdef.get("desc_key", ""))
	if k == "": return ""
	return Locale.t(k)

# ---------- HELPERS: religion / culture stats ----------

## Returns 0..1 share of land provinces matching the state religion.
func _religious_unity(c: Country) -> float:
	if c == null or c.province_ids.is_empty(): return 1.0
	var match_count: int = 0
	var land_count: int = 0
	for pid in c.province_ids:
		var p: Province = GameState.provinces[int(pid)]
		if p == null or p.is_sea: continue
		land_count += 1
		if p.religion == c.state_religion:
			match_count += 1
	return 1.0 if land_count == 0 else float(match_count) / float(land_count)

func _cultural_unity(c: Country) -> float:
	if c == null or c.province_ids.is_empty(): return 1.0
	var match_count: int = 0
	var land_count: int = 0
	for pid in c.province_ids:
		var p: Province = GameState.provinces[int(pid)]
		if p == null or p.is_sea: continue
		land_count += 1
		if p.culture == c.primary_culture:
			match_count += 1
	return 1.0 if land_count == 0 else float(match_count) / float(land_count)

# ---------- BUILDING / CONVERSION ACTIONS ----------

const CONVERT_GOLD_COST := 75
const CULTURE_GOLD_COST := 50
const CONVERT_DURATION_MONTHS := 12.0
const CULTURE_DURATION_MONTHS := 36.0

## Rebuilds the row of "Build X" buttons under the province panel based on
## which buildings the player can construct in this province.
func _rebuild_building_buttons(p: Province, owns_province: bool) -> void:
	if province_panel_build_btns == null:
		return
	for child in province_panel_build_btns.get_children():
		child.queue_free()
	province_panel_build_btns.visible = owns_province and not p.is_sea and p.build_id == ""
	if not province_panel_build_btns.visible:
		return
	for bid in GameState.buildings_db.keys():
		var bdef: Dictionary = GameState.buildings_db[bid]
		if p.buildings.has(bid):
			continue
		if bool(bdef.get("needs_coast", false)) and not p.is_coast:
			continue
		var b := Button.new()
		b.text = "%s: %s (%dg)" % [Locale.t("PANEL_BUILD_BUILDING"), _building_name(bid), int(bdef.get("cost_gold", 0))]
		b.tooltip_text = _building_desc(bid)
		var cap_bid := String(bid)
		var cap_p := p
		b.pressed.connect(func(): _on_build_pressed(cap_p, cap_bid))
		province_panel_build_btns.add_child(b)

func _on_build_pressed(p: Province, bid: String) -> void:
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null: return
	if not pc.province_ids.has(p.id): return
	if p.build_id != "": return
	if p.buildings.has(bid): return
	var bdef: Dictionary = GameState.buildings_db.get(bid, {})
	var cost: float = float(bdef.get("cost_gold", 0))
	if pc.gold < cost:
		GameState.log_event(Locale.t("EVT_BUILDING_CANT_AFFORD") % _building_name(bid), Color(1.0, 0.7, 0.5))
		return
	pc.gold -= cost
	p.build_id = bid
	p.build_progress_months = 0.0
	GameState.log_event(Locale.t("EVT_BUILDING_START") % [_building_name(bid), p.name], Color(0.7, 0.9, 1.0))
	_refresh_top_bar()
	_refresh_province_panel()

func _on_convert_religion_pressed() -> void:
	var pid := GameState.selected_province_id
	if pid < 0: return
	var p: Province = GameState.provinces[pid]
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if p == null or pc == null: return
	if not pc.province_ids.has(pid): return
	if p.religion == pc.state_religion: return
	if p.convert_religion_to != "":
		GameState.log_event(Locale.t("EVT_CONVERT_BUSY"), Color(1.0, 0.7, 0.5))
		return
	if pc.gold < CONVERT_GOLD_COST:
		GameState.log_event(Locale.t("EVT_NOT_ENOUGH_GOLD"), Color(1.0, 0.6, 0.5))
		return
	pc.gold -= CONVERT_GOLD_COST
	p.convert_religion_to = pc.state_religion
	p.convert_religion_months = CONVERT_DURATION_MONTHS
	GameState.log_event(Locale.t("EVT_CONVERT_START") % [p.name, int(CONVERT_DURATION_MONTHS)], Color(0.85, 0.7, 1.0))
	_refresh_top_bar()
	_refresh_province_panel()

func _on_convert_culture_pressed() -> void:
	var pid := GameState.selected_province_id
	if pid < 0: return
	var p: Province = GameState.provinces[pid]
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if p == null or pc == null: return
	if not pc.province_ids.has(pid): return
	if p.culture == pc.primary_culture: return
	if p.convert_culture_to != "":
		GameState.log_event(Locale.t("EVT_CULTURE_BUSY"), Color(1.0, 0.7, 0.5))
		return
	if pc.gold < CULTURE_GOLD_COST:
		GameState.log_event(Locale.t("EVT_NOT_ENOUGH_GOLD"), Color(1.0, 0.6, 0.5))
		return
	pc.gold -= CULTURE_GOLD_COST
	p.convert_culture_to = pc.primary_culture
	p.convert_culture_months = CULTURE_DURATION_MONTHS
	GameState.log_event(Locale.t("EVT_CULTURE_START") % [p.name, int(CULTURE_DURATION_MONTHS)], Color(0.7, 0.9, 0.95))
	_refresh_top_bar()
	_refresh_province_panel()
