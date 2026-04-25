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
var province_panel_move_to: Button

var diplomacy_panel: PanelContainer
var diplomacy_list: VBoxContainer
var character_panel: PanelContainer
var character_text: RichTextLabel
var tech_panel: PanelContainer
var tech_list: VBoxContainer
var save_panel: PanelContainer
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
	hk.text = "D=Diplo  T=Tech  C=Chars  F5=Save  F9=Load"
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
	province_panel_recruit.text = "Recruit Army (cost varies)"
	province_panel_recruit.pressed.connect(_on_recruit_pressed)
	pvb.add_child(province_panel_recruit)
	province_panel_move_to = Button.new()
	province_panel_move_to.text = "Move selected army here"
	province_panel_move_to.pressed.connect(_on_move_to_pressed)
	pvb.add_child(province_panel_move_to)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_province_panel)
	pvb.add_child(close_btn)

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
	var dh := Label.new()
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
	var d_close := Button.new()
	d_close.text = "Close (D)"
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
	var ch := Label.new()
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
	var c_close := Button.new()
	c_close.text = "Close (C)"
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
	var th := Label.new()
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
	var t_close := Button.new()
	t_close.text = "Close (T)"
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
	var slbl := Label.new()
	slbl.text = "Save / Load"
	slbl.add_theme_font_size_override("font_size", 22)
	slbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	spv.add_child(slbl)
	var save_btn := Button.new()
	save_btn.text = "Save (slot 'main')  [F5]"
	save_btn.pressed.connect(func(): SaveLoad.save("main"); save_panel.visible = false)
	spv.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "Load (slot 'main')  [F9]"
	load_btn.pressed.connect(_on_load_pressed)
	spv.add_child(load_btn)
	var sp_close := Button.new()
	sp_close.text = "Close"
	sp_close.pressed.connect(func(): save_panel.visible = false)
	spv.add_child(sp_close)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				GameState.paused = not GameState.paused
				_refresh_top_bar()
			KEY_EQUAL, KEY_PLUS:
				GameState.speed = min(5, GameState.speed + 1)
				_refresh_top_bar()
			KEY_MINUS:
				GameState.speed = max(1, GameState.speed - 1)
				_refresh_top_bar()
			KEY_D:
				diplomacy_panel.visible = not diplomacy_panel.visible
				if diplomacy_panel.visible:
					_refresh_diplomacy()
			KEY_C:
				character_panel.visible = not character_panel.visible
				if character_panel.visible:
					_refresh_characters()
			KEY_T:
				tech_panel.visible = not tech_panel.visible
				if tech_panel.visible:
					_refresh_tech()
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
				province_panel.visible = false

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
	top_bar_label.text += "[color=#f1c40f]Gold[/color]: %d (%+.1f/m)   " % [int(c.gold), income_estimate]
	top_bar_label.text += "[color=#e74c3c]Manpower[/color]: %d   " % int(c.manpower_pool)
	top_bar_label.text += "[color=#3498db]Research[/color]: %d   " % int(c.research_points)
	top_bar_label.text += "[color=#9b59b6]Culture[/color]: %d   " % int(c.culture_points)
	top_bar_label.text += "[color=#2ecc71]Stability[/color]: %.1f   " % c.stability
	top_bar_label.text += "[color=#f39c12]Prestige[/color]: %d   " % int(c.prestige)
	top_bar_label.text += "Provinces: %d   Armies: %d" % [c.province_ids.size(), c.unit_ids.size()]
	date_label.text = GameState.date_string()
	if GameState.paused:
		pause_label.text = "[ PAUSED ]"
		pause_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	else:
		pause_label.text = ">> Speed %d" % GameState.speed
		pause_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))

func _refresh_province_panel() -> void:
	var pid := GameState.selected_province_id
	if pid < 0:
		province_panel.visible = false
		return
	var p: Province = GameState.get_province(pid)
	if p == null: return
	var owner_name := "Unclaimed"
	var owner_color := "#888888"
	if p.owner_id != "":
		var oc: Country = GameState.countries.get(p.owner_id)
		if oc != null:
			owner_name = oc.name
			owner_color = "#%02x%02x%02x" % [int(oc.color.r * 255), int(oc.color.g * 255), int(oc.color.b * 255)]
	var t := "[b][color=#f1c40f]%s[/color][/b]" % p.name
	if p.is_capital:
		t += "  [color=#f4d35e]★ Capital[/color]"
	t += "\n"
	t += "[color=%s]%s[/color]\n" % [owner_color, owner_name]
	t += "Terrain: %s\n" % p.terrain_name()
	t += "Development: [b]%d[/b]\n" % p.development
	t += "Population: %d\n" % p.population
	t += "Culture: %s\n" % p.culture
	t += "Religion: %s\n" % p.religion
	t += "Garrison: %d   Unrest: %.1f\n" % [p.garrison, p.unrest]
	# Units in province
	var present_units := []
	for uid in GameState.units.keys():
		var u: ArmyUnit = GameState.units[uid]
		if u.province_id == pid:
			present_units.append(u)
	if present_units.size() > 0:
		t += "\n[b]Armies present:[/b]\n"
		for u in present_units:
			var oc: Country = GameState.countries.get(u.owner_id)
			var ut: Dictionary = GameState.unit_types.get(u.type_id, {})
			var o_color: String = "#%02x%02x%02x" % [int(oc.color.r * 255), int(oc.color.g * 255), int(oc.color.b * 255)] if oc != null else "#888888"
			t += "  • [color=%s]%s[/color] %s (str %d, mor %.1f)\n" % [o_color, oc.name if oc != null else u.owner_id, ut.get("name", u.type_id), u.strength, u.morale]
	province_panel_text.text = t

	# Buttons enabled depending on selection
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	province_panel_recruit.visible = pc != null and pc.province_ids.has(pid)
	province_panel_move_to.visible = move_mode_unit != -1

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
		var status := "NEUTRAL"
		if pc.at_war_with.has(cid): status = "WAR"
		elif pc.allies.has(cid): status = "ALLY"
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.scroll_active = false
		lbl.custom_minimum_size = Vector2(360, 50)
		var rel_color := "#2ecc71" if rel > 30 else ("#e74c3c" if rel < -30 else "#cccccc")
		lbl.text = "[b]%s[/b]  [color=#aaaaaa](%s)[/color]\n[color=%s]Relations: %+d[/color]   [color=#cccccc]Status: %s[/color]" % [oc.name, oc.era.capitalize(), rel_color, rel, status]
		hb.add_child(lbl)
		# Action buttons
		var b_imp := Button.new()
		b_imp.text = "Improve (-30g)"
		b_imp.pressed.connect(func(): AI.improve_relations(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
		hb.add_child(b_imp)
		var b_gift := Button.new()
		b_gift.text = "Gift (-100g)"
		b_gift.pressed.connect(_on_gift.bind(cid))
		hb.add_child(b_gift)
		if pc.at_war_with.has(cid):
			var b_peace := Button.new()
			b_peace.text = "Make Peace"
			b_peace.pressed.connect(func(): AI.make_peace(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_peace)
		else:
			var b_war := Button.new()
			b_war.text = "Declare War"
			b_war.pressed.connect(func(): AI.declare_war(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_war)
		if pc.allies.has(cid):
			var b_break := Button.new()
			b_break.text = "Break Alliance"
			b_break.pressed.connect(func(): AI.break_alliance(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_break)
		elif not pc.at_war_with.has(cid):
			var b_ally := Button.new()
			b_ally.text = "Form Alliance"
			b_ally.pressed.connect(func(): AI.form_alliance(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
			hb.add_child(b_ally)
		var b_spy := Button.new()
		b_spy.text = "Spy (-60g)"
		b_spy.pressed.connect(func(): AI.send_spy(pc.id, cid); _refresh_diplomacy(); _refresh_top_bar())
		hb.add_child(b_spy)
		var b_kill := Button.new()
		b_kill.text = "Assassinate (-150g)"
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

func _on_recruit_pressed() -> void:
	var pc: Country = GameState.countries.get(GameState.player_country_id)
	if pc == null: return
	var pid := GameState.selected_province_id
	if pid < 0: return
	if not pc.province_ids.has(pid): return
	# Pick latest unlocked
	var best_type := "levy"
	for uid in GameState.unit_types.keys():
		var ut: Dictionary = GameState.unit_types[uid]
		var req := String(ut.get("tech", ""))
		if req == "" or pc.researched_techs.has(req):
			best_type = uid
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

func _on_move_to_pressed() -> void:
	if move_mode_unit == -1: return
	var pid := GameState.selected_province_id
	if pid < 0: return
	var u: ArmyUnit = GameState.units.get(move_mode_unit)
	if u == null: return
	# Allow only adjacent moves (one hex per order); player can stack moves later.
	var current: Province = GameState.provinces[u.province_id]
	if not current.neighbors.has(pid):
		GameState.log_event("Target not adjacent. Move one province at a time.", Color(1.0, 0.7, 0.5))
		return
	u.dest_province_id = pid
	u.orders = "move"
	u.move_progress = 0.0
	GameState.log_event("Army ordered to march to %s." % GameState.provinces[pid].name, Color(0.7, 0.95, 1.0))
	move_mode_unit = -1
	province_panel_move_to.visible = false

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
