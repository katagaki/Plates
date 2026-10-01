from draw import *

# Every ingredient in the app's catalog, keyed by the catalog's kebab-case name, with the
# variants it can be drawn as on a finished dish. An ingredient that cannot be seen once a dish
# is served is listed in HIDDEN with the reason, so the layout leaves it out on purpose.

PLATES = ["plate"]
BOWLS = ["bowl", "pot"]
ANY = ["plate", "bowl", "pan", "pot"]
SAUCE = ["plate", "bowl", "pan", "pot"]
FLAT = ["plate", "board"]
MOUND = ["plate", "pan"]


# Sizes are on the 96 canvas. Scattered pieces are drawn a quarter larger than written, and
# nothing set in the middle is drawn smaller than 18, which is what the review sheets showed
# still reads at the size the grid shows a card.
def p(svg, size, count, tier=0):
    if tier == 0:
        size = round(size * 1.25)
    elif tier == 1:
        size = max(size, 18)
    else:
        size = max(round(size * 1.15), 5)
    return {"kind": "piece", "svg": svg, "size": size, "count": count, "tier": tier}


def fl(maker, vessels, covers=False):
    entry = {"kind": "fill", "make": maker, "vessels": vessels}
    if covers:
        entry["covers"] = True
    return entry


def garnish(svg, size, count):
    return p(svg, size, count, 2)


def center(svg, size, count=1):
    return p(svg, size, count, 1)


GREEN, GREEN_L, GREEN_D = "#7fb069", "#a8cf8e", "#4f8a3a"
DARK_LEAF, DARK_LEAF_L = "#3f6b3a", "#5f8f45"
CREAM = "#f4f1e8"
RED, RED_L = "#d94f45", "#e8695f"

V = {}

# Vegetables --------------------------------------------------------------------------------

V["artichoke"] = {"quartered": p(quarter("#7f9c5a", "#e9e3b8", "#c9c08a"), 14, 4)}
V["arugula"] = {"leaves": garnish(leaf("#4f8a3a", "#7fb069"), 12, 6), "bed": fl(lambda r: bed(r, ["#4f8a3a", "#5f9a45", "#6aa04f"], "#8fbf6f"), PLATES + BOWLS)}
V["asparagus"] = {"spears": p(spear("#7fb069", "#5f8f45", "#a8cf8e"), 18, 4), "cut": p(julienne("#7fb069"), 10, 7)}
V["bamboo-shoots"] = {"slices": p(half_moon("#c9b46f", "#efe2b0"), 13, 5)}
V["bean-sprouts"] = {"sprouts": p(shreds("#ece4c4", "#e0c860"), 13, 6)}
V["beetroot"] = {"diced": p(dice("#9b2a4a", "#c4476b"), 10, 7), "sliced": p(round_slice("#7d1f3c", "#b8355e", rings="#d4708f"), 14, 4), "wedges": p(wedge("#7d1f3c", "#b8355e"), 13, 5)}
V["bell-pepper"] = {"strips": p(strip("#d94f45", "#ef7a6a"), 13, 6), "diced": p(dice("#d94f45", "#ef7a6a"), 9, 8)}
V["bitter-melon"] = {"slices": p(ring("#5f9a45", "#e8efcf", 2.6), 11, 6)}
V["bok-choy"] = {"halves": p('<path d="M2 8c0-4 3-6.5 6-6.5s6 2.5 6 6.5c0 2-1 3-2 3.5L9 15H7l-3-3.5C3 11 2 10 2 8Z" fill="#5f9a45"/><path d="M6 6.5c0-2 1-3 2-3s2 1 2 3L9 15H7Z" fill="#eef3d6"/>', 16, 3)}
V["broccoli"] = {"florets": p(floret("#5f9a45", "#7fb069", "#a8cf8e"), 14, 5)}
V["brussels-sprouts"] = {"halves": p('<circle cx="8" cy="8" r="6.5" fill="#6aa04f"/><path d="M8 2.5c-3 2-3 9 0 11M8 2.5c3 2 3 9 0 11" stroke="#c5dea8" stroke-width="1.1" fill="none"/><path d="M3 8h10" stroke="#a8cf8e" stroke-width="0.9"/>', 12, 5)}
V["burdock"] = {"julienne": p(julienne("#9c7a55", "#c4a37a"), 11, 8)}
V["butternut-squash"] = {"cubes": p(dice("#f0a646", "#f7c27a"), 11, 6), "mash": fl(lambda r: smooth(r, "#f0a646", "#f7c27a", ridges="#e0902f"), PLATES + BOWLS), "soup": fl(lambda r: soup(r, "#f0a646", "#f7c27a"), BOWLS)}
V["cabbage"] = {"shredded": fl(lambda r: shredded_bed(r, ["#dcebc9", "#c5dea8", "#b4d494"]), PLATES + BOWLS), "chopped": p(torn_leaf("#c5dea8", "#eef3d6"), 13, 5)}
V["carrot"] = {"coins": p(round_slice("#ff832b", "#ffa25c", core="#ffb97a"), 11, 6), "diced": p(dice("#ff832b", "#ffa25c"), 9, 7), "julienne": p(julienne("#ff832b", "#ffa25c"), 11, 7), "chunks": p(chunk("#ff832b", "#ffa25c"), 11, 4)}
V["cauliflower"] = {"florets": p(floret("#f2ecd8", "#fbf7ea", "#dcebc9"), 14, 5)}
V["celery"] = {"slices": p(half_moon("#7fb069", "#c5dea8"), 10, 7)}
V["cherry-tomato"] = {"halves": p(round_slice("#d94f45", "#e8695f", seeds="#f4c27a"), 11, 6), "whole": p(berry("#d94f45", "#f08a6a", "#5f8f45"), 11, 5)}
V["chili"] = {"rings": garnish(ring("#d23a30", "#f4c27a", 2.6), 9, 7)}
V["chives"] = {"snipped": garnish(julienne("#4f8a3a"), 6, 12)}
V["corn"] = {"kernels": p(kernels("#f6c84a", "#ffe58a"), 10, 6)}
V["cucumber"] = {"slices": p(round_slice("#4f8a3a", "#dfeec4", seeds="#b9d48f"), 13, 5), "half-moons": p(half_moon("#4f8a3a", "#dfeec4", "#b9d48f"), 12, 6), "julienne": p(julienne("#c5dea8", "#4f8a3a"), 11, 7)}
V["daikon"] = {"grated": center(dollop("#f8f6ef", "#e6e0d4"), 22), "simmered": p(round_slice("#e2cfa0", "#efe2bf"), 15, 3), "slices": p(round_slice("#f4f1e8", "#fbf9f4"), 13, 4)}
V["edamame"] = {"pods": p(pod("#6aa04f", "#a8cf8e"), 13, 5), "beans": p(small_round("#7fb069", "#a8cf8e"), 7, 9)}
V["eggplant"] = {"slices": p(round_slice("#5b3a6b", "#e9dfb8", seeds="#c9b98a"), 14, 4), "chunks": p(cube("#d9c28f", "#efe2bf", "#5b3a6b"), 12, 5)}
V["enoki"] = {"clusters": p(enoki("#f4ecd0", "#e8dcb4"), 14, 3)}
V["fennel"] = {"slices": p(half_moon("#cfe0a8", "#eef3d6"), 13, 5)}
V["gai-lan"] = {"stalks": p(spear("#4f8a3a", "#3f6b3a", "#7fb069"), 18, 4)}
V["garlic"] = {"chips": p('<ellipse cx="8" cy="8" rx="6.5" ry="5" fill="#b98340"/><ellipse cx="8" cy="8" rx="4.6" ry="3.4" fill="#f3dca8"/>', 12, 7), "minced": garnish(dust("#ead69c", "#f6ecd0"), 11, 3), "roasted": p(teardrop("#d9a85c", "#f0d49a"), 10, 5)}
V["ginger"] = {"julienne": garnish(julienne("#e9c88a", "#f3dca8"), 10, 6), "grated": center(dollop("#efd7a0", "#f8e9c4"), 22)}
V["green-beans"] = {"cut": p(spear("#5f9a45", "#4f8a3a"), 12, 7)}
V["jalapeno"] = {"rings": p(ring("#4f8a3a", "#e8efcf", 2.6), 11, 6)}
V["kabocha"] = {"wedges": p(wedge("#3f6b3a", "#f0a646"), 14, 4), "cubes": p(cube("#f0a646", "#f7c27a", "#3f6b3a"), 12, 5)}
V["kale"] = {"torn": p(torn_leaf("#3f6b3a", "#5f8f45"), 14, 5), "bed": fl(lambda r: bed(r, ["#3f6b3a", "#4a7a3f", "#557f47"], "#7fb069"), PLATES + BOWLS)}
V["kimchi"] = {"pieces": p('<path d="M2 10c2-5 6-7 12-6-1 5-6 9-12 6Z" fill="#d94f45"/><path d="M5 9c2-2 4-3 7-3" stroke="#f07a4f" stroke-width="1.6" fill="none" stroke-linecap="round"/>', 13, 5)}
V["king-oyster"] = {"slices": p(mushroom_slice("#d9c39a", "#f2e8cf"), 14, 4), "coins": p(coin("#d9b98a", "#f2e8cf"), 12, 5)}
V["komatsuna"] = {"chopped": p(torn_leaf("#4f8a3a", "#7fb069"), 13, 5)}
V["leek"] = {"rings": p(ring("#c5dea8", "#eef3d6", 2.4), 10, 6)}
V["lettuce"] = {"torn": p(torn_leaf("#a8cf8e", "#dcebc9"), 15, 4), "bed": fl(lambda r: bed(r, ["#a8cf8e", "#93c27a", "#b9d89f"], "#dcebc9"), PLATES + BOWLS)}
V["lotus-root"] = {"slices": p('<circle cx="8" cy="8" r="7" fill="#e2d2ae"/><circle cx="8" cy="8" r="6" fill="#f2e8cf"/>' + "".join(f'<circle cx="{f(8 + 3.4 * math.cos(math.tau * i / 6))}" cy="{f(8 + 3.4 * math.sin(math.tau * i / 6))}" r="1.3" fill="#d4c39c"/>' for i in range(6)) + '<circle cx="8" cy="8" r="1.1" fill="#d4c39c"/>', 14, 4)}
V["mizuna"] = {"leaves": p(torn_leaf("#6aa04f", "#c5dea8"), 13, 5), "bed": fl(lambda r: bed(r, ["#6aa04f", "#7fb069", "#5f9a45"], "#c5dea8"), PLATES + BOWLS)}
V["mushroom"] = {"sliced": p(mushroom_slice("#a87e5a", "#ead9bd"), 13, 5), "quartered": p(chunk("#a87e5a", "#ead9bd"), 11, 5)}
V["myoga"] = {"shredded": garnish(shred("#e9a3a8", 2), 8, 6)}
V["napa-cabbage"] = {"chopped": p('<path d="M2 8c0-4 3-6 6-5.5 2-1.5 5 0 5.5 2.5 2 1.5 1.5 5-.5 6-1 2.5-4 3.5-6.5 2-3 .5-4.5-2-4.5-5Z" fill="#cfe3b0"/><path d="M3 12 12 4" stroke="#f6f8ea" stroke-width="3" stroke-linecap="round"/>', 14, 5)}
V["nira"] = {"cut": p(julienne("#3f6b3a", "#5f8f45"), 11, 7)}
V["okra"] = {"slices": p('<path d="M8 1.5 10 4.5 13.6 4.8 12.4 8 13.6 11.2 10 11.5 8 14.5 6 11.5 2.4 11.2 3.6 8 2.4 4.8 6 4.5Z" fill="#5f9a45"/><circle cx="8" cy="8" r="3.2" fill="#e8efcf"/>' + "".join(f'<circle cx="{f(8 + 2 * math.cos(math.tau * i / 5))}" cy="{f(8 + 2 * math.sin(math.tau * i / 5))}" r="0.6" fill="#c5dea8"/>' for i in range(5)), 10, 6)}
V["onion"] = {"rings": p(ring("#efe2c4", "#f8f2e2", 2.2), 11, 5), "diced": p(dice("#f4ecd6", "#fbf7ea"), 7, 9), "caramelized": p(shreds("#b9763c", "#d39a5a"), 12, 5)}
V["parsnip"] = {"coins": p(round_slice("#e2cfa0", "#f2e6c4", core="#e8d6a8"), 11, 6), "roasted": p(chunk("#d9a85c", "#f0d49a"), 12, 4)}
V["peas"] = {"peas": p(small_round("#6aa04f", "#a8cf8e"), 6, 10)}
V["potato"] = {"chunks": p(chunk("#ead08f", "#f6e3b0"), 12, 4), "wedges": p(wedge("#c99a5e", "#f2d58e"), 14, 4), "slices": p(round_slice("#e6c36f", "#f4dc9a"), 13, 4), "mash": fl(lambda r: smooth(r, "#f2e2b0", "#faf0d0", ridges="#e4cf92"), PLATES + BOWLS)}
V["pumpkin"] = {"cubes": p(dice("#f08a2b", "#f7ad5c"), 11, 6), "soup": fl(lambda r: soup(r, "#f08a2b", "#f7ad5c"), BOWLS)}
V["radish"] = {"slices": p(round_slice("#d94f63", "#fbf7f2", rings="#f2d6dc"), 10, 6)}
V["red-onion"] = {"rings": p(ring("#9b4a7a", "#e8c6d8", 2.2), 11, 5), "diced": p(dice("#b5608e", "#e8c6d8"), 7, 9)}
V["shallot"] = {"crispy": garnish(shreds("#a8682f", "#c98a4b"), 9, 5), "rings": p(ring("#b97a8e", "#ecd2da", 1.8), 8, 6)}
V["shiitake"] = {"caps": p(mushroom_cap("#8a5a3a", "#d9b48a", "#6f4a2f"), 13, 4), "sliced": p(mushroom_slice("#8a5a3a", "#e6d3b4"), 12, 5)}
V["shimeji"] = {"clusters": p(small_caps("#b89a74", "#d9c3a0"), 13, 4)}
V["shiso"] = {"shredded": garnish(shred("#4f8a3a", 1.8), 8, 7), "leaf": center(leaf("#4f8a3a", "#7fb069"), 28)}
V["shungiku"] = {"leaves": p(torn_leaf("#5f9a45", "#a8cf8e"), 13, 5)}
V["snow-peas"] = {"pods": p('<path d="M1.5 10c2-6 9-8 13-6-1 6-8 9-13 6Z" fill="#7fb069"/><path d="M3 9.5c3-1 7-3 10-5" stroke="#a8cf8e" stroke-width="1" fill="none" stroke-linecap="round"/>', 14, 5)}
V["spinach"] = {"wilted": p(torn_leaf("#3f6b3a", "#5f8f45"), 13, 5), "bed": fl(lambda r: bed(r, ["#3f6b3a", "#4a7a3f", "#557f47"], "#6f9a55"), PLATES + BOWLS)}
V["spring-onion"] = {"rings": garnish(rings_small("#7fb069", "#a8cf8e", "#dcebc9"), 8, 7), "sliced": p(julienne("#7fb069", "#dcebc9"), 11, 6)}
V["sweet-potato"] = {"coins": p(round_slice("#8a3a5a", "#f2c46a"), 13, 4), "cubes": p(cube("#f2c46a", "#f8d98f", "#8a3a5a"), 11, 6), "mash": fl(lambda r: smooth(r, "#f0b45a", "#f8cf88", ridges="#e09a3f"), PLATES + BOWLS)}
V["swiss-chard"] = {"torn": p(torn_leaf("#3f6b3a", "#d9536b"), 14, 5)}
V["taro"] = {"chunks": p('<path d="M2 6.5 7.5 2.5 14 5.5 13 12.5 5 14 1.5 10.5Z" fill="#e8dccf"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.7" fill="#b9a6c2"/>' for x, y in ((6, 6), (10, 7), (7, 10.5), (11, 11))), 12, 5)}
V["tomato"] = {"diced": p(dice("#d94f45", "#f08a6a"), 10, 8), "sliced": p('<circle cx="8" cy="8" r="7" fill="#d94f45"/><circle cx="8" cy="8" r="5.4" fill="#e8695f"/><path d="M8 3.5v9M3.8 6l8.4 4M3.8 10l8.4-4" stroke="#d94f45" stroke-width="1.3"/><circle cx="8" cy="8" r="1.3" fill="#f4b8a0"/>', 18, 4), "wedges": p(wedge("#d94f45", "#f08a6a", "#f4c27a"), 14, 5), "sauce": fl(lambda r: smooth(r, "#d94f45", "#e8695f"), SAUCE)}
V["turnip"] = {"wedges": p(wedge("#a8608e", "#f8f5ee"), 13, 5), "slices": p(round_slice("#f2edf2", "#fbf9f4"), 12, 5)}
V["water-chestnut"] = {"slices": p(round_slice("#d9c9a8", "#fbf7ea"), 10, 6)}
V["watercress"] = {"sprigs": p(sprig("#3f6b3a", "#5f8f45"), 13, 5)}
V["yam"] = {"grated": center(dollop("#f6f2e6", "#e2dccb"), 22), "cubes": p(cube("#f6f2e6", "#fbf9f4", "#c9b48f"), 10, 6)}
V["zucchini"] = {"coins": p(round_slice("#4f8a3a", "#e6eec0", seeds="#c5d89a"), 12, 5), "half-moons": p(half_moon("#4f8a3a", "#e6eec0"), 12, 6)}

# Fruits ------------------------------------------------------------------------------------

V["apple"] = {"slices": p(crescent("#c9373f", "#f6ecc8"), 14, 5), "diced": p(cube("#f6ecc8", "#fbf7ea", "#c9373f"), 9, 7)}
V["avocado"] = {"half": center(avocado_half("#3f5a2a", "#c9dc8a", "#8a5a3a"), 30), "sliced": p(crescent("#3f5a2a", "#c9dc8a"), 15, 4), "diced": p(cube("#c9dc8a", "#e2edb8", "#6f8f3a"), 9, 7)}
V["banana"] = {"coins": p(round_slice("#f2e2a6", "#fbf2cc", seeds="#c9b07a"), 11, 6)}
V["blueberry"] = {"berries": p(berry("#4b5a9e", "#7c8ac2"), 7, 8)}
V["cherry"] = {"whole": p(cherry("#a3243a", "#d4556b", "#5f8f45"), 12, 4)}
V["coconut"] = {"flakes": garnish(flake("#fbf9f4", "#e6e0d4"), 9, 6)}
V["dates"] = {"chopped": p(chunk("#7a4a2a", "#a0683f"), 8, 6)}
V["fig"] = {"quarters": p(quarter("#6b3a5a", "#e88a8a", "#f6d6a8"), 13, 4)}
V["grape"] = {"halves": p(round_slice("#8fbf5a", "#c9e09a", seeds="#a8cf7a"), 9, 7), "whole": p(berry("#6b3a7a", "#9a6aa8"), 9, 6)}
V["grapefruit"] = {"segments": p(citrus_wedge("#f0a07a", "#fbe6d6", "#e8695f"), 17, 4)}
V["kiwi"] = {"slices": p('<circle cx="8" cy="8" r="7" fill="#8a6a3a"/><circle cx="8" cy="8" r="6.2" fill="#7fb03a"/><circle cx="8" cy="8" r="2.2" fill="#eef3d6"/>' + "".join(f'<circle cx="{f(8 + 3.2 * math.cos(math.tau * i / 10))}" cy="{f(8 + 3.2 * math.sin(math.tau * i / 10))}" r="0.5" fill="#2a2a2a"/>' for i in range(10)), 13, 4)}
V["lemon"] = {"wedges": p(citrus_wedge("#f1c21b", "#fbf2cc", "#f6dc5c"), 17, 3), "wheels": p(citrus_wheel("#f1c21b", "#fbf2cc", "#f6dc5c"), 13, 3), "zest": garnish(shreds("#f1c21b"), 8, 4)}
V["lime"] = {"wedges": p(citrus_wedge("#5f9a45", "#e8efcf", "#a8cf6f"), 17, 3), "wheels": p(citrus_wheel("#5f9a45", "#e8efcf", "#a8cf6f"), 13, 3)}
V["mango"] = {"cubes": p(dice("#f6a63a", "#fbc46a"), 10, 7), "slices": p(crescent("#e88a2a", "#fbc46a"), 14, 4)}
V["melon"] = {"cubes": p(dice("#c9dc8a", "#e2edb8"), 11, 6)}
V["orange"] = {"segments": p(citrus_wedge("#f08a2b", "#fbe6c8", "#f7a64a"), 17, 4), "wheels": p(citrus_wheel("#f08a2b", "#fbe6c8", "#f7a64a"), 13, 3)}
V["peach"] = {"slices": p(crescent("#e86a4a", "#f8c47a"), 14, 5)}
V["pear"] = {"slices": p(crescent("#b9c45a", "#f6f0d0"), 14, 5)}
V["persimmon"] = {"wedges": p(wedge("#e8762a", "#f6a64a"), 13, 5)}
V["pineapple"] = {"chunks": p(wedge("#e8b84a", "#f8dc7a"), 11, 6), "rings": p(ring("#f2c84a", "#f8e08a", 3.4), 15, 3)}
V["plum"] = {"slices": p(crescent("#6b2a4a", "#e8a05a"), 13, 5)}
V["pomegranate"] = {"seeds": garnish(cluster("#b8243a", "#e86a7a", 1.9), 9, 4)}
V["raspberry"] = {"berries": p(cluster("#d9435f", "#f08aa0", 2.2), 9, 6)}
V["strawberry"] = {"halves": p(heart_half("#d9364a", "#f6a6a6", "#f6e08a"), 13, 5)}
V["watermelon"] = {"cubes": p(dice("#e8505f", "#f6808a") + '<ellipse cx="10" cy="10" rx="0.9" ry="0.6" fill="#2a2a2a"/>', 11, 6)}
V["yuzu"] = {"zest": garnish(shreds("#f1c21b", "#f6dc5c"), 8, 4), "wheels": p(citrus_wheel("#e8b81b", "#fbf2cc", "#f6dc5c"), 12, 3)}

# Meat --------------------------------------------------------------------------------------

V["bacon"] = {"rashers": p(bacon("#b9503f", "#f2d6c4"), 17, 3), "lardons": p(cube("#c9604f", "#f2d6c4", "#f6e6d6"), 9, 7), "bits": garnish(crumble("#a8402f", "#d9705f"), 7, 8)}
V["beef"] = {"slices": p(meat_slice("#8a4a3a", "#c4826a"), 15, 5), "steak": center(steak_slices("#3f1f15", "#d4707a", "#6a3424"), 46), "cubes": p(chunk("#6f3a2a", "#9a5a42"), 12, 5)}
V["chicken"] = {"pieces": p(chunk("#d4975a", "#ecc184"), 12, 5), "cutlet": center(sliced_fan("#f6e6c8", "#c98a4b", "#d9963f"), 40), "grilled": center(fillet("#d9a56a", "#b9783f", "#c98a4b") + '<path d="M4 6l8 4M3.5 9.5l7 3.5" stroke="#8a5a2a" stroke-width="1" stroke-linecap="round"/>', 50)}
V["chorizo"] = {"coins": p(coin("#a8302a", "#c9483a", "#f2c4a8"), 11, 6), "diced": p(dice("#a8302a", "#d9604a"), 8, 8)}
V["corned-beef"] = {"chunks": p(crumble("#b8605a", "#d9887a"), 10, 6)}
V["duck"] = {"slices": p(meat_slice("#c4706a", "#6f3a22"), 15, 5)}
V["guanciale"] = {"cubes": p('<rect x="3" y="3" width="10" height="10" rx="2.5" fill="#d98a7a"/><rect x="3" y="3" width="10" height="3.4" rx="1.7" fill="#f6eedf"/>', 11, 7)}
V["ham"] = {"diced": p(dice("#e89a9a", "#f6c4c4"), 9, 7), "strips": p(strip("#e89a9a", "#f6c4c4"), 13, 5), "slices": p(coin("#e2908f", "#f2b0ae"), 15, 3)}
V["lamb"] = {"chunks": p(chunk("#8a4a32", "#b06a4a"), 12, 5), "slices": p(meat_slice("#a85a4a", "#f2d6c4", "#6f3a22"), 15, 4)}
V["liver"] = {"slices": p(chunk("#6a2a2a", "#8a4040"), 12, 5)}
V["luncheon-meat"] = {"slices": p('<rect x="1.5" y="4" width="13" height="8" rx="1.5" fill="#d98a7a"/><rect x="2.5" y="5" width="11" height="6" rx="1" fill="#eaa898"/><path d="M4 7h4" stroke="#f6c8b8" stroke-width="1" stroke-linecap="round"/>', 15, 3), "cubes": p(dice("#d98a7a", "#eaa898"), 10, 6)}
V["minced-meat"] = {"crumbled": p(mince("#8a5040", "#b07a5a"), 10, 7), "sauce": fl(lambda r: smooth(r, "#9a4a32", "#b8604a", specks="#6f3a22"), SAUCE)}
V["pancetta"] = {"cubes": p('<rect x="3" y="3" width="10" height="10" rx="2.5" fill="#d98a7a"/><rect x="3" y="3" width="10" height="3.4" rx="1.7" fill="#f6eedf"/>', 10, 7)}
V["pork"] = {"strips": p('<rect x="1" y="5" width="14" height="6" rx="3" fill="#c9805f"/><rect x="1" y="5" width="14" height="2.2" rx="1.1" fill="#f2ede0"/>', 14, 4), "slices": p(meat_slice("#c9805f", "#f2e6d6"), 15, 5), "cutlet": center(sliced_fan("#f6ead8", "#d9a05a", "#c98a3f"), 40), "simmered": fl(lambda r: covering_slices(r, '<path d="M1 6c4-2 10-2 14 0 1 2.4 1 5.4 0 7-4 2-10 2-14 0-1-1.6-1-4.6 0-7Z" fill="#b87650"/><path d="M1.6 7.2c4-1.4 9-1.4 12.8 0" stroke="#e8d3b8" stroke-width="1.4" fill="none" stroke-linecap="round"/>', 30), ANY, covers=True)}
V["prosciutto"] = {"ribbons": p(meat_slice("#d9707a", "#f6e6e0"), 15, 4)}
V["salami"] = {"coins": p(coin("#a83a42", "#c9505a", "#f2d6c8"), 12, 5)}
V["sausage"] = {"links": p(link("#a8603f", "#c98a5f"), 15, 3), "coins": p(coin("#9a5a3a", "#d4a088"), 11, 6)}
V["turkey"] = {"slices": p(meat_slice("#ead8bc", "#c9a07a"), 15, 4)}
V["veal"] = {"cutlet": center(sliced_fan("#f2e6d0", "#c9904b", "#d9a04f"), 40)}

# Seafood -----------------------------------------------------------------------------------

V["anchovies"] = {"fillets": p(stick("#8a6a5a", "#b8a090"), 13, 4)}
V["chikuwa"] = {"rings": p(ring("#c98a4b", "#f4ecd6", 3), 11, 6)}
V["clams"] = {"shells": p(clam("#d9cbb4", "#f2d6b0", "#b8a688"), 13, 5)}
V["cod"] = {"fillet": center(fillet("#f8f4ea", "#e6dfcc", "#c9c4b8"), 50)}
V["crab"] = {"flaked": p(shreds("#f6e6dc", "#e8735f"), 11, 6)}
V["crab-sticks"] = {"sticks": p(crab_stick("#e04a3a", "#fbf6ee"), 14, 4), "shredded": p(shreds("#fbf6ee", "#e04a3a"), 11, 6)}
V["eel"] = {"glazed": center('<rect x="1" y="3" width="14" height="10" rx="1.5" fill="#6a3a1f"/><rect x="2" y="4" width="12" height="8" rx="1" fill="#9a5a2a"/><path d="M4 5v6M8 5v6M12 5v6" stroke="#5a2f15" stroke-width="0.9"/>', 44)}
V["fish"] = {"fillet": center(fillet("#f6efe2", "#e2d6c0", "#b8b0a0"), 50)}
V["mackerel"] = {"fillet": center(fillet("#e6cdb0", "#c9a888", "#6f7f8f") + '<path d="M3 9c3-3 8-4.5 11-3.5" stroke="#9aaab8" stroke-width="1" fill="none"/>', 50)}
V["mentaiko"] = {"dollop": center(dollop("#f0848a", "#f8b8b8") + "".join(f'<circle cx="{x}" cy="{y}" r="0.5" fill="#d9505a"/>' for x, y in ((6, 10), (9, 9), (11, 11), (7, 12))), 14)}
V["mussels"] = {"shells": p(mussel("#2f3440", "#f2a65a"), 14, 5)}
V["octopus"] = {"slices": p(octopus("#c45a6a", "#f6e6e0", "#e8a0a8"), 12, 5)}
V["oyster"] = {"shells": p(clam("#b8b4aa", "#e8e2d0", "#8a8678"), 15, 4)}
V["salmon"] = {"fillet": center(fillet("#f6906a", "#fbc4a8", "#b8b0a8"), 50), "sashimi": p(strip("#f6906a", "#fbc4a8"), 15, 4), "flaked": p(crumble("#f6a080", "#fbc4a8"), 9, 7)}
V["salmon-roe"] = {"roe": p(cluster("#f2702a", "#fbb07a", 2.1), 10, 4)}
V["sardines"] = {"fillets": p(stick("#9aa6b0", "#d9c4b0"), 15, 3)}
V["scallops"] = {"seared": p(scallop("#f6ead8", "#d9a05a"), 13, 4)}
V["seafood"] = {"shrimp": p(shrimp("#fa7368", "#ffb0a4"), 15, 3), "squid": p(ring("#f6ecdf", "#fbf7f0", 2.6), 11, 3)}
V["shirasu"] = {"sprinkle": garnish(squiggles("#f2ead8", "#3a3a3a"), 15, 3)}
V["shrimp"] = {"whole": p(shrimp("#fa7368", "#ffb0a4"), 15, 4)}
V["squid"] = {"rings": p(ring("#f6ecdf", "#fbf7f0", 2.6), 11, 6)}
V["tuna"] = {"sashimi": p(strip("#c8374a", "#e0606e"), 15, 4), "cubes": p(dice("#c8374a", "#e0606e"), 10, 7), "flaked": p(crumble("#e8c4b0", "#f6dccf"), 9, 7)}
V["yellowtail"] = {"sashimi": p(strip("#f0c0b0", "#f8dcd2"), 15, 4)}

# Dairy and eggs ----------------------------------------------------------------------------

V["blue-cheese"] = {"crumbled": p(crumble("#ece4cc", "#5a7a98") + '<circle cx="9" cy="9" r="1" fill="#5a7a98"/><circle cx="6" cy="10" r="0.8" fill="#5a7a98"/>', 11, 6)}
V["burrata"] = {"whole": center('<circle cx="8" cy="8" r="7" fill="#f8f6ef"/><path d="M5 8c1-3 5-3 6 0s-2 4-3 3-3 0-3-3Z" fill="#fbf2d8"/><circle cx="6" cy="5.5" r="1.4" fill="#ffffff"/>', 34)}
V["butter"] = {"pat": center('<rect x="2" y="2" width="12" height="12" rx="2.5" fill="#f1c21b"/><rect x="3.5" y="3.5" width="9" height="8" rx="2" fill="#ffe97a"/>', 24)}
V["cheddar"] = {"grated": garnish(shreds("#f2a63a", "#f8c46a"), 9, 6), "melted": fl(lambda r: melted(r, "#f6b84a", "#fbd88a", "#d98a2a"), ANY, covers=True)}
V["cheese"] = {"grated": garnish(shreds("#f6dc7a", "#fbe9a8"), 9, 6), "melted": fl(lambda r: melted(r, "#f8d86a", "#fbeaa0", "#e0a83a"), ANY, covers=True), "slice": center('<rect x="2" y="2" width="12" height="12" rx="1" fill="#f6d45a"/><circle cx="6" cy="6" r="1.2" fill="#e8c040"/><circle cx="10.5" cy="9.5" r="1" fill="#e8c040"/>', 26)}
V["condensed-milk"] = {"drizzle": center(drizzle("#f6ecd6", 2.2), 24, 2)}
V["cream"] = {"swirl": center(dollop("#fbf9f4", "#ece6d6"), 22), "sauce": fl(lambda r: smooth(r, "#f6efdc", "#fbf9f0"), SAUCE)}
V["cream-cheese"] = {"dollop": center(dollop("#f8f6ef", "#e6e0d4"), 22)}
V["creme-fraiche"] = {"dollop": center(dollop("#fbf8ef", "#e8e0cc"), 22)}
V["egg"] = {"fried": center(egg_fried(), 42), "scrambled": p(egg_scrambled(), 15, 6), "boiled": center(egg_half("#fbf9f4", "#f1c21b", "#ffe97a"), 24, 2), "yolk": center(yolk("#f6b21b", "#ffd86a"), 22), "omelette": fl(lambda r: omelette(r, "#f6d55c", "#ffe97a", "#e8bc3a"), PLATES)}
V["feta"] = {"crumbled": p(cube("#fbfaf4", "#ffffff", "#e6e0d0"), 8, 8)}
V["goat-cheese"] = {"crumbled": p(crumble("#fbfaf6", "#e6e2d6"), 9, 6)}
V["gruyere"] = {"grated": garnish(shreds("#f2dc9a", "#f8ecc4"), 9, 6), "melted": fl(lambda r: melted(r, "#f2d48a", "#f8e8b8", "#c98a3a"), ANY, covers=True)}
V["halloumi"] = {"grilled": p('<rect x="1.5" y="3" width="13" height="10" rx="2" fill="#f4ecd6"/><path d="M4 4l-1.5 8M8 4l-1.5 8M12 4l-1.5 8" stroke="#a8743a" stroke-width="1.2" stroke-linecap="round"/>', 15, 3)}
V["mascarpone"] = {"dollop": center(dollop("#fbf6e6", "#ece2c8"), 22)}
V["mozzarella"] = {"slices": p(round_slice("#f6f2e6", "#fbfaf4"), 14, 4), "torn": p(crumble("#fbfaf4", "#ece6d8"), 12, 5), "melted": fl(lambda r: melted(r, "#fbf6e0", "#ffffff", "#e8c88a"), ANY, covers=True)}
V["paneer"] = {"cubes": p(cube("#f8f2e0", "#ffffff", "#d9a85c"), 10, 7)}
V["parmesan"] = {"grated": garnish(shred("#fbf2d0", 2), 8, 8), "shaved": p(flake("#f6e6b0", "#fbf2d0"), 11, 5)}
V["pecorino"] = {"grated": garnish('<path d="M4 9c3-3 6-3 8-1" stroke="#fdf6dc" stroke-width="2" fill="none" stroke-linecap="round"/>', 9, 8), "shaved": p(flake("#f8ecc4", "#fdf6dc"), 11, 5)}
V["ricotta"] = {"dollop": center(dollop("#fbfaf4", "#e8e4d8"), 22)}
V["sour-cream"] = {"dollop": center(dollop("#fbfaf6", "#e6e2d8"), 22)}
V["yogurt"] = {"dollop": center(dollop("#fbfaf6", "#e6e2d8"), 22), "bowl": fl(lambda r: smooth(r, "#fbfaf6", "#ffffff", full=True, ridges="#ece8de"), BOWLS)}

# Grains, noodles, and bread ----------------------------------------------------------------

V["arborio-rice"] = {"risotto": fl(lambda r: grains_in(r, "#f2e6c4", "#e2d2a0", 60, 2.6, 1.5, shape="full"), PLATES + BOWLS + ["pan"])}
V["barley"] = {"mound": fl(lambda r: grains_in(r, "#e2cfa0", "#c9b07a", 80, 1.8, 1.4), MOUND), "bowl": fl(lambda r: grains_in(r, "#e2cfa0", "#c9b07a", 90, 1.8, 1.4, shape="full"), BOWLS)}
V["bread"] = {"toast": fl(lambda r: slice_of_bread("#ecc078", "#b8874a", extra='<path d="M-14 -12h28v26h-28Z" fill="#f3d38e" opacity="0.6"/>'), FLAT), "french-toast": fl(lambda r: slice_of_bread("#d99a4a", "#9c6430", 2, '<path d="M-12 -10c6 4 14-2 22 2M-14 4c8 3 14-3 24 1" stroke="#b97a35" stroke-width="3" fill="none" stroke-linecap="round"/>'), FLAT), "slice": fl(lambda r: slice_of_bread("#f3dfae", "#c9a15f"), FLAT), "croutons": p(cube("#e8b860", "#f6d88a", "#c98a3a"), 9, 7)}
V["breadcrumbs"] = {"toasted": garnish(dust("#c98a3a", "#e8b860"), 10, 4)}
V["couscous"] = {"mound": fl(lambda r: grains_in(r, "#f2dc9a", "#e2c47a", 120, 1, 0.9), MOUND), "bowl": fl(lambda r: grains_in(r, "#f2dc9a", "#e2c47a", 140, 1, 0.9, shape="full"), BOWLS)}
V["egg-noodles"] = {"swirl": fl(lambda r: noodles(r, "#f2c85a", "#f8dc8a", "#e8b84a", 2.2), ANY), "broth": fl(lambda r: noodles(r, "#f2c85a", "#f8dc8a", "#e8b84a", 2.2, broth="#e8c48a"), BOWLS)}
V["fettuccine"] = {"swirl": fl(lambda r: noodles(r, "#f2d68a", "#fbeab5", "#e8c46e", 4, 18), PLATES + ["pan"])}
V["fusilli"] = {"pasta": fl(lambda r: tiled(r, spiral("#f2d27a", "#fbe6a8"), 17, 14, base="#e2b85a"), PLATES + BOWLS + ["pan"])}
V["glutinous-rice"] = {"mound": fl(lambda r: grains_in(r, "#fbf9f4", "#ece6da", 60, 2.6, 1.6), MOUND), "bowl": fl(lambda r: grains_in(r, "#fbf9f4", "#ece6da", 70, 2.6, 1.6, shape="full"), BOWLS)}
V["gnocchi"] = {"pasta": fl(lambda r: tiled(r, pillow("#f2dca0", "#d9b46a"), 16, 13, base="#e2c47a"), PLATES + ["pan"]), "pieces": p(pillow("#f2dca0", "#e2c47a"), 12, 6)}
V["gyoza-wrappers"] = {"dumplings": fl(lambda r: row_of(r, dumpling("#f6ecd6", "#d9c8a8", "#c98a3a"), 26, 3), PLATES + ["pan"]), "pieces": p(dumpling("#f6ecd6", "#d9c8a8", "#c98a3a"), 16, 4)}
V["harusame"] = {"noodles": fl(lambda r: noodles(r, "#eef0f0", "#ffffff", "#dfe4e4", 1.4, 34), ANY)}
V["lasagna"] = {"square": fl(lambda r: layered_square(r, "#f6dc8a", "#d9533f", "#c98a3a"), PLATES + ["pan"])}
V["macaroni"] = {"pasta": fl(lambda r: tiled(r, elbow("#f6d36a", "#fbe6a8"), 15, 16, base="#e8b84a"), PLATES + BOWLS + ["pan"])}
V["mochi"] = {"pieces": p(mochi("#fbfaf6", "#ffffff"), 13, 4)}
V["noodles"] = {"swirl": fl(lambda r: noodles(r, "#f2d68a", "#fbeab5", "#e8c46e", 2.4), ANY), "broth": fl(lambda r: noodles(r, "#f2d68a", "#fbeab5", "#e8c46e", 2.4, broth="#d9a86a"), BOWLS)}
V["oats"] = {"porridge": fl(lambda r: grains_in(r, "#efe2c4", "#dcc89c", 60, 2.2, 1.6, shape="full"), BOWLS)}
V["orzo"] = {"pasta": fl(lambda r: grains_in(r, "#f2dc9a", "#e2c47a", 90, 2, 1.1), PLATES + BOWLS + ["pan"])}
V["panko"] = {"crumbs": garnish(dust("#e8c47a", "#f6dca0"), 10, 4)}
V["penne"] = {"pasta": fl(lambda r: tiled(r, tube("#f2d27a", "#d9a84a"), 18, 13, base="#e2b85a"), PLATES + BOWLS + ["pan"])}
V["pita"] = {"bread": fl(lambda r: flatbread(r, "#f2d8a0", "#d9a85c", "#e2bc7a", oval=True), FLAT), "wedges": p(triangle("#e8c47a", "#f6dca0"), 14, 4)}
V["polenta"] = {"soft": fl(lambda r: smooth(r, "#f6cf5a", "#fbe08a"), PLATES + BOWLS)}
V["quinoa"] = {"mound": fl(lambda r: grains_in(r, "#efe2c4", "#c9a888", 140, 1.1, 1), MOUND), "bowl": fl(lambda r: grains_in(r, "#efe2c4", "#c9a888", 150, 1.1, 1, shape="full"), BOWLS)}
V["ramen"] = {"broth": fl(lambda r: noodles(r, "#f2d27a", "#fbe6a8", "#e8c46e", 2, 30, broth="#e2b878"), BOWLS), "swirl": fl(lambda r: noodles(r, "#f2d27a", "#fbe6a8", "#e8c46e", 2, 30), PLATES + ["pan"])}
V["ravioli"] = {"pasta": fl(lambda r: tiled(r, ravioli("#f6dc8a", "#fbecbc", "#e8c46e"), 15, 10), PLATES + BOWLS + ["pan"]), "pieces": p(ravioli("#f6dc8a", "#fbecbc", "#e8c46e"), 14, 4)}
V["rice"] = {"mound": fl(lambda r: grains_in(r, "#fbf8f0", "#ebe5d6", 48), MOUND), "bowl": fl(lambda r: grains_in(r, "#fbf8f0", "#ebe5d6", 60, shape="full"), BOWLS), "fried": fl(lambda r: grains_in(r, "#f2d796", "#e0bb6c", 48), MOUND + BOWLS), "red-fried": fl(lambda r: grains_in(r, "#e8946b", "#d0704b", 48), MOUND + BOWLS)}
V["rice-noodles"] = {"swirl": fl(lambda r: noodles(r, "#f6f2e6", "#ffffff", "#e6e0d0", 3.4, 22), ANY), "broth": fl(lambda r: noodles(r, "#f6f2e6", "#ffffff", "#e6e0d0", 3.4, 22, broth="#e8d9b0"), BOWLS)}
V["rice-paper"] = {"rolls": fl(lambda r: rolls(r, "#f4efe4", "#ffffff", "#e8735f"), FLAT)}
V["rigatoni"] = {"pasta": fl(lambda r: tiled(r, tube("#f2d27a", "#d9a84a", True), 20, 10, base="#e2b85a"), PLATES + BOWLS + ["pan"])}
V["soba"] = {"swirl": fl(lambda r: noodles(r, "#9a8a72", "#b8a88e", "#857560", 1.6, 34), PLATES + BOWLS), "broth": fl(lambda r: noodles(r, "#9a8a72", "#b8a88e", "#857560", 1.6, 34, broth="#9a6a3a"), BOWLS)}
V["somen"] = {"swirl": fl(lambda r: noodles(r, "#fbf9f2", "#ffffff", "#ece8dc", 1.2, 40), PLATES + BOWLS)}
V["spaghetti"] = {"plain": fl(lambda r: noodles(r, "#efd281", "#fbeab5", "#e8c46e"), PLATES + ["pan"]), "creamy": fl(lambda r: noodles(r, "#efd281", "#fbeab5", "#f6e3a8"), PLATES + ["pan"]), "tomato": fl(lambda r: noodles(r, "#e2694f", "#f08a6a", "#d9533f"), PLATES + ["pan"])}
V["tortilla"] = {"flat": fl(lambda r: flatbread(r, "#f2dca8", "#d9b070", "#e8c88a"), FLAT), "chips": p(triangle("#f2c85a", "#f8dc8a"), 13, 6)}
V["udon"] = {"broth": fl(lambda r: noodles(r, "#fbf6e6", "#ffffff", "#ece4cc", 4.2, 16, broth="#c99a5a"), BOWLS), "swirl": fl(lambda r: noodles(r, "#fbf6e6", "#ffffff", "#ece4cc", 4.2, 16), PLATES + ["pan"])}
V["wonton-wrappers"] = {"wontons": p(dumpling("#f6f0e0", "#e2d8c0"), 15, 4)}

# Seasonings --------------------------------------------------------------------------------

V["basil"] = {"leaves": garnish(leaf("#4f8f3a", "#7fb069"), 12, 4)}
V["cayenne"] = {"dusting": garnish(dust("#d9533f"), 10, 2)}
V["chili-flakes"] = {"flakes": garnish(dust("#c9402f", "#f2c46a"), 10, 3)}
V["cinnamon"] = {"dusting": garnish(dust("#8a5a32"), 10, 3)}
V["coriander"] = {"leaves": garnish(torn_leaf("#5f9a45", "#a8cf8e"), 7, 7)}
V["dill"] = {"fronds": garnish(needles("#6aa04f"), 9, 5)}
V["furikake"] = {"sprinkle": garnish(dust("#2f4a3a", "#e8d6a0"), 10, 4)}
V["gochugaru"] = {"flakes": garnish(dust("#d9402f", "#e8704a"), 10, 3)}
V["kaffir-lime-leaves"] = {"slivers": garnish(shred("#3f6b3a", 2.6), 10, 5)}
V["mint"] = {"leaves": garnish(leaf("#5fa05a", "#a8d89a"), 11, 4)}
V["mustard-seeds"] = {"seeds": garnish(dust("#c9a03a", "#8a6a2a"), 9, 3)}
V["oregano"] = {"flecks": garnish(fleck("#5f7f3a"), 4, 12)}
V["paprika"] = {"dusting": garnish(dust("#d9603a"), 10, 3)}
V["parsley"] = {"chopped": garnish(fleck("#5f9a45"), 5, 12), "sprig": garnish(sprig("#4f8a3a"), 12, 2)}
V["pepper"] = {"cracked": garnish('<circle cx="8" cy="8" r="1.6" fill="#3a3632"/>', 4, 14)}
V["rosemary"] = {"sprig": garnish(needles("#4f6f45"), 14, 2)}
V["sage"] = {"leaves": garnish(leaf("#7f9a7a", "#b8c8b0"), 12, 3)}
V["sesame-seeds"] = {"sprinkle": garnish('<ellipse cx="8" cy="8" rx="2.4" ry="1.4" fill="#e8d4a4"/><ellipse cx="7.4" cy="7.6" rx="1.2" ry="0.6" fill="#f8eed8"/>', 6, 10), "black": garnish('<ellipse cx="8" cy="8" rx="2.4" ry="1.4" fill="#2a2a2a"/>', 6, 10)}
V["shichimi"] = {"sprinkle": garnish(dust("#d9533f", "#2a2a2a"), 10, 2)}
V["sichuan-peppercorns"] = {"cracked": garnish(dust("#8a3a2a", "#c9604a"), 9, 3)}
V["star-anise"] = {"whole": p('<path d="' + "".join(f'M8 8L{f(8 + 6.5 * math.cos(math.tau * i / 8))} {f(8 + 6.5 * math.sin(math.tau * i / 8))}' for i in range(8)) + '" stroke="#7a3f22" stroke-width="2.6" stroke-linecap="round"/><circle cx="8" cy="8" r="1.4" fill="#a85a32"/>', 12, 2)}
V["tarragon"] = {"leaves": garnish(julienne("#6a9a4a"), 7, 8)}
V["thai-basil"] = {"leaves": garnish(leaf("#3f7f3a", "#8a4a7a"), 12, 4)}
V["thyme"] = {"sprigs": garnish(sprig("#5f7f4a", "#8a7a5a"), 13, 3)}
V["wasabi"] = {"dollop": center(dollop("#9cc45a", "#c4e08a"), 22)}
V["yuzu-kosho"] = {"dollop": center(dollop("#b8c84a", "#dce88a"), 22)}

# Sauces and condiments ---------------------------------------------------------------------

V["balsamic-vinegar"] = {"drizzle": center(drizzle("#3a1f1a", 1.6), 24, 2)}
V["olive-oil"] = {"drizzle": center(drizzle("#c9b43a", 1.8), 24, 2)}
V["pesto"] = {"dollop": center(dollop("#5f8f3a", "#8ab55a"), 22), "sauce": fl(lambda r: smooth(r, "#6a9a3f", "#8ab55a", specks="#3f6b2a"), PLATES + ["pan"])}
V["chili-oil"] = {"drizzle": center(drizzle("#c9301f", 2.4) + '<circle cx="5" cy="9" r="0.8" fill="#6a1f15"/><circle cx="11" cy="7" r="0.8" fill="#6a1f15"/>', 24, 2)}
V["douchi"] = {"beans": garnish(cluster("#2a2422", "#5a4a42", 1.6, 5), 7, 4)}
V["hoisin"] = {"drizzle": center(drizzle("#5a2a1f", 2), 24, 2)}
V["plum-sauce"] = {"dollop": center(dollop("#c9603a", "#e8905a"), 22)}
V["tianmianjiang"] = {"sauce": fl(lambda r: smooth(r, "#4a2a1a", "#6f4430"), SAUCE)}
V["xo-sauce"] = {"dollop": center(dollop("#a8402a", "#d9704a") + '<circle cx="7" cy="10" r="1" fill="#6a2a1a"/>', 22)}
V["dashi"] = {"broth": fl(lambda r: soup(r, "#e8d6a0", "#f6e8c4"), BOWLS)}
V["miso"] = {"soup": fl(lambda r: soup(r, "#d9b06a", "#e8c88a", "#c4954a"), BOWLS), "glaze": center(dollop("#c9903a", "#e2b060"), 22)}
V["okonomiyaki-sauce"] = {"drizzle": center(zigzag("#4a2a1a"), 26, 1)}
V["sesame-dressing"] = {"drizzle": center(drizzle("#e8d6a8", 2.2), 24, 2)}
V["teriyaki-sauce"] = {"glaze": center(drizzle("#6a3a1a", 2.6), 24, 2)}
V["tonkatsu-sauce"] = {"drizzle": center(zigzag("#3a1f15"), 24, 1)}
V["yakisoba-sauce"] = {"noodles": fl(lambda r: noodles(r, "#b8743a", "#d4955a", "#9a5a2a", 2.2, 28), PLATES + ["pan"])}
V["doenjang"] = {"stew": fl(lambda r: soup(r, "#b8864a", "#d4a46a", "#8a5a2a"), BOWLS)}
V["gochujang"] = {"dollop": center(dollop("#c9302a", "#e8604a"), 22), "sauce": fl(lambda r: smooth(r, "#c9402f", "#e8604a"), SAUCE)}
V["kecap-manis"] = {"drizzle": center(drizzle("#2a1a15", 2), 24, 2)}
V["sambal"] = {"dollop": center(dollop("#c9301f", "#e8603a") + '<circle cx="9" cy="10" r="0.8" fill="#f2c46a"/>', 22)}
V["sriracha"] = {"drizzle": center(zigzag("#d9301f"), 22, 1)}
V["sweet-chili-sauce"] = {"drizzle": center(drizzle("#e8603a", 2.2) + '<circle cx="5" cy="8" r="0.7" fill="#b8201a"/>', 24, 2)}
V["bbq-sauce"] = {"drizzle": center(drizzle("#6a2a1a", 2.6), 24, 2)}
V["honey"] = {"drizzle": center('<path d="M1 8c3-4 5 4 7 0s5-4 7 0" stroke="#e9a826" stroke-width="2" fill="none" stroke-linecap="round" opacity="0.9"/>', 24, 2)}
V["hot-sauce"] = {"drizzle": center(drizzle("#d9301f", 1.8), 22, 2)}
V["ketchup"] = {"drizzle": center(zigzag("#c9201f"), 22, 1)}
V["maple-syrup"] = {"drizzle": center('<path d="M1 8c3-4 5 4 7 0s5-4 7 0" stroke="#a5531c" stroke-width="2.2" fill="none" stroke-linecap="round" opacity="0.85"/>', 26, 2)}
V["mayonnaise"] = {"drizzle": center(zigzag("#fbf6dc"), 24, 1), "dollop": center(dollop("#fbf2cc", "#ffffff"), 22)}
V["mustard"] = {"drizzle": center(zigzag("#e8b81b"), 22, 1), "dollop": center(dollop("#d9a81b", "#f2c84a"), 22)}
V["tahini"] = {"drizzle": center(drizzle("#d9c08a", 2.2), 24, 2)}

# Baking and sweet --------------------------------------------------------------------------

V["anko"] = {"dollop": center(dollop("#5a2a2a", "#7a3f3a") + '<circle cx="7" cy="9" r="0.8" fill="#3a1a1a"/><circle cx="10" cy="10" r="0.8" fill="#3a1a1a"/>', 24)}
V["chocolate"] = {"shavings": garnish(flake("#5a3422", "#7a4a32"), 8, 5), "sauce": center(drizzle("#4a2a1a", 2.4), 24, 2)}
V["cocoa-powder"] = {"dusting": garnish(dust("#6a4030"), 10, 3)}
V["coconut-flakes"] = {"flakes": garnish(flake("#fbf9f4", "#e6e0d4"), 9, 6)}
V["golden-syrup"] = {"drizzle": center(drizzle("#e8a82a", 2), 24, 2)}
V["icing-sugar"] = {"dusting": garnish(dust("#ffffff"), 10, 4)}
V["jam"] = {"dollop": center(dollop("#b8243a", "#e05a6a"), 22)}
V["kinako"] = {"dusting": garnish(dust("#d9b878", "#e8cc98"), 10, 4)}
V["peanut-butter"] = {"dollop": center(dollop("#c98a4a", "#e2ac6a"), 22), "drizzle": center(drizzle("#c98a4a", 2.4), 24, 2)}
V["puff-pastry"] = {"square": fl(lambda r: place(pastry_square("#d99a3f", "#f2c46a", "#e8b056"), C, C, 52), FLAT), "pieces": p(pastry_square("#d99a3f", "#f2c46a", "#e8b056"), 16, 3)}
V["raisins"] = {"raisins": garnish(cluster("#4a2a2a", "#6a4040", 1.8, 5), 8, 4)}
V["shiratamako"] = {"dumplings": p(small_round("#fbfaf6", "#ffffff"), 11, 5)}
V["sugar"] = {"dusting": garnish('<circle cx="8" cy="8" r="1.4" fill="#ffffff" opacity="0.95"/>', 4, 14)}

# Preserved and dried -----------------------------------------------------------------------

V["aburaage"] = {"strips": p(strip("#c98a3f", "#e8b46a"), 13, 5), "triangles": p(triangle("#c98a3f", "#e8b46a"), 14, 4)}
V["almonds"] = {"slivered": garnish(teardrop("#e8d2a0", "#c9a870"), 8, 7), "whole": p(teardrop("#a8683a", "#c98a5a"), 9, 6)}
V["aonori"] = {"sprinkle": garnish(dust("#3f7a2a", "#5f9a45"), 13, 4)}
V["azuki"] = {"beans": p(cluster("#7a2a2a", "#a84a4a", 1.8, 6), 9, 5)}
V["beans"] = {"beans": p(bean("#dcc496", "#f2e2c0"), 9, 7), "stewed": fl(lambda r: tiled(r, bean("#c96a3a", "#e08a5a"), 8, 40, base="#b8502f"), SAUCE)}
V["black-beans"] = {"beans": p(bean("#2a2428", "#4a424a"), 7, 9)}
V["canned-tomatoes"] = {"sauce": fl(lambda r: smooth(r, "#c9402f", "#e8604a", specks="#a8301f"), SAUCE), "chunks": p(chunk("#c9402f", "#e8604a"), 10, 6)}
V["capers"] = {"capers": garnish(small_round("#6f7f3a", "#9aa85a"), 5, 8)}
V["chickpeas"] = {"chickpeas": p('<circle cx="8" cy="8" r="4.6" fill="#d9a660"/><path d="M8 3.6c-1 1.4-1 2.8 0 4" stroke="#b8803a" stroke-width="1" fill="none" stroke-linecap="round"/><circle cx="6.6" cy="7" r="1.2" fill="#f2d4a0"/>', 10, 7)}
V["coconut-milk"] = {"curry": fl(lambda r: smooth(r, "#f2e2b0", "#fbf2d8"), SAUCE), "drizzle": center(drizzle("#fbf8ef", 2.4), 24, 2)}
V["curry-roux"] = {"sauce": fl(lambda r: smooth(r, "#a4693a", "#c98a4b"), SAUCE)}
V["dried-shiitake"] = {"caps": p(mushroom_cap("#6f4a2f", "#c9a07a", "#5a3a22"), 12, 4)}
V["hijiki"] = {"strands": garnish(short_strokes("#1f1f1f"), 10, 4)}
V["kamaboko"] = {"slices": p(half_moon("#f08aa0", "#fbf8f2"), 13, 4)}
V["katsuobushi"] = {"flakes": garnish(flake("#dca088", "#f2cdb8"), 12, 6)}
V["kidney-beans"] = {"beans": p(bean("#8a2a2a", "#b04a4a"), 8, 8)}
V["kiriboshi-daikon"] = {"strands": p(shreds("#d9c49a", "#e8d6b0"), 11, 6)}
V["kombu"] = {"strips": p(julienne("#2f3a2a", "#4a5a3a"), 11, 5)}
V["konnyaku"] = {"cubes": p(cube("#8a8580", "#a8a49e", "#6f6a66") + "".join(f'<circle cx="{x}" cy="{y}" r="0.5" fill="#4a4642"/>' for x, y in ((6, 9), (10, 7), (9, 11))), 10, 6)}
V["koya-dofu"] = {"cubes": p(cube("#ecdcb8", "#f6ead0", "#d9c49a"), 11, 5)}
V["lentils"] = {"dal": fl(lambda r: smooth(r, "#e2a83a", "#f2c45a", specks="#c98a2a"), SAUCE), "lentils": p(cluster("#a8683a", "#c98a5a", 1.8), 8, 5)}
V["matcha"] = {"dusting": garnish(dust("#7fa83a"), 10, 3)}
V["menma"] = {"strips": p(strip("#c99a5a", "#e2bc7a"), 13, 4)}
V["natto"] = {"dollop": center(cluster("#b8864a", "#d9a86a", 1.9) + '<path d="M3 4c3 1 7 1 10 0M3 12c3-1 7-1 10 0" stroke="#f2e6d0" stroke-width="0.5" fill="none"/>', 26)}
V["nori"] = {"strips": garnish('<rect x="7" y="1" width="2" height="14" rx="1" fill="#1f3a33"/>', 11, 6), "sheet": center(sheet_square("#1f3a33", "#2c5148"), 30)}
V["nuts"] = {"chopped": garnish(crumble("#a8743a", "#d9a86a"), 9, 7)}
V["olives"] = {"rings": p(olive_ring("#3a3a2a", "#6a6a52"), 9, 6), "whole": p(berry("#5a6a2a", "#8a9a4a"), 10, 5)}
V["passata"] = {"sauce": fl(lambda r: smooth(r, "#d03f30", "#e8604a"), SAUCE)}
V["peanuts"] = {"crushed": garnish(crumble("#c98f4f", "#f2cc94"), 9, 7)}
V["pickled-ginger"] = {"slices": p(shreds("#f2a8a8", "#f8c8c8"), 11, 3)}
V["pine-nuts"] = {"toasted": garnish(teardrop("#f2d8a0", "#e2bc7a"), 5, 8)}
V["shirataki"] = {"noodles": fl(lambda r: noodles(r, "#e6e2da", "#f6f4ee", "#d4d0c6", 1.6, 30), ANY)}
V["sun-dried-tomatoes"] = {"strips": p(strip("#9a2a2a", "#c4483a"), 12, 5)}
V["takuan"] = {"slices": p(half_moon("#f2c81b", "#f8e05a"), 12, 4)}
V["tofu"] = {"cubes": p(cube("#fbf8ee", "#ffffff", "#e8e2d0"), 11, 6), "fried": p(cube("#f2dcb0", "#fbecd0", "#d99a4a"), 11, 6), "block": fl(lambda r: block(r, "#fbf8ee", "#ffffff", "#e8e2d0"), PLATES + BOWLS)}
V["umeboshi"] = {"whole": center('<circle cx="8" cy="8" r="5.6" fill="#c4304a"/><path d="M5 7c1-1 2-1 3 0M8 10c1 1 2 1 3 0" stroke="#e05a6a" stroke-width="1" fill="none" stroke-linecap="round"/>', 12)}
V["wakame"] = {"pieces": p(torn_leaf("#2f5a3a", "#4a7a52"), 12, 5)}
V["walnuts"] = {"halves": p(walnut("#b8864a", "#8a5a2a"), 11, 5)}
V["wheat-gluten"] = {"fu": p(ring("#f2dcb0", "#fbecd0", 3), 12, 3)}
V["zha-cai"] = {"strips": p(strip("#b8b064", "#d4cc88"), 11, 5)}

HIDDEN = {
    # Cooked into the dish or taken out before serving.
    "bay-leaf": "taken out before serving",
    "cardamom": "taken out before serving",
    "cloves": "taken out before serving",
    "lemongrass": "taken out before serving",
    # Ground spices and powders colour the dish rather than sit on it.
    "cumin": "ground into the dish", "curry-powder": "ground into the dish", "fennel-seeds": "ground into the dish",
    "five-spice": "ground into the dish", "garam-masala": "ground into the dish", "garlic-powder": "ground into the dish",
    "msg": "dissolved", "nutmeg": "ground into the dish", "onion-powder": "ground into the dish",
    "saffron": "colours the rice", "salt": "dissolved", "sansho": "ground into the dish", "turmeric": "colours the dish",
    # Liquids and seasonings that are absorbed.
    "red-wine": "cooked off", "white-wine": "cooked off", "black-vinegar": "absorbed", "char-siu-sauce": "absorbed",
    "dark-soy-sauce": "absorbed", "doubanjiang": "colours the sauce", "oyster-sauce": "absorbed", "sesame-oil": "absorbed",
    "shacha-sauce": "absorbed", "shaoxing-wine": "cooked off", "mentsuyu": "absorbed", "mirin": "absorbed",
    "ponzu": "absorbed", "rice-vinegar": "absorbed", "sake": "cooked off", "shiro-dashi": "absorbed",
    "soy-sauce": "absorbed", "yakiniku-sauce": "absorbed", "coconut-oil": "cooking fat", "fish-sauce": "absorbed",
    "tamarind": "absorbed", "apple-cider-vinegar": "absorbed", "beer": "cooked off", "oil": "cooking fat",
    "soy-milk": "absorbed", "vinegar": "absorbed", "water": "absorbed", "worcestershire": "absorbed",
    "buttermilk": "absorbed", "ghee": "cooking fat", "milk": "absorbed", "bouillon": "dissolved",
    "tomato-paste": "colours the sauce", "molasses": "absorbed", "vanilla": "absorbed",
    # Baking staples that become something else.
    "agar": "sets the dish", "almond-flour": "baked in", "baking-powder": "baked in", "baking-soda": "baked in",
    "bread-flour": "baked in", "brown-sugar": "dissolved", "cake-flour": "baked in", "cornmeal": "baked in",
    "cornstarch": "thickens the sauce", "flour": "baked in", "gelatin": "sets the dish", "rice-flour": "baked in",
    "yeast": "baked in",
}
