#!/usr/bin/env python3
"""
Generate a low-resolution Earth landmask for the Godot game.
Draws hand-approximated continent outlines in (lon, lat) space,
rasterizes into a W x H bitmap (equirectangular projection),
and emits a GDScript constant the game can embed.
"""
from PIL import Image, ImageDraw

W, H = 240, 120   # 1.5° per cell
# (lon, lat) polygons for major landmasses. Rough but recognizable.
# Longitudes: -180..+180 (0 = Greenwich).  Latitudes: -90..+90 (positive = north).
CONTINENTS = {
    "north_america": [
        (-168, 65), (-158, 70), (-140, 70), (-128, 71), (-100, 73), (-80, 75),
        (-70, 70), (-63, 60), (-58, 48), (-67, 45), (-67, 40), (-76, 35),
        (-82, 30), (-82, 26), (-88, 22), (-98, 20), (-106, 24), (-115, 30),
        (-124, 35), (-128, 42), (-134, 52), (-160, 58), (-168, 65),
    ],
    "central_america": [
        (-105, 20), (-98, 20), (-92, 17), (-88, 16), (-83, 12), (-80, 9),
        (-82, 8), (-89, 14), (-95, 17), (-105, 18), (-105, 20),
    ],
    "south_america": [
        (-80, 12), (-72, 12), (-60, 10), (-50, 5), (-35, -5), (-35, -22),
        (-40, -35), (-55, -40), (-65, -40), (-70, -52), (-72, -55), (-75, -48),
        (-78, -35), (-82, -20), (-81, -5), (-80, 0), (-80, 12),
    ],
    "greenland": [
        (-55, 83), (-30, 83), (-20, 78), (-22, 70), (-38, 60), (-50, 60),
        (-58, 70), (-60, 78), (-55, 83),
    ],
    "iceland": [
        (-25, 66), (-14, 66), (-13, 64), (-22, 63), (-25, 64), (-25, 66),
    ],
    "britain": [
        (-6, 59), (-1, 59), (1, 55), (1, 51), (-4, 50), (-6, 52), (-6, 59),
    ],
    "ireland": [
        (-10, 55), (-6, 55), (-6, 52), (-10, 52), (-10, 55),
    ],
    "europe_main": [
        # Iberia
        (-10, 44), (-8, 36), (-5, 36), (0, 38), (3, 42), (8, 44),
        # Italy
        (8, 45), (7, 44), (15, 40), (18, 40), (15, 44), (14, 46),
        # Central + eastern Europe
        (20, 43), (30, 42), (40, 44), (45, 42),
        # Black Sea north / Russia south
        (50, 48), (60, 52), (70, 58), (70, 70), (60, 72), (40, 72),
        (25, 72), (15, 68), (10, 62), (5, 55), (0, 52), (-8, 48), (-10, 44),
    ],
    "scandinavia": [
        (5, 70), (25, 70), (30, 65), (30, 60), (16, 58), (8, 60), (5, 65), (5, 70),
    ],
    "asia_main": [
        # connect from Caucasus eastward
        (40, 45), (55, 40), (60, 35), (70, 30), (75, 32), (85, 45),
        (95, 48), (105, 48), (115, 50), (125, 52), (135, 50), (140, 55),
        (150, 60), (165, 65), (175, 68), (179, 70), (179, 76), (160, 78),
        (140, 76), (120, 75), (100, 72), (85, 70), (75, 72), (65, 72),
        (60, 70), (55, 65), (50, 58), (45, 52), (40, 45),
    ],
    "china_india": [
        (70, 30), (80, 30), (88, 28), (95, 28), (100, 25), (110, 22),
        (120, 24), (122, 30), (122, 38), (118, 40), (105, 42), (95, 45),
        (85, 45), (80, 40), (75, 36), (70, 30),
    ],
    "india_peninsula": [
        (68, 24), (73, 22), (75, 18), (78, 12), (80, 8), (82, 10),
        (85, 16), (90, 22), (92, 25), (88, 28), (80, 30), (72, 28), (68, 24),
    ],
    "southeast_asia": [
        # Indochina + Malaysia (rough)
        (95, 22), (105, 20), (108, 16), (108, 12), (105, 8), (103, 2),
        (100, 1), (98, 8), (96, 15), (95, 22),
    ],
    "korea": [
        (125, 39), (130, 39), (130, 34), (126, 34), (125, 39),
    ],
    "japan": [
        (130, 33), (141, 41), (145, 44), (142, 45), (135, 35), (130, 33),
    ],
    "philippines": [
        (120, 19), (126, 16), (126, 7), (120, 6), (118, 10), (120, 19),
    ],
    "indonesia_java": [
        (95, 4), (110, 3), (120, 2), (128, -2), (135, -4), (140, -4),
        (140, -8), (125, -9), (115, -8), (105, -7), (95, -6), (95, 4),
    ],
    "new_guinea": [
        (132, -1), (150, -6), (150, -10), (140, -10), (132, -6), (132, -1),
    ],
    "australia": [
        (114, -22), (123, -18), (135, -13), (142, -10), (145, -15),
        (152, -25), (150, -35), (138, -38), (125, -33), (115, -33),
        (114, -22),
    ],
    "tasmania": [
        (144, -41), (148, -41), (148, -44), (144, -44), (144, -41),
    ],
    "new_zealand": [
        (172, -34), (178, -38), (175, -46), (168, -46), (170, -40), (172, -34),
    ],
    "africa_main": [
        (-18, 21), (-10, 30), (10, 35), (22, 32), (34, 30), (34, 25),
        (42, 16), (50, 12), (52, 8), (51, 3), (42, -5), (40, -15),
        (38, -22), (30, -30), (24, -34), (18, -34), (12, -18),
        (8, -5), (3, 4), (-5, 5), (-10, 7), (-17, 12), (-18, 21),
    ],
    "madagascar": [
        (43, -12), (50, -15), (50, -25), (46, -25), (43, -12),
    ],
    "arabia": [
        (34, 30), (38, 30), (46, 28), (52, 25), (56, 19), (53, 15),
        (48, 12), (42, 13), (38, 20), (34, 25), (34, 30),
    ],
    "caucasus_mid": [
        (28, 38), (40, 36), (50, 36), (55, 40), (50, 45), (42, 44),
        (35, 42), (28, 40), (28, 38),
    ],
    "iran_plateau": [
        (44, 40), (55, 40), (65, 38), (70, 32), (68, 27), (60, 25),
        (55, 26), (48, 29), (44, 34), (44, 40),
    ],
    "levant": [
        (34, 37), (38, 37), (40, 32), (36, 30), (34, 31), (34, 37),
    ],
    "indonesia_sumatra": [
        (95, 6), (100, 3), (104, -2), (103, -6), (95, -2), (95, 6),
    ],
    "indonesia_borneo": [
        (109, 4), (118, 4), (119, -1), (117, -4), (110, -4), (109, -1), (109, 4),
    ],
    "antarctica": [(-180, -90), (180, -90), (180, -67), (-180, -67), (-180, -90)],
}


def lonlat_to_px(lon, lat):
    # Longitude -180..180 -> x 0..W
    x = (lon + 180.0) / 360.0 * W
    # Latitude +90..-90 -> y 0..H (top = north)
    y = (90.0 - lat) / 180.0 * H
    return x, y


img = Image.new("L", (W, H), 0)
draw = ImageDraw.Draw(img)
for name, poly in CONTINENTS.items():
    draw.polygon([lonlat_to_px(lon, lat) for lon, lat in poly], fill=255)

# Smooth the edges slightly so we don't get jaggy coastlines, then threshold.
from PIL import ImageFilter

img = img.filter(ImageFilter.SMOOTH)
data = img.load()

# Emit as GDScript constants.
lines = []
lines.append("# Auto-generated by tools/gen_landmask.py — do not hand-edit.")
lines.append(f"const LANDMASK_W: int = {W}")
lines.append(f"const LANDMASK_H: int = {H}")
lines.append("const LANDMASK_HEX: String = \\")
hex_rows = []
for y in range(H):
    # Pack 240 bits → 60 hex chars per row.
    bits = 0
    for x in range(W):
        if data[x, y] >= 128:
            bits |= 1 << (W - 1 - x)
    hex_row = format(bits, f"0{W // 4}x")
    hex_rows.append(hex_row)
joined = "".join(hex_rows)
# Break into 60-char chunks for readability.
for i in range(0, len(joined), 60):
    sep = " + \\" if i + 60 < len(joined) else ""
    lines.append(f'\t"{joined[i:i+60]}"{sep}')

out = "\n".join(lines) + "\n"
import sys

sys.stdout.write(out)

# ASCII preview to stderr so we can eyeball the map.
for y in range(0, H, 2):
    row = "".join("#" if data[x, y] >= 128 else "." for x in range(0, W, 2))
    sys.stderr.write(row + "\n")
