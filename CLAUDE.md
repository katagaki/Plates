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

- `Plates/Models` holds `Recipe` and the icon catalog. Files are read through `Decodable` and
  written by hand in `RecipeJSON`, because `JSONEncoder` hands its keys back in whatever order
  its own storage holds them. Property order is the key order written back to disk, so keep the
  properties and `Recipe.json` matching the schema and each other. A step carries a title, the
  icons it works with, and its points. It has no hint or image, which is where the
  file shape parts from the site's.
- `Plates/Storage` holds the storage location and the file-backed `RecipeStore`.
- `Plates/Intelligence` holds the Apple Intelligence `@Generable` types and the generator. The
  recipe is written in five passes, each in its own session, so no one request carries the whole
  recipe. The first pass picks the ingredients and pins each to a catalog icon, so every later
  pass works from a list that already exists. A pass runs on device first, and only a pass the
  on-device model rejects with `contextSizeExceeded` is run again on
  `PrivateCloudComputeLanguageModel`. Keep passes small enough that the cloud stays a fallback.
  That fallback, the background time a pass runs in, and whether the model is there at all are
  written down once in `ModelPasses`, which both the generator and the editor run through.
- `RecipeAskEditor` rewrites a recipe the cook already has, from a request in their own words.
  It asks twice over: once for a plan of what to change, then once for each change on that plan,
  each in its own session and given only the recipe and the one change to make. The plan is what
  the progress screen lists, so its rows are as many as the work turned out to be rather than
  fixed the way a generation's are. Changes to the recipe as a whole are made first and step
  changes from the last step back, so adding or dropping a step never moves one that a later
  change is counting on.
- `Plates/Views` holds the list, detail, generation, editing, and sharing views. The detail
  view turns into the editor in place, so a recipe is read and written on the one screen, and
  every edit is written straight to the file rather than kept until the editor is left. The
  catalog picker the generation view browses is the same one the editor picks into, pointed at
  one of the recipe's own lists. Sharing writes the recipe to the temporary folder as a
  `.plate` file, which is its JSON, as a picture, or as letter sized pages whose text stays
  text: the pages are packed block by block, each measured first, so nothing is cut in half.
- `Shared` holds `GenerationActivityAttributes`, the one file both the app and the widget
  extension compile. The app localizes every string before it goes into the activity state, so
  the extension never looks a key up and carries no strings of its own.
- `PlatesActivity` is the widget extension holding the Live Activity, bundle identifier
  `com.tsubuzaki.Plates.Seasoning`. The app embeds it and declares `NSSupportsLiveActivities`.
- `Plates/SampleRecipes` holds the recipes bundled with the app for the "Add Sample Recipes"
  menu item. Recipe text is not looked up in the string catalog, so each sample is written out
  once per language in its own `.lproj` folder, `en-US.lproj` and `ja.lproj`, under the same
  file name and the same `id`. `addSampleRecipes` copies the reader's language only, and the
  shared `id` means switching languages does not add a second copy of a recipe already saved.
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

`IconCatalog` lists every icon, groups the ingredients and the tools into the categories the
pickers browse, and resolves whatever icon name the generator's model writes back onto one
that exists. The ingredient groups sit on one of two shelves, fresh and pantry, and each shelf
has a picker of its own. Both write into the one ingredient list the model is handed, so the
split is in the browsing, not in the request.

The catalog is never inlined into a `@Generable` schema: the on-device model has a 4,096 token
window, and an `.anyOf` over 264 ingredient names overruns it before the prompt is even added.

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
- Everything the model is given is a key too, under `Generate.Prompt.`, `Generate.Lookup.`,
  and `Edit.Prompt.`, down to the comma a list is joined with. Only the `@Generable` schema descriptions stay in
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
