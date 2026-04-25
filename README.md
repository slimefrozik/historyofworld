# History of the World

A top-down **geopolitical simulator** built in Godot 4.3. Lead historical nations through five eras — Antiquity, Medieval, Renaissance, Industrial, Modern — and shape the world through diplomacy, war, science, culture, and intrigue.

![map_preview](icon.svg)

## Features

- **Stylized world map** of Earth, procedurally divided into ~500 hex provinces with terrain (plains, forest, hills, mountains, desert, steppe, jungle, tundra, coast).
- **22 playable historical nations** across 5 eras, each with their own starting region, government, culture and religion. Pick from Rome, Han China, Ptolemaic Egypt, Persia, Mauryan India, Gauls, Germanics, Mongol Khanate, Medieval France/England, Byzantium, Japan, Ottomans, Spain, Habsburg Austria, Russia, USA, British Empire, German Empire, Soviet Union, Modern China, and more.
- **Advanced army system** with 15 era-gated unit types: levies, spearmen, horse archers, legionaries, knights, men-at-arms, longbowmen, pikemen, musketeers, cuirassiers, line infantry, artillery, riflemen, tanks, mechanized infantry. Each has attack/defense/discipline stats and unlocks via specific techs.
- **Economy** — base tax + tech multipliers, manpower pool, building maintenance, army upkeep.
- **Science** — 25-tech research tree spanning all 5 eras, with prerequisites, unlocks, and effects (research speed, tax, manpower, culture, stability, unit unlocks).
- **Culture** — culture points generated per province, modified by techs.
- **Diplomacy** — relations score (-200 … +200) per pair, declare war, make peace, form/break alliances, send gifts to improve standing.
- **Intrigue** — fabricate claims on enemy provinces, send spies to steal tech, attempt assassinations against rival rulers (success driven by intrigue stats and traits).
- **Characters with traits and power levels** — each nation has a Ruler, 3 Advisors, 2 Generals (more can spawn). 15 personality traits (Brilliant Strategist, Craven, Born Diplomat, Deceitful, Midas Touched, Wasteful, Scholar, Ambitious, Loyal, Wrathful, Patient, Zealous, Cynical, Humble, Vengeful) modify Martial / Diplomacy / Stewardship / Intrigue / Learning. Rulers age, can be assassinated, and successors take over.
- **Real-time-with-pause** simulation, 5 speed levels, monthly economy & research ticks, yearly relations decay & character ageing.
- **AI opponents** — non-player nations research, recruit, march on enemies, and run their own diplomacy.
- **Save / load** to JSON.
- **Cross-platform release builds** for Windows and Linux.

## Controls

| Key / Mouse | Action |
|---|---|
| WASD / Arrow keys | Pan the camera |
| Mouse wheel | Zoom in / out |
| Left-click province | Select / inspect |
| Left-click own army | Pick up army for movement |
| Right-click adjacent province | Move selected army there (one province per order) |
| Space | Pause / unpause |
| `+` / `-` | Speed up / down (5 levels) |
| `D` | Toggle diplomacy panel |
| `T` | Toggle technology panel |
| `C` | Toggle court / characters panel |
| `F5` | Quick save (slot `main`) |
| `F9` | Quick load |
| `Esc` | Close all panels |

## Running

### From a release build

Download the appropriate build from the GitHub Release and run:

- **Windows:** double-click `HistoryOfTheWorld_windows.exe` (the `.pck` file must be next to it).
- **Linux:** `chmod +x HistoryOfTheWorld_linux.x86_64 && ./HistoryOfTheWorld_linux.x86_64`.

### From source

1. Install [Godot 4.3 stable (Standard)](https://godotengine.org/download).
2. Open the project (`project.godot`) in Godot.
3. Press F5 to play; first run will prompt for the main scene — pick `scenes/Boot.tscn`.

## Building from source

With the Godot 4.3 editor on PATH and the export templates installed:

```bash
godot --headless --path . --export-release "Linux/X11"   exports/HistoryOfTheWorld_linux.x86_64
godot --headless --path . --export-release "Windows Desktop" exports/HistoryOfTheWorld_windows.exe
```

The bundled `export_presets.cfg` already declares both targets.

## Architecture

```
project.godot           Godot configuration + autoloads
scenes/                 Boot, MainMenu, Game (.tscn)
scripts/
  game_state.gd         Singleton: world state, relations, lookups
  world_generator.gd    Procedural map + country placement
  time_controller.gd    Daily / monthly / yearly tick driver
  ai_controller.gd      AI for non-player nations + diplomacy actions
  movement_battle.gd    Unit movement, battle resolution, conquest
  save_load.gd          JSON save/load (user://saves/)
  province.gd           Province data class
  country.gd            Country data class
  unit.gd               Army-unit data class
  character.gd          Character (ruler/advisor/general) data class
  map_view.gd           Map renderer (Polygon2D draw + clicks)
  camera_controller.gd  Top-down RTS camera
  main_menu.gd          Era + country selection
  game.gd               Top bar / panels / interaction glue
data/
  countries.json        Historical nations + starting regions
  unit_types.json       Era-gated unit roster
  tech_tree.json        Research tree
  traits.json           Personality traits
  eras.json             Era definitions
  regions.json          Geographic region rectangles
  names.json            Procedural name pools
```

## Scope notes

This is an **MVP / prototype** built in a single session — it has all the listed systems wired together and is end-to-end playable, but is not the depth of a full Paradox-class grand strategy game. Easy avenues for further work:

- Real coastline / heightmap-derived continents instead of stylized blobs.
- Multi-hop pathfinding for armies (currently move one province per order).
- Naval units & boarding.
- Trade routes, market goods.
- Religious schism / heresy, missionary mechanics.
- Estates / parliament / political factions.
- Generated wars-of-succession and civil-war events.
- Full localization of all strings.

Pull requests welcome.
