## Renders the world map.
##
## Optimization: split into two canvas items.
##   * Base layer (this Node2D) — provinces, borders, capitals, selection.
##     Redrawn ONLY when ownership / selection changes.
##   * Units layer (child node) — armies and fleets. Redrawn each day_tick.
##
## Country stat changes (gold, manpower, research) DO NOT redraw the map any
## more — they used to fire ~13 full repaints per month on top of the per-day
## unit redraws, which was the dominant frame cost on faster speeds.
extends Node2D

const SEA_COLOR := Color(0.06, 0.13, 0.22)
const UNCLAIMED := Color(0.34, 0.40, 0.30)
const HIGHLIGHT := Color(1.0, 0.95, 0.4, 0.85)
const TERRAIN_TINT := {
	0: Color(1.0, 1.0, 1.0),         # PLAINS
	1: Color(0.85, 1.0, 0.85),       # FOREST
	2: Color(0.95, 0.90, 0.78),      # HILLS
	3: Color(0.85, 0.82, 0.78),      # MOUNTAINS
	4: Color(1.0, 0.95, 0.7),        # DESERT
	5: Color(0.95, 0.95, 0.78),      # STEPPE
	6: Color(0.7, 1.0, 0.78),        # JUNGLE
	7: Color(0.95, 0.95, 1.0),       # TUNDRA
	8: Color(0.78, 0.95, 1.0),       # COAST
	9: Color(0.20, 0.45, 0.78),      # SEA
}
const SEA_TINT_DEEP := Color(0.06, 0.18, 0.32)
const SEA_TINT_SHALLOW := Color(0.18, 0.42, 0.66)

var _units_node: UnitsLayer
# Cached coastal flag for sea hexes (computed once per world).
var _sea_coastal: PackedByteArray = PackedByteArray()
# Debounce flag — many province_owner_changed signals can fire in one frame
# (e.g. peace deal returns 8 provinces). Coalesce them into one redraw.
var _redraw_pending: bool = false

class UnitsLayer extends Node2D:
	func _draw() -> void:
		# Drawn in screen-space of the parent (MapView), so we must replicate
		# unit drawing here (the parent now skips it).
		for uid in GameState.units.keys():
			var u: ArmyUnit = GameState.units[uid]
			var origin: Province = GameState.provinces[u.province_id] if u.province_id >= 0 else null
			if origin == null: continue
			var pos: Vector2 = origin.center
			if u.orders == "move" and u.dest_province_id != -1:
				var dest: Province = GameState.provinces[u.dest_province_id]
				if dest != null:
					pos = origin.center.lerp(dest.center, clamp(u.move_progress, 0.0, 1.0))
			var c: Country = GameState.countries.get(u.owner_id)
			var col := c.color if c != null else Color.GRAY
			var ut: Dictionary = GameState.unit_types.get(u.type_id, {})
			var is_naval: bool = bool(ut.get("naval", false))
			if is_naval:
				var diamond := PackedVector2Array([
					pos + Vector2(0, -11), pos + Vector2(11, 0),
					pos + Vector2(0, 11), pos + Vector2(-11, 0),
				])
				draw_colored_polygon(diamond, Color(0, 0, 0, 0.5))
				var diamond_inner := PackedVector2Array([
					pos + Vector2(0, -10), pos + Vector2(10, 0),
					pos + Vector2(0, 10), pos + Vector2(-10, 0),
				])
				draw_colored_polygon(diamond_inner, col)
				draw_polyline(_closed_arr(diamond_inner), Color(1, 1, 1, 0.9), 1.5, true)
			else:
				draw_circle(pos + Vector2(2, 2), 11.0, Color(0, 0, 0, 0.5))
				draw_circle(pos, 10.0, col)
				draw_arc(pos, 11.0, 0, TAU, 24, Color(1, 1, 1, 0.85), 1.5)
			var f := ThemeDB.fallback_font
			var fs: int = 11
			var s_str := str(int(round(u.strength / 100.0)))
			draw_string(f, pos + Vector2(-8, 4), s_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1))
			if u.general_id != -1:
				draw_circle(pos + Vector2(8, -8), 3.5, Color(1.0, 0.85, 0.2, 0.95))

	static func _closed_arr(poly: PackedVector2Array) -> PackedVector2Array:
		var arr := PackedVector2Array(poly)
		if arr.size() > 0:
			arr.append(arr[0])
		return arr

func _ready() -> void:
	_units_node = UnitsLayer.new()
	add_child(_units_node)
	# Map redraws only on ownership/selection changes.
	GameState.province_owner_changed.connect(_on_owner_changed)
	GameState.world_ready.connect(_on_world_ready)
	GameState.selection_changed.connect(_on_selection_changed)
	# Units redraw every day so animated movement is smooth.
	TimeCtl.day_tick.connect(_redraw_units)
	# Sieges advance monthly — force base redraw so progress arcs update.
	TimeCtl.month_tick.connect(_request_redraw)
	queue_redraw()

func _on_world_ready() -> void:
	_rebuild_coastal_cache()
	_request_redraw()
	_redraw_units()

func _on_owner_changed(_pid: int) -> void:
	_request_redraw()

func _on_selection_changed(_pid: int) -> void:
	_request_redraw()

func _request_redraw() -> void:
	if _redraw_pending:
		return
	_redraw_pending = true
	call_deferred("_flush_redraw")

func _flush_redraw() -> void:
	_redraw_pending = false
	queue_redraw()

func _redraw_units() -> void:
	if _units_node != null:
		_units_node.queue_redraw()

func _rebuild_coastal_cache() -> void:
	_sea_coastal.resize(GameState.provinces.size())
	for i in range(GameState.provinces.size()):
		var p: Province = GameState.provinces[i]
		if p == null or not p.is_sea:
			_sea_coastal[i] = 0
			continue
		var coastal: int = 0
		for nb in p.neighbors:
			var np: Province = GameState.provinces[int(nb)]
			if np != null and not np.is_sea:
				coastal = 1
				break
		_sea_coastal[i] = coastal

func _draw() -> void:
	# Sea background
	draw_rect(Rect2(0, 0, GameState.MAP_W, GameState.MAP_H), SEA_COLOR, true)

	# Provinces
	for p in GameState.provinces:
		if p.is_sea:
			var sea_col: Color = SEA_TINT_SHALLOW if (p.id < _sea_coastal.size() and _sea_coastal[p.id] == 1) else SEA_TINT_DEEP
			draw_colored_polygon(p.polygon, sea_col)
			draw_polyline(_closed(p.polygon), Color(0.08, 0.20, 0.36, 0.4), 1.0, true)
			continue
		var base_color := UNCLAIMED
		if p.owner_id != "":
			var c: Country = GameState.countries.get(p.owner_id)
			if c != null:
				base_color = c.color
		var tint: Color = TERRAIN_TINT.get(p.terrain, Color(1, 1, 1))
		var col := Color(base_color.r * tint.r, base_color.g * tint.g, base_color.b * tint.b, 1.0)
		var dev_factor: float = 0.65 + 0.05 * float(p.development)
		col = col * dev_factor
		col.a = 1.0
		draw_colored_polygon(p.polygon, col)
		draw_polyline(_closed(p.polygon), Color(0, 0, 0, 0.4), 1.0, true)

	# Country borders thicker (between different owners)
	for p in GameState.provinces:
		if p.is_sea: continue
		for nb in p.neighbors:
			if nb <= p.id: continue
			var np: Province = GameState.provinces[nb]
			if np == null or np.is_sea: continue
			if np.owner_id != p.owner_id:
				draw_line(p.center, np.center, Color(0, 0, 0, 0.55), 1.5, true)

	# Rivers — draw after land fills but before capital markers so they sit on top of land.
	var rivers: Array = WorldGen.rivers_world()
	for poly in rivers:
		if poly.size() >= 2:
			draw_polyline(poly, Color(0.55, 0.80, 0.95, 0.85), 2.5, true)

	# Capital markers + siege/fort indicators
	for p in GameState.provinces:
		if p.is_capital:
			draw_circle(p.center, 5.0, Color(1, 1, 0.5, 0.9))
			draw_arc(p.center, 7.0, 0, TAU, 24, Color(0.4, 0.3, 0.1, 0.8), 1.5)
		# Fort marker — small chevron
		if not p.is_sea and p.fort_level > 0:
			var s: float = 3.0 + 1.2 * float(p.fort_level)
			var pts := PackedVector2Array([
				p.center + Vector2(-s, s * 0.5),
				p.center + Vector2(0, -s),
				p.center + Vector2(s, s * 0.5),
			])
			draw_polyline(pts, Color(0.95, 0.85, 0.55, 0.95), 1.5, true)
		# Siege marker — red ring
		if not p.is_sea and p.siege_progress > 0.0:
			var frac: float = clamp(p.siege_progress, 0.0, 1.0)
			draw_arc(p.center, 13.0, -PI * 0.5, -PI * 0.5 + frac * TAU, 24, Color(1, 0.3, 0.3, 0.9), 2.0)

	# Selection highlight
	if GameState.selected_province_id >= 0 and GameState.selected_province_id < GameState.provinces.size():
		var sp: Province = GameState.provinces[GameState.selected_province_id]
		draw_polyline(_closed(sp.polygon), HIGHLIGHT, 3.0, true)

	# Units are drawn by _units_node (child).

func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var arr := PackedVector2Array(poly)
	if arr.size() > 0:
		arr.append(arr[0])
	return arr

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var world_pos: Vector2 = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			for uid in GameState.units.keys():
				var u: ArmyUnit = GameState.units[uid]
				var origin: Province = GameState.provinces[u.province_id] if u.province_id >= 0 else null
				if origin == null: continue
				var pos: Vector2 = origin.center
				if u.orders == "move" and u.dest_province_id != -1:
					var dest: Province = GameState.provinces[u.dest_province_id]
					if dest != null:
						pos = origin.center.lerp(dest.center, clamp(u.move_progress, 0.0, 1.0))
				if world_pos.distance_to(pos) < 12.0:
					var game_root := get_parent()
					if game_root.has_method("on_unit_clicked"):
						game_root.on_unit_clicked(uid)
					get_viewport().set_input_as_handled()
					return
			var pid := _province_at(world_pos)
			if pid >= 0:
				var game_root := get_parent()
				if game_root.has_method("on_province_clicked"):
					game_root.on_province_clicked(pid)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var pid := _province_at(world_pos)
			if pid >= 0:
				var game_root := get_parent()
				if game_root.has_method("on_province_right_clicked"):
					game_root.on_province_right_clicked(pid)
				get_viewport().set_input_as_handled()

func _province_at(world_pos: Vector2) -> int:
	for p in GameState.provinces:
		if world_pos.distance_squared_to(p.center) > 1600.0:
			continue
		if Geometry2D.is_point_in_polygon(world_pos, p.polygon):
			return p.id
	var best_id: int = -1
	var best_d: float = 28.0
	for p in GameState.provinces:
		var d: float = world_pos.distance_to(p.center)
		if d < best_d:
			best_d = d
			best_id = p.id
	return best_id
