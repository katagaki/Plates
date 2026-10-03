# Fluent icon style for Plates

Every ingredient and tool icon is drawn in a Fluent Color style: flat shapes, no outlines,
filled with soft gradients lit from the top left, and one highlight per main body. Open several
existing icons before you draw, in particular Tomato, Egg, Broccoli, Butter, Garlic, Rice,
SoySauce, Pot and Knife.

## File rules

- Root element exactly: `<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="...">`.
  Keep the `aria-label` in plain English (US), describing the thing drawn.
- Allowed elements: `defs`, `linearGradient`, `radialGradient`, `stop`, `g`, `path`, `circle`,
  `ellipse`, `rect`, `line`, `polygon`. Attributes: `fill`, `fill-opacity`, `stroke`,
  `stroke-opacity`, `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `opacity`, `transform`.
- Not allowed: `filter`, `mask`, `clipPath`, `pattern`, `image`, `text`, `use`, `style`
  elements or attributes, CSS classes. The asset catalog renders through CoreSVG.
- Gradients use `gradientUnits="userSpaceOnUse"` with explicit coordinates, so they line up
  with the shapes. They live in `<defs>` at the top. Ids are short and unique within the file.
- No file header or comments. Two space indentation, one element per line, like the existing icons.
- Do not touch `Contents.json`, file names, or anything outside your assigned `.svg` files.
- The drawing fills about the same area as today: roughly 40 by 40 inside the 48 box, centred.
  Many current files wrap the drawing in `<g transform="translate(...) scale(1.125)">`. Keeping
  that wrapper is fine; gradient coordinates are then in the inner space.

## Light and colour

- Light comes from the top left. Every main body gets a gradient from a lighter tint at the top
  left, through the base colour, to a deeper shade at the bottom right.
  - Round bodies (fruit, bulbs, florets): `radialGradient` centred at the upper left of the shape,
    radius about 1.5 times the shape's radius. Three stops: tint, base at about .5, shade at 1.
  - Flat faces and boxes: `linearGradient` on the diagonal. On boxes, the top face is lightest,
    the left face is the base, and the right face is darkest.
  - Cylinders, bottles and handles: horizontal `linearGradient`, light on the left.
- Shift hue a little across the ramp, as Fluent does: tints run warmer and lighter, shades run
  deeper and more saturated. Tomato goes `#ff8a75` to `#ec4a3c` to `#b3242b`.
- One specular highlight on each main body, at the upper left: a white ellipse or a short round
  capped stroke, `fill-opacity` or `stroke-opacity` from .5 to .85. Glossy things (tomato, egg
  yolk, eggplant, chili, cherries) get a crisp bright one. Matte things (bread, flour, meat, tofu)
  get a soft one around .3 to .5, or none.
- Detail lines (ridges, segments, veins, scale marks, seams) are a darker shade of the body
  colour at opacity .4 to .6, not an opaque new colour.
- No outlines, no drop shadows, no backgrounds, no ground plane.

## Reusable ramps

Keep families consistent across icons:

| Material | Ramp (tint, base, shade) |
| --- | --- |
| Leaf green | `#a6dc7e`, `#5fa83f`, `#3f8a2e` |
| Deep green (broccoli, kale) | `#8fcf5c`, `#4f9a34`, `#2f6e22` |
| Red (tomato, strawberry) | `#ff8a75`, `#ec4a3c`, `#b3242b` |
| Orange (carrot) | `#ffb25c`, `#ff7a1f`, `#d9520c` |
| Yellow (lemon, butter) | `#fff59a`, `#ffd21f`, `#e09a00` |
| White food (garlic, rice, tofu) | `#ffffff`, `#f1ece0`, `#cfc6b2` |
| Brown (mushroom, crust) | `#d79a63`, `#a4693a`, `#6e3d1c` |
| Steel | `#e3e9ef`, `#b2bcc6`, `#8e99a4` |
| Dark metal (pans, pots) | `#767d86`, `#4e545c`, `#25282d` |
| Wood | `#d79c64`, `#b07440`, `#8a5530` |
| Fish back (blue grey) | `#7f9fb6`, `#5a7b93`, `#3f5e75` |

## Small sizes and dark mode

- The smallest size the app draws is 20 pt. Every icon must still be recognisable there.
  Nothing structural thinner than about 1.2 units. The silhouette carries recognition, not the
  gradients.
- Check every icon on white and on `#1c1c1e`. White foods keep their lightest stop at `#f0f0f0`
  or above so they do not go grey. Very dark items (soy sauce, nori, black beans, pans) need a
  lighter tint or a highlight on the top left edge so they separate from the dark background.

## Accuracy review, before you redraw

For each icon, before drawing, check the current icon against the real thing:

1. Find what the ingredient is. The icon name is the Pascal cased recipe id. Look up its English
   name in `Plates/Localizable.xcstrings` (`Ingredient.Name.<Name>` or `Tool.Name.<Name>`), and
   its id in `CulinaryIntelligence` if needed. Note the Japanese name too; it can clarify which
   ingredient is meant (for example `Mentsuyu`, `Chikuwa`, `Shiso`).
2. Ask: is this what a cook would recognise? Right shape, proportions, colour, anatomy, and the
   form it is usually bought or used in. If you are unsure what it looks like, search the web for
   photos (WebSearch, WebFetch) before deciding.
3. Conventions: a fish ingredient is the whole fish; fillets, steaks, cans and kabayaki are their
   own variant icons. Variants stay visually consistent with their parent (Salmon,
   SalmonFillet, SmokedSalmon share colours).
4. It must be told apart from its neighbours at 20 pt: Lemon, Lime, Yuzu, Sudachi, Mandarin;
   Shiitake, Mushroom, Enoki, Shimeji, KingOyster; the soy sauces and vinegars; the pasta
   shapes; the flours. Open neighbouring icons (even outside your batch, read only) to compare.
5. If anything is wrong, fix it in the redraw: change the shape, colour or detail as needed. If
   it is right, keep the silhouette and change only the rendering.

## Workflow

1. Read the current SVG, if there is one, and do the accuracy review.
2. Draw the SVG in `Plates/Ingredients.xcassets` or `Plates/Tools.xcassets`.
3. Render it: `python3 Assets/IconStyle/batch_sheet.py /tmp/icons.png Name1 Name2 ...` (up to
   about 8 names). It shows the committed version and the working tree side by side, on light
   and dark, at 48 pt and 20 pt. Look at it, fix anything that looks wrong, and render again.
4. To compare a group of neighbours, such as every bottled sauce:
   `python3 Assets/IconStyle/overview.py /tmp/sauces "#1c1c1e" SoySauce Mentsuyu Ponzu ...`.
   Pass `all` instead of names for a contact sheet of every icon.
