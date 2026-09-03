# Plates

A single-view iOS recipe manager. Recipes are JSON files that follow the schema used by the
One-Pan Food site in `../Recipes`, one file per recipe, stored either in the app's Documents
folder or in iCloud Drive depending on what the user picks in the ellipsis menu.

## Code rules

- No file headers. Swift files start at the first `import`, with no leading comment block
  naming the file, the project, or the author.
- Never use em-dashes anywhere: not in user-facing copy, code comments, commit messages, or
  this file. Use a period, comma, or colon instead.
- All user-facing text ships in English (US) and Japanese. A new key is written in both.
- The app is a single view. Do not add a `TabView`. Menu items and settings live in the top
  trailing ellipsis menu.

## Copy style rules

- Write plainly, like a good cookbook. No breathless adjectives, no "it's not X, it's Y"
  constructions, no rule-of-three padding.
- Write ranges with the word "to", never a dash.

## Layout

- `Plates/Models` holds `Recipe` and the icon catalog. Property order in the `Codable` types
  is the key order written back to disk, so keep it matching the schema. A step carries a
  title, the icons it works with, and its points. It has no hint or image, which is where the
  file shape parts from the site's.
- `Plates/Storage` holds the storage location and the file-backed `RecipeStore`.
- `Plates/Intelligence` holds the Apple Intelligence `@Generable` types and the generator. The
  recipe is written in five passes, each in its own session, so no one request carries the whole
  recipe. The first pass picks the ingredients and pins each to a catalog icon, so every later
  pass works from a list that already exists. A pass runs on device first, and only a pass the
  on-device model rejects with `contextSizeExceeded` is run again on
  `PrivateCloudComputeLanguageModel`. Keep passes small enough that the cloud stays a fallback.
- `Plates/Views` holds the list, detail, and generation views.
- `Shared` holds `GenerationActivityAttributes`, the one file both the app and the widget
  extension compile. The app localizes every string before it goes into the activity state, so
  the extension never looks a key up and carries no strings of its own.
- `PlatesActivity` is the widget extension holding the Live Activity, bundle identifier
  `com.tsubuzaki.Plates.Seasoning`. The app embeds it and declares `NSSupportsLiveActivities`.
- `Plates/SampleRecipes` holds the recipes bundled with the app for the "Add Sample Recipes"
  menu item.
- `Plates` also holds `Info.plist` and `Plates.entitlements`. They sit in the synchronized
  group, so the target lists them as membership exceptions to keep them out of the bundle's
  resources.

## Icons

Every SVG lives in `Plates/Assets.xcassets`: ingredient icons in `Ingredients` and tool icons
in `Tools`. The site's step illustrations are not shipped. They are asset catalog vector images
with `preserves-vector-representation`.

Asset catalog items are always Pascal cased, including the SVG file inside the image set:
`SpringOnion.imageset/SpringOnion.svg`. Recipe files stay kebab cased because that is the
site's schema, so `img/ingredients/spring-onion.svg` is read by `IconCatalog.iconName(for:)`
as `spring-onion` and drawn through `IconCatalog.assetName(for:)` as `SpringOnion`. When
adding an icon, copy the SVG in with explicit `width` and `height` on the root element,
otherwise the asset catalog will not take it.

`IconCatalog` lists every icon, groups the ingredients into the categories the picker browses,
and resolves whatever icon name the generator's model writes back onto one that exists. The
catalog is never inlined into a `@Generable` schema: the on-device model has a 4,096 token
window, and an `.anyOf` over 178 ingredient names overruns it before the prompt is even added.

## Localization

All user-facing text goes through `Plates/Localizable.xcstrings`, with English (US) as the
source language and the project's development region set to `en-US`. Japanese is the second
language, listed in the project's `knownRegions` as `ja`. Every key carries both, so a key added
without a Japanese value is unfinished. Japanese copy follows the same plain style, written in
です・ます.

- Keys are dot notated and Pascal cased by segment, from broad to narrow:
  `Recipe.Detail.Ingredients.Supermarket`, `Menu.Sort.TriedOnly`, `Shared.Cancel`. Never write
  the English text as the key.
- Views pass the key as a string literal (`Text("Recipe.Detail.Time")`). Strings that come from
  outside a view use `LocalizedStringResource`, and formatted ones use
  `String(format: String(localized: "Key"), ...)` with positional specifiers such as `%1$@`.
- Recipe data is not localized. Titles, amounts, steps, and error text from the system are
  shown with `Text(verbatim:)` so they are never looked up as keys. A generated recipe is
  written in the reader's language because the prompts are, not because it is translated after
  the fact.
- Every catalog icon carries its own name key, `Ingredient.Name.SpringOnion` and
  `Tool.Name.CuttingBoard`, read through `IconCatalog.displayName(for:)`. The key is built at
  runtime from the asset name, so the entries are kept in the string catalog by hand with
  `extractionState` set to `manual`, and adding an icon means adding its name in both
  languages.
- Everything the model is given is a key too, under `Generate.Prompt.` and `Generate.Lookup.`,
  down to the comma a list is joined with. Only the `@Generable` schema descriptions stay in
  English: they are the shape of the answer, not the prompt, and the house style tells the
  model which language to write in.
- A recipe's `time` is stored as the model wrote it and shown through `Recipe.formattedTime`,
  which reads the minute count out of it and formats it with `Duration.UnitsFormatStyle`, so
  "25 min" is read as "25分" in Japanese.

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
