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
- Everything that is not a view goes in the `CulinaryIntelligence` package. What the app uses
  is `public`, and public types need hand written `public` initializers.
- The package never imports ActivityKit. Progress goes out through `RunObserver`.
- The widget extension carries no strings. The app localizes everything before it goes into
  the activity state.

## Copy style rules

- Write plainly, like a good cookbook. No breathless adjectives, no "it's not X, it's Y"
  constructions, no rule-of-three padding.
- Write ranges with the word "to", never a dash.

## Recipe files

- Files are written by hand in `RecipeJSON`, not `JSONEncoder`, which does not keep key order.
  Property order is the key order on disk, so keep the properties and `Recipe.json` matching the
  site's schema and each other.
- Sample recipes are written out once per language, in `en-US.lproj` and `ja.lproj`, under the
  same file name and the same `id`, so switching languages does not add a second copy.

## PlatesCloud

The Worker lives in `../PlatesCloud` (github.com/katagaki/PlatesCloud) and keeps every daily
limit. The app only shows what it is told is left.

- `PlatesCloudAddress.url` is empty in the repository. `ci_scripts/ci_pre_xcodebuild.sh` writes
  Xcode Cloud's `PLATES_CLOUD_URL` into it. For a local build against the Worker, run the script
  with `PLATES_CLOUD_URL` and `CI_PRIMARY_REPOSITORY_PATH` set, and do not commit the result.
- App Attest does not run in Simulator, so a debug build there sends unsigned requests to
  `http://localhost:8787`. Run `npm run dev` in `../PlatesCloud` with `SKIP_APP_ATTEST=true` in
  its `.dev.vars`.
- Debug builds register `plates-debug://generate?request=...&decide=true` to write a request at
  once. `Info.plist` is preprocessed so Release builds do not list the scheme.

## Model lessons

Gemma writes on Cloudflare and Apple Intelligence sorts on the device. Each rule below came out
of the evals, so do not undo one without running them again.

- Gemma is always given English, read through `String(culinaryEnglish:)`, and a non-ASCII
  request is put into English first. The model before it read "卵チャーハン" as egg curry.
  The Japanese values on those keys are never sent.
- Read in code whatever code can read: sections, time, servings, units, icons, and whether a
  line is optional. A model read "1 hour 20 minutes" as two hours and got half a cup wrong.
- Sort one line per session. Given a whole list, the on-device model dropped lines, merged
  steps, and padded from the troubleshooting.
- Every sorting pass has a response token limit. One ran past seven thousand tokens and was
  reported as a request too large for the device.
- Sorting passes are not given the house style. They turned its cooking rules into steps.
- When a line names a catalog ingredient, hand the pass the catalog's name, or "frozen peas"
  comes back as green peppers.
- Asked whether the picks can make a dish, the model said yes to a tomato pasta with no pasta.
  The starch is checked against the picks in code.
- A generation has no read through at the end. It rewrote whole lists, dropping, duplicating,
  and inventing lines. A rewrite keeps its read through, since there it checks the result
  against what the cook asked.
- Never inline the catalog into a `@Generable` schema. The on-device window is 4,096 tokens,
  and an `.anyOf` over every ingredient name overruns it on its own.
- Keep passes small enough that Private Cloud Compute stays a fallback for
  `contextSizeExceeded`, not the usual path.

## Icons

- Asset catalog items are Pascal cased, including the SVG inside: `SpringOnion.imageset/SpringOnion.svg`.
  Recipe files stay kebab cased, as the site's schema is.
- Copy an SVG in with explicit `width` and `height` on the root element, or the asset catalog
  will not take it.
- Adding an icon means adding its `Ingredient.Name.` or `Tool.Name.` key in both languages, by
  hand, with `extractionState` set to `manual`.

### Dish icons

The parts, `Plates/Dishes.xcassets`, and the package's `Resources/DishParts.json` are all written
from `Assets/DishIcons/Parts`. Do not edit the outputs.

- After changing a prepared part, run `swift sync.swift` from `Assets/DishIcons`.
- `swift contrast.swift` checks piece colours against the test surfaces.
- After changing a drawn shape, run `python3 export.py` there to regenerate the prepared SVGs and
  review sheets.

## Localization

English (US) is the source language and Japanese the second. Japanese copy follows the same
plain style, written in です・ます.

- Package code reads its own catalog through `String(culinary:)` and
  `LocalizedStringResource(culinary:)`, never `String(localized:)`, which would look in the
  app's. A key both a view and the package use is kept in both catalogs.
- Keys are dot notated and Pascal cased by segment, from broad to narrow:
  `Recipe.Detail.Ingredients.Supermarket`. Never write the English text as the key.
- Formatted strings use `String(format: String(localized: "Key"), ...)` with positional
  specifiers such as `%1$@`.
- Recipe data is not localized. Show it with `Text(verbatim:)`.
- Everything a model is given is a key, down to the comma a list is joined with. Only the
  `@Generable` schema descriptions stay in English.

## Commit rules

- Single line only. No body, no trailers, no attribution or co-author lines.
- Keep it short (under about 60 characters) and in the imperative mood: "Add recipe detail
  view", not "Added" or "Adds".
- No prefixes like `feat:`/`fix:`, no emoji, no issue references.
- Commit whenever a major change is complete, rather than batching unrelated work.
