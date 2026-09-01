# Plates

A single-view iOS recipe manager. Recipes are JSON files that follow the schema used by the
One-Pan Food site in `../Recipes`, one file per recipe, stored either in the app's Documents
folder or in iCloud Drive depending on what the user picks in the ellipsis menu.

## Code rules

- No file headers. Swift files start at the first `import`, with no leading comment block
  naming the file, the project, or the author.
- Never use em-dashes anywhere: not in user-facing copy, code comments, commit messages, or
  this file. Use a period, comma, or colon instead.
- All user-facing text is English.
- The app is a single view. Do not add a `TabView`. Menu items and settings live in the top
  trailing ellipsis menu.

## Copy style rules

- Write plainly, like a good cookbook. No breathless adjectives, no "it's not X, it's Y"
  constructions, no rule-of-three padding.
- Write ranges with the word "to", never a dash.

## Layout

- `Plates/Models` holds `Recipe` and the icon catalog. Property order in the `Codable` types
  is the key order written back to disk, so keep it matching the schema.
- `Plates/Storage` holds the storage location and the file-backed `RecipeStore`.
- `Plates/Intelligence` holds the Apple Intelligence `@Generable` types and the generator.
- `Plates/Views` holds the list, detail, and generation views.
- `Plates/SampleRecipes` holds the recipes bundled with the app for the "Add Sample Recipes"
  menu item.
- `Config` holds `Info.plist` and the entitlements, kept outside the synchronized `Plates`
  group so they are not also copied in as resources.

## Icons

Every SVG from the site lives in `Plates/Assets.xcassets`: ingredient icons in `Ingredients`,
tool icons in `Tools`, and step illustrations in `Steps`. They are asset catalog vector images
with `preserves-vector-representation`, named after the SVG file, so a schema path such as
`img/ingredients/garlic.svg` maps to the asset `garlic`. When adding an icon, copy the SVG in
with explicit `width` and `height` on the root element, otherwise the asset catalog will not
take it.

## App icon

The app icon is an Icon Composer document at `AppIcon.icon`, not an asset catalog icon set.
Layers are SVGs in `AppIcon.icon/Assets`, one group each, over an automatic gradient fill.
`ASSETCATALOG_COMPILER_APPICON_NAME` stays `AppIcon` and resolves to that document.

## Commit rules

- Single line only. No body, no trailers, no attribution or co-author lines.
- Keep it short (under about 60 characters) and in the imperative mood: "Add recipe detail
  view", not "Added" or "Adds".
- No prefixes like `feat:`/`fix:`, no emoji, no issue references.
- Commit whenever a major change is complete, rather than batching unrelated work.
