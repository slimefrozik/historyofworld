extends Node
func _ready() -> void:
	await get_tree().process_frame
	for era in ["antiquity", "medieval", "renaissance", "industrial", "modern"]:
		GameState.provinces.clear()
		GameState.countries.clear()
		GameState.units.clear()
		GameState.characters.clear()
		var t0 := Time.get_ticks_msec()
		WorldGen.generate(era)
		var gen_ms: int = Time.get_ticks_msec() - t0
		var land: int = 0; var sea: int = 0
		for p in GameState.provinces:
			if p.is_sea: sea += 1
			else: land += 1
		var country_provinces := {}
		for cid in GameState.countries.keys():
			var c: Country = GameState.countries[cid]
			country_provinces[cid] = c.province_ids.size()
		# Run a year of month ticks to exercise ledger push + log categories.
		GameState.player_country_id = GameState.countries.keys()[0]
		GameState.ledger_history.clear()
		GameState.event_log.clear()
		for _i in range(12):
			TimeCtl._on_month()
		var cat_counts := {"war": 0, "diplo": 0, "econ": 0, "culture": 0, "general": 0}
		for e in GameState.event_log:
			var cat: String = String(e.get("category", "general"))
			cat_counts[cat] = int(cat_counts.get(cat, 0)) + 1
		print("[%s] gen=%dms land=%d sea=%d countries=%d ledger=%d log=%d cats=%s" % [
			era, gen_ms, land, sea, GameState.countries.size(),
			GameState.ledger_history.size(), GameState.event_log.size(), cat_counts,
		])
		var empty: Array = []
		for cid in country_provinces.keys():
			if country_provinces[cid] == 0: empty.append(cid)
		if empty.size() > 0:
			print("  EMPTY COUNTRIES: ", empty)
	get_tree().quit()
