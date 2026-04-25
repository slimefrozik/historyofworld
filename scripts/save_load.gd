## Save/load to JSON in user://saves/.
extends Node

const SAVE_DIR := "user://saves"

func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save(slot: String) -> bool:
	ensure_dir()
	var data := {
		"version": 1,
		"era": GameState.current_era,
		"year": GameState.year,
		"month": GameState.month,
		"day": GameState.day,
		"player_country_id": GameState.player_country_id,
		"next_unit_id": GameState.next_unit_id,
		"next_char_id": GameState.next_char_id,
		"provinces": [],
		"countries": {},
		"units": {},
		"characters": {},
		"relations": GameState.relations,
	}
	for p in GameState.provinces:
		data.provinces.append(p.to_dict())
	for cid in GameState.countries.keys():
		data.countries[cid] = GameState.countries[cid].to_dict()
	for uid in GameState.units.keys():
		data.units[str(uid)] = GameState.units[uid].to_dict()
	for chid in GameState.characters.keys():
		data.characters[str(chid)] = GameState.characters[chid].to_dict()
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	GameState.log_event("Saved to slot '%s'." % slot, Color(0.7, 0.95, 0.7))
	return true

func load_save(slot: String) -> bool:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null: return false
	GameState.reset()
	GameState.current_era = String(data.get("era", "antiquity"))
	GameState.year = int(data.get("year", -500))
	GameState.month = int(data.get("month", 1))
	GameState.day = int(data.get("day", 1))
	GameState.player_country_id = String(data.get("player_country_id", ""))
	GameState.next_unit_id = int(data.get("next_unit_id", 1))
	GameState.next_char_id = int(data.get("next_char_id", 1))
	for pd in data.get("provinces", []):
		GameState.provinces.append(Province.from_dict(pd))
	for cid in data.get("countries", {}).keys():
		var c := Country.from_dict(data.countries[cid])
		GameState.countries[cid] = c
	GameState.relations = data.get("relations", {})
	for uid in data.get("units", {}).keys():
		var u := ArmyUnit.from_dict(data.units[uid])
		GameState.units[u.id] = u
	for chid in data.get("characters", {}).keys():
		var ch := Character.from_dict(data.characters[chid])
		GameState.characters[ch.id] = ch
	GameState.world_ready.emit()
	GameState.log_event("Loaded slot '%s'." % slot, Color(0.7, 0.95, 0.7))
	return true

func list_slots() -> Array:
	ensure_dir()
	var d := DirAccess.open(SAVE_DIR)
	if d == null: return []
	var names := []
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".json"):
			names.append(f.replace(".json", ""))
		f = d.get_next()
	d.list_dir_end()
	return names
