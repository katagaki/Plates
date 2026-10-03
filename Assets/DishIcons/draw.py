import math
import random

# The shapes every prepared part is drawn from. Pieces are drawn on a 16 x 16 canvas around
# (8, 8). Fills are drawn on a 64 x 64 canvas into the circle around (32, 32) of radius 30,
# which the layout scales onto whichever region of a vessel the fill lands in. Vessels are
# drawn on the 96 x 96 canvas the finished icon uses.

C, R = 32, 30


def f(x):
    return f"{x:.1f}".rstrip("0").rstrip(".")


def blob_path(rng, cx, cy, r, wobble=0.08, points=12):
    pts = []
    for i in range(points):
        a = math.tau * i / points
        rr = r * (1 + rng.uniform(-wobble, wobble))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = f"M{f(pts[0][0])} {f(pts[0][1])}"
    n = len(pts)
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}"
    return d + "Z"


def scatter_in_circle(rng, cx, cy, r, count, gap=0.0):
    out = []
    for _ in range(count * 6):
        if len(out) >= count:
            break
        a = rng.uniform(0, math.tau)
        d = r * math.sqrt(rng.random())
        x, y = cx + d * math.cos(a), cy + d * math.sin(a)
        if gap and any(math.hypot(x - ox, y - oy) < gap for ox, oy in out):
            continue
        out.append((x, y))
    return out


def place(svg, x, y, size, rot=0):
    return f'<g transform="translate({f(x)} {f(y)}) rotate({f(rot)}) scale({f(size / 16)}) translate(-8 -8)">{svg}</g>'


# Pieces ------------------------------------------------------------------------------------


def dice(m, l):
    return f'<rect x="2.5" y="2.5" width="11" height="11" rx="2.4" fill="{m}"/><rect x="4" y="4" width="5.5" height="4.4" rx="1.6" fill="{l}"/>'


def cube(m, l, edge=None):
    e = edge or m
    return f'<rect x="2.5" y="2.5" width="11" height="11" rx="1.6" fill="{e}"/><rect x="3.6" y="3.6" width="8.8" height="8.8" rx="1.2" fill="{m}"/><rect x="4.6" y="4.6" width="4" height="2" rx="1" fill="{l}"/>'


def chunk(m, l):
    return f'<path d="M2 6.5 7.5 2.5 14 5.5 13 12.5 5 14 1.5 10.5Z" fill="{m}"/><path d="M5 6l4.5-2" stroke="{l}" stroke-width="1.6" stroke-linecap="round"/>'


def round_slice(rind, flesh, core=None, seeds=None, rings=None):
    s = f'<circle cx="8" cy="8" r="7" fill="{rind}"/><circle cx="8" cy="8" r="5.6" fill="{flesh}"/>'
    if rings:
        s += f'<circle cx="8" cy="8" r="3.6" fill="none" stroke="{rings}" stroke-width="0.9"/>'
    if seeds:
        for i in range(6):
            a = math.tau * i / 6
            s += f'<ellipse cx="{f(8 + 3.2 * math.cos(a))}" cy="{f(8 + 3.2 * math.sin(a))}" rx="0.9" ry="0.6" fill="{seeds}" transform="rotate({f(math.degrees(a))} {f(8 + 3.2 * math.cos(a))} {f(8 + 3.2 * math.sin(a))})"/>'
    if core:
        s += f'<circle cx="8" cy="8" r="1.6" fill="{core}"/>'
    return s


def half_moon(rind, flesh, seeds=None):
    s = f'<path d="M1 11a7 7 0 0 1 14 0Z" fill="{rind}"/><path d="M2.4 11a5.6 5.6 0 0 1 11.2 0Z" fill="{flesh}"/>'
    if seeds:
        s += "".join(f'<circle cx="{x}" cy="9" r="0.7" fill="{seeds}"/>' for x in (5.5, 8, 10.5))
    return s


def wedge(skin, flesh, seeds=None):
    s = f'<path d="M2 13A10 10 0 0 1 14 2.5Z" fill="{skin}"/><path d="M4.4 11.4A7 7 0 0 1 11.8 5Z" fill="{flesh}"/>'
    if seeds:
        s += f'<circle cx="7.4" cy="8.6" r="0.8" fill="{seeds}"/><circle cx="9.4" cy="7.2" r="0.8" fill="{seeds}"/>'
    return s


def citrus_wheel(rind, pith, flesh):
    s = f'<circle cx="8" cy="8" r="7" fill="{rind}"/><circle cx="8" cy="8" r="6" fill="{pith}"/><circle cx="8" cy="8" r="5.2" fill="{flesh}"/>'
    s += "".join(
        f'<path d="M8 8L{f(8 + 5.2 * math.cos(math.tau * i / 8))} {f(8 + 5.2 * math.sin(math.tau * i / 8))}" stroke="{pith}" stroke-width="0.8"/>'
        for i in range(8)
    )
    return s


def citrus_wedge(rind, pith, flesh):
    return (
        f'<path d="M1 10a7 7 0 0 1 14 0Z" fill="{rind}"/><path d="M2.2 10a5.8 5.8 0 0 1 11.6 0Z" fill="{pith}"/>'
        f'<path d="M3 10a5 5 0 0 1 10 0Z" fill="{flesh}"/><path d="M8 10V5M8 10l-3.5-3.5M8 10l3.5-3.5" stroke="{pith}" stroke-width="0.8"/>'
    )


def strip(m, l):
    return f'<rect x="1" y="5.5" width="14" height="5" rx="2.5" fill="{m}"/><path d="M3.5 7h8" stroke="{l}" stroke-width="1.3" stroke-linecap="round"/>'


def julienne(m, l=None):
    s = f'<rect x="6.9" y="1" width="2.2" height="14" rx="1.1" fill="{m}"/>'
    if l:
        s += f'<rect x="4" y="2.5" width="2" height="11" rx="1" fill="{l}" transform="rotate(14 5 8)"/>'
    return s


def ring(m, l=None, width=2.2):
    s = f'<circle cx="8" cy="8" r="5.4" fill="none" stroke="{m}" stroke-width="{width}"/>'
    if l:
        s += f'<circle cx="8" cy="8" r="3.4" fill="none" stroke="{l}" stroke-width="1"/>'
    return s


def rings_small(m, l, core):
    return f'<circle cx="8" cy="8" r="4.6" fill="{l}"/><circle cx="8" cy="8" r="2.6" fill="{m}"/><circle cx="8" cy="8" r="1" fill="{core}"/>'


def leaf(m, v):
    return f'<path d="M1.5 10c3-7 10-8.5 13-6-2 7-9 9.5-13 6Z" fill="{m}"/><path d="M3.2 9.4 12.6 5" stroke="{v}" stroke-width="0.9" stroke-linecap="round"/>'


def torn_leaf(m, v):
    return f'<path d="M2 8c0-4 3-6 6-5.5 2-1.5 5 0 5.5 2.5 2 1.5 1.5 5-.5 6-1 2.5-4 3.5-6.5 2-3 .5-4.5-2-4.5-5Z" fill="{m}"/><path d="M4 11c2-2 5-4 8-6M8 8.5 7 5M10 7l2 2" stroke="{v}" stroke-width="0.8" fill="none" stroke-linecap="round"/>'


def fleck(m):
    return f'<path d="M3 10c1.5-5 6-7.5 10-5-1.5 5-6 7-10 5Z" fill="{m}"/>'


def sprig(m, stem=None):
    st = stem or m
    s = f'<path d="M3 13 13 3" stroke="{st}" stroke-width="1" stroke-linecap="round"/>'
    for t in (0.25, 0.45, 0.65, 0.85):
        x, y = 3 + 10 * t, 13 - 10 * t
        s += f'<ellipse cx="{f(x - 1.6)}" cy="{f(y - 1.6)}" rx="1.9" ry="0.9" fill="{m}" transform="rotate(-80 {f(x - 1.6)} {f(y - 1.6)})"/>'
        s += f'<ellipse cx="{f(x + 1.6)}" cy="{f(y + 1.6)}" rx="1.9" ry="0.9" fill="{m}" transform="rotate(-10 {f(x + 1.6)} {f(y + 1.6)})"/>'
    return s


def needles(m):
    s = f'<path d="M3 13 13 3" stroke="{m}" stroke-width="0.9" stroke-linecap="round"/>'
    for t in (0.2, 0.35, 0.5, 0.65, 0.8):
        x, y = 3 + 10 * t, 13 - 10 * t
        s += f'<path d="M{f(x)} {f(y)}l-3-1M{f(x)} {f(y)}l1 3" stroke="{m}" stroke-width="0.9" stroke-linecap="round"/>'
    return s


def floret(m, l, stem=None):
    s = ""
    if stem:
        s += f'<rect x="7" y="9" width="2.4" height="6" rx="1.2" fill="{stem}"/>'
    for x, y, r in ((5.5, 6.5, 3.2), (10.5, 6.5, 3.2), (8, 4.2, 3), (6.5, 10, 3), (10, 10, 2.8)):
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/>'
    for x, y in ((5, 5.6), (9.5, 5.4), (7.6, 3.2)):
        s += f'<circle cx="{x}" cy="{y}" r="1" fill="{l}"/>'
    return s


def dot(m, r=2.2):
    return f'<circle cx="8" cy="8" r="{r}" fill="{m}"/>'


def seed(m):
    return f'<ellipse cx="8" cy="8" rx="3.4" ry="2" fill="{m}"/>'


def dust(m, l=None):
    s = "".join(f'<circle cx="{x}" cy="{y}" r="1.7" fill="{m}"/>' for x, y in ((4, 4.5), (10, 3.5), (12.5, 9), (6.5, 9.5), (9.5, 13), (3.5, 12.5)))
    if l:
        s += "".join(f'<circle cx="{x}" cy="{y}" r="1.3" fill="{l}"/>' for x, y in ((8, 6.5), (13, 4.5), (2.8, 8.4)))
    return s


def shred(m, width=2.4):
    return f'<path d="M3 11c2-5 6-7 10-6" stroke="{m}" stroke-width="{width}" fill="none" stroke-linecap="round"/>'


def shreds(m, l=None):
    s = f'<path d="M2 5.5c4-2 8-2 12 0M3 10c3-1.5 7-1.5 11 1" stroke="{m}" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    if l:
        s += f'<path d="M4 13.5c3-1 6-1 8 0" stroke="{l}" stroke-width="2" fill="none" stroke-linecap="round"/>'
    return s


def flake(m, l):
    return f'<path d="M2 9c2-5 7-7 12-5-1 2-3 3-5 3 2 1 3 3 3 5-4 1-8 0-10-3Z" fill="{m}"/><path d="M5 8c2-1.5 4-2 6-2" stroke="{l}" stroke-width="1" fill="none" stroke-linecap="round"/>'


def meat_slice(m, fat, sear=None):
    s = f'<path d="M1.5 6c4-3 9-3 13 0 1 2 1 4 0 5-4 3-9 3-13 0-1-1.5-1-3.5 0-5Z" fill="{m}"/><path d="M2.5 6.2c4-2.4 7-2.4 11 0" stroke="{fat}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    if sear:
        s += f'<path d="M5 9.5h6" stroke="{sear}" stroke-width="1.2" stroke-linecap="round"/>'
    return s


def bacon(m, fat):
    return f'<path d="M1 6c2.5-2 4.5 2 7 0s4.5-2 7 0v4c-2.5-2-4.5 2-7 0s-4.5-2-7 0Z" fill="{m}"/><path d="M1 7.6c2.5-2 4.5 2 7 0s4.5-2 7 0" stroke="{fat}" stroke-width="1.2" fill="none"/>'


def mince(m, l):
    s = ""
    for x, y, r in ((5, 6, 2.6), (10, 5.5, 2.4), (7.5, 10, 2.8), (12, 10, 2), (3.8, 10.8, 1.8)):
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/>'
    return s + f'<circle cx="5" cy="5.4" r="0.9" fill="{l}"/><circle cx="7.6" cy="9.2" r="0.9" fill="{l}"/>'


def crumble(m, l):
    return f'<path d="M3 7 6 3.5l4 1 3 3-1 4.5-4.5 2-4-1.5Z" fill="{m}"/><path d="M5 7.5l2.5-2" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/>'


def berry(m, l, crown=None):
    s = f'<circle cx="8" cy="8.5" r="5.6" fill="{m}"/><circle cx="6.2" cy="6.6" r="1.6" fill="{l}"/>'
    if crown:
        s += f'<path d="M8 3.5l1.5-2M8 3.5l-1.5-2M8 3.5V1.5" stroke="{crown}" stroke-width="1.1" stroke-linecap="round"/>'
    return s


def small_round(m, l):
    return f'<circle cx="8" cy="8" r="4.2" fill="{m}"/><circle cx="6.8" cy="6.8" r="1.3" fill="{l}"/>'


def cluster(m, l, r=2.1, n=7):
    pts = [(8, 8), (8, 3.8), (11.7, 6), (11.7, 10), (8, 12.2), (4.3, 10), (4.3, 6)][:n]
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/><circle cx="{f(x - 0.6)}" cy="{f(y - 0.6)}" r="{f(r * 0.35)}" fill="{l}"/>' for x, y in pts)


def bean(m, l):
    return f'<path d="M3 9c-1-4 2-6.5 5-5.5 1 .3 2 .3 3 0 3-1 4.5 3 2.5 6-2 3-8 4-10.5-.5Z" fill="{m}"/><path d="M5 7c1-1 2-1.5 3.5-1" stroke="{l}" stroke-width="1.1" stroke-linecap="round" fill="none"/>'


def pod(m, l):
    return f'<path d="M1.5 10c2-6 9-8 13-6-1 6-8 9-13 6Z" fill="{m}"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="1.5" fill="{l}"/>' for x, y in ((5, 9), (8, 7.5), (11, 6)))


def spear(m, tip, l=None):
    s = f'<path d="M2.5 13.5 12 4" stroke="{m}" stroke-width="2.8" stroke-linecap="round"/><path d="M11 2.5c2 0 3 1.5 3 3l-2.5 1-1.5-1.5Z" fill="{tip}"/>'
    if l:
        s += f'<path d="M5 11l1.5 .5M8 8l1.5 .5" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/>'
    return s


def stick(m, l, end=None):
    s = f'<rect x="1" y="6" width="14" height="4" rx="2" fill="{m}"/><path d="M3 7.3h9" stroke="{l}" stroke-width="1" stroke-linecap="round"/>'
    if end:
        s += f'<circle cx="2.5" cy="8" r="1.4" fill="{end}"/>'
    return s


def drizzle(m, width=2.2):
    return f'<path d="M1 8c2.5-4 4.5 4 7 0s4.5-4 7 0" stroke="{m}" stroke-width="{width}" fill="none" stroke-linecap="round"/>'


def zigzag(m):
    """Sauce piped back and forth across the dish, thin enough not to read as a letter."""
    s = ""
    for i, y in enumerate((3, 6, 9, 12)):
        x0, x1 = (1.5, 14.5) if i % 2 == 0 else (14.5, 1.5)
        s += f'<path d="M{x0} {y}C{f((x0 + x1) / 2)} {y - 1.2} {f((x0 + x1) / 2)} {y + 1.2} {x1} {y + 0.4}" stroke="{m}" stroke-width="1.1" fill="none" stroke-linecap="round"/>'
    return s


def dollop(m, l):
    return f'<path d="M2.5 9c0-4 3-6.5 5.5-6.5S13.5 5 13.5 9 11 13.5 8 13.5 2.5 12.5 2.5 9Z" fill="{m}"/><path d="M5 8.5c1-2 4-2.5 5.5-.5" stroke="{l}" stroke-width="1.3" fill="none" stroke-linecap="round"/>'


def puddle(m, l):
    return f'<path d="M2 9c0-3.5 3-5.5 6-5 2-1 5 0 5.5 2.5 1.5 2 0 5-2 5.5-2 1.5-5 1.5-7 .5-2-.5-2.5-2-2.5-3.5Z" fill="{m}"/><ellipse cx="6.5" cy="7" rx="1.8" ry="1" fill="{l}"/>'


def shrimp(m, l):
    return f'<path d="M12 4a6 6 0 1 0 1 7l-3-1a3 3 0 1 1-1-4Z" fill="{m}"/><path d="M7 3.5l1 3M4 6l2.6 1.6M3.4 9.6l3-.4" stroke="{l}" stroke-width="1.1" stroke-linecap="round"/><path d="M12 4l2.5-1.5L13.5 5.5Z" fill="{m}"/>'


def clam(shell, meat, ridge):
    return f'<path d="M1.5 9a6.5 6 0 0 1 13 0c0 3-3 5-6.5 5S1.5 12 1.5 9Z" fill="{shell}"/><path d="M4 9.5a4 3.5 0 0 1 8 0c0 1.8-1.8 3-4 3s-4-1.2-4-3Z" fill="{meat}"/><path d="M3 6.5l1.5 1M13 6.5l-1.5 1M8 3v1.6" stroke="{ridge}" stroke-width="0.9" stroke-linecap="round"/>'


def mussel(shell, meat):
    return f'<path d="M3 13C1 9 4 2 9 1.5c4.5 0 5 5 3 8.5-2 3.5-6 5.5-9 3Z" fill="{shell}"/><path d="M5 11.5c-1-3 1.5-7 4.5-7.5 2.5 0 2.5 3 1 5.5-1.5 2.2-3.8 3-5.5 2Z" fill="{meat}"/>'


def scallop(m, sear):
    return f'<circle cx="8" cy="8" r="6" fill="{m}"/><circle cx="8" cy="8" r="4.2" fill="{sear}"/><circle cx="7" cy="7" r="1.4" fill="{m}" opacity="0.6"/>'


def octopus(m, l, sucker):
    return f'<path d="M2 8a6 5.5 0 0 1 12 0c0 3.3-2.7 5.5-6 5.5S2 11.3 2 8Z" fill="{m}"/><ellipse cx="8" cy="8.5" rx="4" ry="3.4" fill="{l}"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.9" fill="{sucker}"/>' for x, y in ((4, 11.5), (6.5, 13), (9.5, 13), (12, 11.5)))


def crab_stick(red, white):
    return f'<rect x="1" y="5" width="14" height="6" rx="2" fill="{white}"/><path d="M1.5 6.5h13" stroke="{red}" stroke-width="2.6" stroke-linecap="round"/>'


def squiggles(m, l):
    return f'<path d="M2 5c1.5-1 3 1 4.5 0M8 4c1.5-1 3 1 4.5 0M3 10c1.5-1 3 1 4.5 0M9 9.5c1.5-1 3 1 4.5 0M5 13.5c1.5-1 3 1 4.5 0" stroke="{m}" stroke-width="1.3" fill="none" stroke-linecap="round"/><circle cx="2" cy="5" r="0.6" fill="{l}"/><circle cx="8" cy="4" r="0.6" fill="{l}"/><circle cx="9" cy="9.5" r="0.6" fill="{l}"/>'


def fillet(m, l, skin):
    return f'<path d="M1 9c1-4 5-6.5 9-6.5s5 2.5 5 5.5-2 6-7 6-7.5-2-7-5Z" fill="{skin}"/><path d="M2.2 9c1-3.4 4.4-5.4 7.8-5.4s3.8 2 3.8 4.4-1.6 4.8-5.8 4.8-6.2-1.6-5.8-3.8Z" fill="{m}"/><path d="M5 6.5c1 2 1 4 0 5.5M8 5.2c1 2.5 1 5 0 7M11 5.2c.8 2 .8 4.5 0 6.5" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def sliced_fan(m, l, crust):
    s = ""
    for i, dx in enumerate((-4, 0, 4)):
        s += f'<rect x="{f(5.5 + dx)}" y="2" width="4.6" height="12" rx="1.4" fill="{crust}" transform="rotate({(i - 1) * 9} 8 8)"/>'
        s += f'<rect x="{f(6.3 + dx)}" y="3" width="3" height="10" rx="1" fill="{m}" transform="rotate({(i - 1) * 9} 8 8)"/>'
    return s + f'<path d="M4 6h1.2M8 5h1.2M12 6h1.2" stroke="{l}" stroke-width="0.8" stroke-linecap="round"/>'


def steak_slices(m, inner, crust):
    """A seared steak cut across one end, so the pink inside shows beside the crust."""
    return (
        f'<path d="M2 6c1-3 5-4.5 8-4 3 .5 5 2.5 4.5 5.5-.4 2-.2 3.5.5 4.5-1 2-4 2.5-7 2.5S1 13 1.5 10c.3-1.5 0-2.5.5-4Z" fill="{crust}"/>'
        f'<path d="M4 6.5l6-3M4.5 9.5l7-3.5M6 12l6-3" stroke="{m}" stroke-width="1" stroke-linecap="round"/>'
        f'<path d="M10.5 9.5c1.5-.3 3-.2 4 .5-.8 1.6-2.5 2.4-4.3 2.6Z" fill="{inner}"/>'
        f'<path d="M8.6 10.6c.8-.5 1.4-.8 2-1-.2 1.2-.2 2.2 0 3-.8.2-1.6.2-2.3.1Z" fill="{inner}"/>'
    )


def link(m, l):
    return f'<rect x="1" y="5" width="14" height="6" rx="3" fill="{m}"/><path d="M3.5 6.8h7" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/><path d="M5 11l1-1M9 11l1-1" stroke="{l}" stroke-width="0.8" stroke-linecap="round"/>'


def coin(m, l, spots=None):
    s = f'<circle cx="8" cy="8" r="6.4" fill="{m}"/><circle cx="8" cy="8" r="5" fill="{l}"/>'
    if spots:
        s += "".join(f'<circle cx="{x}" cy="{y}" r="0.9" fill="{spots}"/>' for x, y in ((6, 6.5), (10, 7), (7.5, 10.5), (10.5, 10)))
    return s


def egg_fried():
    return '<path d="M2 8c0-5 4-7 7-6s6 3 5 7-3 6-7 6-5-3-5-7Z" fill="#fbf9f4"/><circle cx="8" cy="8" r="3.4" fill="#f1c21b"/><circle cx="7" cy="7" r="1.2" fill="#ffe97a"/>'


def egg_scrambled():
    return '<path d="M3 8c0-4 4-6 7-5s4 4 3 7-5 4-7 3-3-2-3-5Z" fill="#f6d55c"/><circle cx="7" cy="7" r="2" fill="#ffe97a"/>'


def egg_half(white, yolk, l):
    return f'<ellipse cx="8" cy="8" rx="5.6" ry="7" fill="{white}"/><circle cx="8" cy="8.6" r="3.4" fill="{yolk}"/><circle cx="7.2" cy="7.8" r="1" fill="{l}"/>'


def yolk(m, l):
    return f'<circle cx="8" cy="8" r="5" fill="{m}"/><circle cx="6.6" cy="6.6" r="1.6" fill="{l}"/>'


def mushroom_slice(cap, flesh):
    return f'<path d="M2 8a6 5 0 0 1 12 0c0 1-1 1.5-2.5 1.5H10.5v4.5h-5V9.5H4C3 9.5 2 9 2 8Z" fill="{cap}"/><path d="M3.4 8a4.6 3.6 0 0 1 9.2 0H9.6v4.6H6.4V8Z" fill="{flesh}"/>'


def mushroom_cap(cap, mark, l=None):
    s = f'<circle cx="8" cy="8" r="6.4" fill="{cap}"/><path d="M5 5l6 6M11 5l-6 6" stroke="{mark}" stroke-width="1.4" stroke-linecap="round"/>'
    if l:
        s += f'<circle cx="8" cy="8" r="6.4" fill="none" stroke="{l}" stroke-width="0.8"/>'
    return s


def enoki(m, cap):
    s = ""
    for i, x in enumerate((3, 5.5, 8, 10.5, 13)):
        s += f'<path d="M8 15 {x} 3" stroke="{m}" stroke-width="1" stroke-linecap="round"/><circle cx="{x}" cy="3" r="1.3" fill="{cap}"/>'
    return s


def small_caps(cap, l):
    return "".join(f'<circle cx="{x}" cy="{y}" r="2.6" fill="{cap}"/><circle cx="{f(x - 0.7)}" cy="{f(y - 0.7)}" r="0.8" fill="{l}"/>' for x, y in ((5, 5.5), (10.5, 5), (7.8, 10), (12.5, 10.5), (3.5, 11)))


def kernels(m, l):
    return "".join(f'<rect x="{x}" y="{y}" width="3.4" height="3" rx="1" fill="{m}"/>' for x, y in ((2.5, 4), (6.3, 3.5), (10.1, 4), (4.4, 8), (8.2, 7.8), (6.3, 11.6))) + f'<rect x="3" y="4.5" width="1.4" height="1" rx="0.5" fill="{l}"/>'


def olive_ring(m, hole):
    return f'<ellipse cx="8" cy="8" rx="5.6" ry="4.8" fill="{m}"/><ellipse cx="8" cy="8" rx="2" ry="1.6" fill="{hole}"/>'


def teardrop(m, l):
    return f'<path d="M8 1.5c3 3 5 6 5 8.5a5 5 0 0 1-10 0c0-2.5 2-5.5 5-8.5Z" fill="{m}"/><path d="M8 4v8" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/>'


def walnut(m, l):
    return f'<path d="M3 5c1-2.5 4-3 5-1.5 1-1.5 4-1 5 1.5 1.5 3 0 7-2 8-1 .5-2 0-3-1-1 1-2 1.5-3 1-2-1-3.5-5-2-8Z" fill="{m}"/><path d="M8 3.5v9M5 7c1 .5 1.5 1.5 1.5 2.5M11 7c-1 .5-1.5 1.5-1.5 2.5" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def pillow(m, ridge):
    return f'<rect x="2" y="4" width="12" height="8" rx="3.5" fill="{m}"/><path d="M5 5v6M8 5v6M11 5v6" stroke="{ridge}" stroke-width="0.8" stroke-linecap="round"/>'


def ravioli(m, l, edge):
    return f'<rect x="2" y="2" width="12" height="12" rx="1.5" fill="{edge}"/><rect x="4" y="4" width="8" height="8" rx="3" fill="{m}"/><circle cx="7" cy="7" r="1.3" fill="{l}"/>'


def dumpling(m, pleat, sear=None):
    s = f'<path d="M1.5 10c0-4.5 3-7 6.5-7s6.5 2.5 6.5 7c0 1.5-1 2.5-2.5 2.5H4c-1.5 0-2.5-1-2.5-2.5Z" fill="{m}"/>'
    if sear:
        s += f'<path d="M3 11.5h10" stroke="{sear}" stroke-width="1.6" stroke-linecap="round"/>'
    return s + f'<path d="M4 5.5l1 1.6M6.5 4l.7 1.8M9.5 4l-.7 1.8M12 5.5l-1 1.6" stroke="{pleat}" stroke-width="0.9" stroke-linecap="round"/>'


def mochi(m, l):
    return f'<rect x="2.5" y="3" width="11" height="10" rx="4.5" fill="{m}"/><ellipse cx="6.5" cy="6" rx="2" ry="1.2" fill="{l}"/>'


def avocado_half(skin, flesh, pit):
    return f'<path d="M8 1c3 0 5.5 4 5.5 8.5S11 15 8 15s-5.5-1.5-5.5-5.5S5 1 8 1Z" fill="{skin}"/><path d="M8 2.4c2.3 0 4.2 3.4 4.2 7S10.3 13.8 8 13.8s-4.2-1-4.2-4.4S5.7 2.4 8 2.4Z" fill="{flesh}"/><circle cx="8" cy="9.6" r="2.6" fill="{pit}"/>'


def crescent(skin, flesh):
    return f'<path d="M2 12C3 6 8 2.5 14 2.5 12 8 8 12 2 12Z" fill="{flesh}"/><path d="M14 2.5C12 8 8 12 2 12l.6 1.2C9 13 13 8.5 15 3Z" fill="{skin}"/>'


def heart_half(m, l, s):
    return f'<path d="M8 14C4 11 1.5 8 2 5c.5-3 3.5-3.5 6-1.5 2.5-2 5.5-1.5 6 1.5.5 3-2 6-6 9Z" fill="{m}"/><path d="M8 12c-2-1.8-3.4-3.6-3.2-5.4" stroke="{l}" stroke-width="1.6" fill="none" stroke-linecap="round"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.5" fill="{s}"/>' for x, y in ((5, 6), (11, 6), (8, 9), (10, 9.5), (6, 9.5)))


def quarter(skin, flesh, seed_color):
    return f'<path d="M2 13 8 2l6 11Z" fill="{skin}"/><path d="M4 12 8 4.5 12 12Z" fill="{flesh}"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.6" fill="{seed_color}"/>' for x, y in ((7, 9), (9, 9.5), (8, 7.5), (8, 11)))


def cherry(m, l, stem):
    return f'<path d="M8 6c1-3 3-4.5 5-5" stroke="{stem}" stroke-width="1" fill="none" stroke-linecap="round"/><circle cx="7.5" cy="10" r="4.6" fill="{m}"/><circle cx="6" cy="8.6" r="1.2" fill="{l}"/>'


def sheet_square(m, l):
    return f'<rect x="2" y="2" width="12" height="12" rx="1" fill="{m}"/><path d="M4 5h8M4 8h8M4 11h8" stroke="{l}" stroke-width="0.6"/>'


def triangle(m, l):
    return f'<path d="M2 13 8 2.5 14 13Z" fill="{m}"/><path d="M5 11.5 8 6" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/>'


def short_strokes(m):
    return f'<path d="M2 5l3 1M7 3l1 3M11 4l3-1M3 10l2 2M7 9l3 1M12 9l1 3M6 13l3 0" stroke="{m}" stroke-width="1.2" stroke-linecap="round"/>'


def pastry_square(m, l, top):
    return f'<rect x="2" y="2" width="12" height="12" rx="2" fill="{m}"/><rect x="3.5" y="3.5" width="9" height="9" rx="1.5" fill="{top}"/><path d="M5 6h6M5 9h6" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/>'


def tube(m, l, ridges=False):
    s = f'<rect x="1.5" y="5" width="13" height="6" rx="1" fill="{m}" transform="rotate(-20 8 8)"/><ellipse cx="13.6" cy="5.6" rx="1.4" ry="3" fill="{l}" transform="rotate(-20 13.6 5.6)"/>'
    if ridges:
        s += f'<path d="M3 10.5l9-3.4M3.4 8.4l8.4-3.2" stroke="{l}" stroke-width="0.6" transform="rotate(0)"/>'
    return s


def spiral(m, l):
    return f'<path d="M3 3c3 1 3 3 0 4s0 3 3 4 3 3 0 4" stroke="{m}" stroke-width="3" fill="none" stroke-linecap="round" transform="translate(4 -1) rotate(15 8 8)"/><path d="M4 4c2 .8 2 2 0 2.8" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round" transform="translate(4 -1) rotate(15 8 8)"/>'


def elbow(m, l):
    return f'<path d="M3 11a6 6 0 0 1 9-7" stroke="{m}" stroke-width="3.6" fill="none" stroke-linecap="round"/><path d="M4.4 10a4.6 4.6 0 0 1 6.6-5" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


# Fills -------------------------------------------------------------------------------------


def grains_in(rng, base, grain, count=70, length=2.4, width=1.3, shape="mound", sheen=True):
    if shape == "mound":
        s = f'<path d="{blob_path(rng, C, C, R * 0.97, 0.06)}" fill="{base}"/>'
    else:
        s = f'<circle cx="{C}" cy="{C}" r="{R}" fill="{base}"/>'
    if sheen:
        s += f'<path d="{blob_path(rng, C - 6, C - 7, 15, 0.1)}" fill="#ffffff" opacity="0.28"/>'
    for x, y in scatter_in_circle(rng, C, C, R * 0.88, count):
        rot = rng.uniform(0, 180)
        s += f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{length}" ry="{width}" transform="rotate({f(rot)} {f(x)} {f(y)})" fill="{grain}"/>'
    return s


def smooth(rng, base, sheen, specks=None, full=False, ridges=None):
    s = f'<circle cx="{C}" cy="{C}" r="{R}" fill="{base}"/>' if full else f'<path d="{blob_path(rng, C, C, R * 0.95, 0.09, 10)}" fill="{base}"/>'
    s += f'<path d="{blob_path(rng, C - 8, C - 9, 10, 0.2, 8)}" fill="{sheen}"/>'
    if ridges:
        s += f'<path d="M14 36c6-8 16-10 24-6M20 44c6-5 14-6 22-2M18 26c4-4 10-5 16-3" stroke="{ridges}" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    if specks:
        for x, y in scatter_in_circle(rng, C, C, R * 0.8, 18):
            s += f'<circle cx="{f(x)}" cy="{f(y)}" r="0.9" fill="{specks}"/>'
    return s


def soup(rng, base, sheen, dots=None):
    s = f'<circle cx="{C}" cy="{C}" r="{R}" fill="{base}"/><circle cx="{C}" cy="{C}" r="{R - 3}" fill="none" stroke="{sheen}" stroke-width="1.6" opacity="0.6"/>'
    if dots:
        for x, y in scatter_in_circle(rng, C, C, R * 0.75, 9, 5):
            s += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(rng.uniform(1, 2.2))}" fill="{dots}"/>'
    return s


def noodles(rng, m, l, shade, width=2.4, count=26, broth=None, full=False, dots=None):
    s = ""
    if broth:
        s += f'<circle cx="{C}" cy="{C}" r="{R}" fill="{broth}"/>'
        r_nest = R * 0.72
    else:
        r_nest = R
    s += f'<circle cx="{C}" cy="{C}" r="{f(r_nest)}" fill="{shade}"/>' if (full or not broth) else ""
    for i in range(count):
        rr = r_nest * rng.uniform(0.2, 0.95)
        a0 = rng.uniform(0, math.tau)
        sweep = rng.uniform(1.6, 3.2)
        x0, y0 = C + rr * math.cos(a0), C + rr * math.sin(a0)
        x1, y1 = C + rr * math.cos(a0 + sweep), C + rr * math.sin(a0 + sweep)
        large = 1 if sweep > math.pi else 0
        c = m if i % 3 else l
        s += f'<path d="M{f(x0)} {f(y0)}A{f(rr)} {f(rr)} 0 {large} 1 {f(x1)} {f(y1)}" stroke="{c}" stroke-width="{width}" fill="none" stroke-linecap="round"/>'
    if dots:
        for x, y in scatter_in_circle(rng, C, C, r_nest * 0.85, 40):
            s += f'<circle cx="{f(x)}" cy="{f(y)}" r="0.8" fill="{dots}"/>'
    return s


def tiled(rng, piece_svg, size, count, base=None, shadow=None):
    s = f'<path d="{blob_path(rng, C, C, R * 0.96, 0.06)}" fill="{base}"/>' if base else ""
    for x, y in scatter_in_circle(rng, C, C, R * 0.8, count, size * 0.55):
        s += place(piece_svg, x, y, size, rng.uniform(0, 360))
    return s


def bed(rng, colors, vein, count=16):
    s = f'<path d="{blob_path(rng, C, C, R * 0.95, 0.1)}" fill="{colors[0]}"/>'
    for i, (x, y) in enumerate(scatter_in_circle(rng, C, C, R * 0.72, count)):
        s += place(torn_leaf(colors[i % len(colors)], vein), x, y, 18, rng.uniform(0, 360))
    return s


def shredded_bed(rng, colors):
    s = f'<path d="{blob_path(rng, C, C, R * 0.92, 0.1)}" fill="{colors[0]}"/>'
    for i in range(40):
        x, y = scatter_in_circle(rng, C, C, R * 0.8, 1)[0]
        a = rng.uniform(0, math.tau)
        x1, y1 = x + 7 * math.cos(a), y + 7 * math.sin(a)
        s += f'<path d="M{f(x)} {f(y)}Q{f((x + x1) / 2 + 2)} {f((y + y1) / 2 - 2)} {f(x1)} {f(y1)}" stroke="{colors[i % len(colors)]}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    return s


def slice_of_bread(crumb, crust, count=1, extra="", rot=0):
    s = ""
    offsets = [(0, 0, rot)] if count == 1 else [(-6, -5, -10), (7, 6, 12)]
    sc = 1.05 if count == 1 else 0.86
    for dx, dy, r in offsets:
        s += (
            f'<g transform="translate({C + dx} {C + dy}) rotate({r}) scale({sc})">'
            f'<path d="M-24 -8a12 12 0 0 1 10-18h28a12 12 0 0 1 10 18v28a4 4 0 0 1-4 4h-40a4 4 0 0 1-4-4Z" fill="{crust}"/>'
            f'<path d="M-19 -7a8 8 0 0 1 7-13h24a8 8 0 0 1 7 13v24h-38Z" fill="{crumb}"/>{extra}</g>'
        )
    return s


def flatbread(rng, m, spot, edge, oval=False):
    shape = f'<ellipse cx="{C}" cy="{C}" rx="{R}" ry="{R * 0.72}" fill="{edge}"/><ellipse cx="{C}" cy="{C}" rx="{R - 2.5}" ry="{R * 0.72 - 2.5}" fill="{m}"/>' if oval else f'<circle cx="{C}" cy="{C}" r="{R}" fill="{edge}"/><circle cx="{C}" cy="{C}" r="{R - 2.5}" fill="{m}"/>'
    for x, y in scatter_in_circle(rng, C, C, R * 0.6, 10, 5):
        shape += f'<ellipse cx="{f(x)}" cy="{f(y * 0.9 + 3)}" rx="{f(rng.uniform(1.4, 2.8))}" ry="{f(rng.uniform(1, 2))}" fill="{spot}"/>'
    return shape


def omelette(rng, m, l, fold):
    return f'<ellipse cx="{C}" cy="{C}" rx="{R}" ry="{R * 0.62}" fill="{m}"/><path d="M{C - R + 6} {C}c12-10 36-10 48 0" stroke="{fold}" stroke-width="1.6" fill="none" stroke-linecap="round"/><ellipse cx="{C - 8}" cy="{C - 6}" rx="9" ry="3.4" fill="{l}"/>'


def block(rng, m, l, edge):
    return f'<rect x="{C - 21}" y="{C - 17}" width="42" height="34" rx="4" fill="{edge}"/><rect x="{C - 19}" y="{C - 15}" width="38" height="30" rx="3" fill="{m}"/><path d="M{C - 13} {C - 9}h14" stroke="{l}" stroke-width="3" stroke-linecap="round"/>'


def layered_square(rng, top, sauce, edge):
    return f'<rect x="{C - 22}" y="{C - 22}" width="44" height="44" rx="4" fill="{edge}"/><rect x="{C - 19}" y="{C - 19}" width="38" height="38" rx="3" fill="{top}"/>' + "".join(f'<path d="{blob_path(rng, x, y, 5, 0.25, 7)}" fill="{sauce}"/>' for x, y in scatter_in_circle(rng, C, C, 14, 6, 9))


def rolls(rng, m, l, fill_color):
    s = ""
    for dy in (-14, 0, 14):
        s += f'<rect x="{C - 24}" y="{C + dy - 6}" width="48" height="12" rx="6" fill="{m}"/><path d="M{C - 20} {C + dy}h40" stroke="{fill_color}" stroke-width="3.2" stroke-linecap="round" opacity="0.6"/><path d="M{C - 18} {C + dy - 3}h20" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/>'
    return s


def row_of(rng, piece_svg, size, n=5):
    """Pieces set side by side the way gyoza come out of the pan, two short rows."""
    s = ""
    step = size * 0.62
    for row, dy in enumerate((-size * 0.42, size * 0.42)):
        count = n if row == 0 else n - 1
        x0 = C - step * (count - 1) / 2
        for i in range(count):
            s += place(piece_svg, x0 + i * step, C + dy, size, 0 if row == 0 else 180)
    return s


def melted(rng, m, l, brown):
    s = f'<path d="{blob_path(rng, C, C, R * 0.8, 0.16, 9)}" fill="{m}"/>'
    for x, y in scatter_in_circle(rng, C, C, R * 0.55, 6, 7):
        s += f'<path d="{blob_path(rng, x, y, 3, 0.3, 6)}" fill="{brown}"/>'
    return s + f'<path d="{blob_path(rng, C - 7, C - 6, 6, 0.3, 7)}" fill="{l}"/>'


def covering_slices(rng, piece_svg, size, n=5):
    s = ""
    for (dx, dy, rot) in [(-10, -11, -20), (9, -10, 15), (-12, 6, 10), (10, 8, -15), (0, -1, 5)][:n]:
        s += place(piece_svg, C + dx, C + dy, size, rot)
    return s


# Vessels -----------------------------------------------------------------------------------

VESSELS = {
    "plate": ('<circle cx="48" cy="48" r="46" fill="#f0ece4"/><circle cx="48" cy="48" r="37" fill="#e8e3d8"/>', "plate"),
    "plate-rim": ('<circle cx="48" cy="48" r="46" fill="#f0ece4"/><circle cx="48" cy="48" r="43" fill="none" stroke="#5f7fa3" stroke-width="2.4"/><circle cx="48" cy="48" r="37" fill="#e8e3d8"/>', "plate"),
    "plate-sage": ('<circle cx="48" cy="48" r="46" fill="#9fb8a0"/><circle cx="48" cy="48" r="37" fill="#b6cbb5"/>', "plate"),
    "plate-terracotta": ('<circle cx="48" cy="48" r="46" fill="#c9805f"/><circle cx="48" cy="48" r="37" fill="#d99a7c"/>', "plate"),
    "bowl": ('<circle cx="48" cy="48" r="46" fill="#f0ece4"/><circle cx="48" cy="48" r="40" fill="#d9d2c3"/>', "bowl"),
    "bowl-indigo": ('<circle cx="48" cy="48" r="46" fill="#3f5a7a"/><circle cx="48" cy="48" r="40" fill="#2f4762"/>', "bowl"),
    "bowl-sage": ('<circle cx="48" cy="48" r="46" fill="#7f9c82"/><circle cx="48" cy="48" r="40" fill="#6a876d"/>', "bowl"),
    "pan": ('<rect x="80" y="43" width="16" height="10" rx="5" fill="#a97142"/><circle cx="44" cy="48" r="42" fill="#6f747b"/><circle cx="44" cy="48" r="37" fill="#4a4e54"/>', "pan"),
    "pot": ('<rect x="0" y="43" width="12" height="10" rx="4" fill="#3d4146"/><rect x="84" y="43" width="12" height="10" rx="4" fill="#3d4146"/><circle cx="48" cy="48" r="40" fill="#8a9097"/><circle cx="48" cy="48" r="36" fill="#5d6268"/>', "pot"),
    "board": ('<rect x="4" y="12" width="88" height="72" rx="10" fill="#b98a55"/><rect x="8" y="16" width="80" height="64" rx="8" fill="#c99a62"/><path d="M14 30h30M50 44h32M16 62h40" stroke="#b98a55" stroke-width="1.6" stroke-linecap="round"/>', "board"),
}

# Where fills sit on each kind of vessel, as (cx, cy, r) on the 96 canvas.
REGIONS = {
    "plate": {"full": (48, 48, 32), "left": (36, 50, 24), "right": (61, 45, 25)},
    "bowl": {"full": (48, 48, 38), "left": (37, 48, 26), "right": (60, 48, 26)},
    "pan": {"full": (44, 48, 34), "left": (33, 50, 23), "right": (56, 45, 23)},
    "pot": {"full": (48, 48, 35), "left": (37, 48, 24), "right": (60, 48, 24)},
    "board": {"full": (48, 48, 34), "left": (32, 48, 22), "right": (64, 48, 22)},
}
