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

- `CulinaryIntelligence` is a local Swift package holding everything that is not a view: the
  models, the generator and the editor, and the PlatesCloud client. The app links it as its one package
  product and imports it wherever it touches a recipe. The package's code runs on the main actor
  by default in Swift 5 mode, as the app's does, and what the app uses is `public`.
- `CulinaryIntelligence/Sources/CulinaryIntelligence/Models` holds `Recipe`, `RecipeList`, and
  the icon catalog. Files are read through `Decodable` and written by hand in `RecipeJSON`,
  because `JSONEncoder` hands its keys back in whatever order its own storage holds them.
  Property order is the key order written back to disk, so keep the properties and
  `Recipe.json` matching the schema and each other. A step carries a title, the icons it works
  with, and its points. It has no hint or image, which is where the file shape parts from the
  site's. The public types carry hand written `public` initializers, since Swift does not make
  a memberwise one public.
- `Plates/Storage` holds the storage location and the file-backed `RecipeStore`.
- There is no model to choose. Gemma writes on Cloudflare and Apple Intelligence sorts on the
  device, falling back to Private Cloud Compute.
- `CulinaryIntelligence/Sources/CulinaryIntelligence/Cloud` holds `PlatesCloud`, the client for
  the Worker in `../PlatesCloud` (github.com/katagaki/PlatesCloud). The Worker runs Google's Gemma
  4 26B A4B on Workers AI behind an OpenAI Chat Completions endpoint, capped at 1,400 tokens,
  and asks TypeSafe's Jev to pick an idea when the cook taps Decide for Me. Its address is
  `PlatesCloudAddress.url`, empty in the repository. `ci_scripts/ci_pre_xcodebuild.sh` writes
  Xcode Cloud's `PLATES_CLOUD_URL` environment variable into it before the build, and a build
  without it says it has no recipe writer. For a local build against the Worker, run the script
  with `PLATES_CLOUD_URL` and `CI_PRIMARY_REPOSITORY_PATH` set, and do not commit the result. Every request is signed with App Attest: the first request makes a
  key, attests it against a challenge from the Worker, and keeps its ID in the Keychain, and
  each request after that carries an assertion over the SHA-256 of its body. A key the Worker
  no longer knows is dropped and made again once. App Attest does not run in Simulator, so
  a debug build there sends its requests unsigned to `http://localhost:8787`, where `npm run dev` in
  ../PlatesCloud answers them when its `.dev.vars` sets `SKIP_APP_ATTEST=true`. Debug builds also register
  `plates-debug://generate?request=...&decide=true`, which opens the recipe sheet and writes the
  request at once, with `decide` letting Jev pick from the ideas. Release builds do not list the
  scheme: `Info.plist` is preprocessed, and only Debug defines `DEBUG`. The Worker keeps the daily limits, Decide for Me
  included, so the app only shows what it is told is left. `LimitsView`, opened from the ellipsis
  menu, reads all of them from the Worker's `/v1/limits`.
  `WrittenRecipe` and `Measures` sit in `Writer`: they read what Gemma wrote before any model
  sorts it.
- `CulinaryIntelligence/Sources/CulinaryIntelligence/Intelligence` holds the Apple Intelligence
  `@Generable` types, the generator, and the editor. A recipe is written by two models, the way
  the evals ran them, and every step of it is shaped by what the Mac runs of it showed:
  - Gemma writes in English, always. Granite, the model the evals ran before it, got the
    cooking right in English and badly wrong in Japanese, so its instructions, the house style
    it is given, and the names of the cook's picks are read from the English catalog through
    `String(culinaryEnglish:)` in every locale. Those keys still carry Japanese values, marked in their comments as never sent.
  - A request the cook typed in anything but plain ASCII is put into English by Apple
    Intelligence first. Granite read "卵チャーハン" as egg curry.
  - `WrittenRecipe` cuts Gemma's text into its sections in code. The time and the serving
    count are read out of it there, through `Recipe.minutes(in:)` and the figures in the line,
    because a model read "1 hour 20 minutes" as two hours.
  - `Measures` converts cups, ounces, pounds, inches, and Fahrenheit to metric for a reader
    outside the US, and writes spoon measures and "to taste" the Japanese way for a Japanese
    reader, before any model sees the line. A model asked to convert got half a cup wrong.
  - Apple Intelligence then sorts one line at a time, each in its own session: the title, every
    ingredient, every tool, every step, every problem. Given a whole list, it dropped lines,
    merged steps, and filled the gaps from the troubleshooting, even with the count fixed by a
    `DynamicGenerationSchema`; given one line, it has nothing else to draw on. A step comes back
    as one piece of text and is cut into sentences with `NLTokenizer`, so there are no slots to
    pad. Every sorting pass has a response token limit: one ran on past seven thousand tokens,
    overran the window, and was taken for a request too large for the device. A line that
    fails is retried with a growing wait, since the usual failure is the system rate limiting a
    run in the background. When a section cannot be split into lines, it is
    sorted from the whole text with a ranged `DynamicGenerationSchema` instead.
  - The sorting passes are not given the house style: they sorted its cooking rules into the
    method as steps. `Generate.Prompt.Structure` carries the wording rules and the language
    instead, and in Japanese, how to translate.
  - What code can read off Gemma's English line, code decides rather than the pass: an
    ingredient's icon is the longest run of the line's words the catalog knows (measure words
    such as "cloves" skipped), whether an ingredient or a tool is optional is whether the line
    says so, and a figure the pass wrote without its metric unit gets the unit back. When the
    line names a catalog ingredient, the pass is handed the catalog's name for it, so "frozen
    peas" is not translated as green peppers.
  - A cook's picks are what they have, not what the dish needs. Gemma is told to choose only
    what the dish needs and to list only what its method uses, and `withoutUnusedPicks` drops
    any ingredient line naming a pick, or any pan, pot, or appliance line naming a picked tool,
    that no step mentions. What Gemma added on its own, anything "to taste", and utensils such
    as knives and boards, which a method seldom names, are kept.
  - Text a sorting pass returns goes through `withoutLeakedSyntax`, because the on-device model
    sometimes runs past a Japanese string into `」} ```json{` or a `<ctrl46>` token, and then
    through `Measures.tidied`, which puts a spoon measure written back as "2大さじ" right and
    writes every range with "to", or から in Japanese.
  An Apple pass runs on device first, and only a pass the on-device model rejects with
  `contextSizeExceeded` is run again on `PrivateCloudComputeLanguageModel`. That fallback, the
  background time a pass runs in, and whether the model is there at all are written down once
  in `ModelPasses`, which both the generator and the editor run through. A generation has no
  read through at the end. It had one, and once the sorting was faithful line for line, the read
  through was what made recipes wrong: it rewrote whole lists, dropping and duplicating lines
  and adding ones Gemma never wrote. Rewriting a recipe keeps its read through, since there it
  checks the result against what the cook asked.
- Before a recipe is written, `RecipeGenerator.plan` sorts the request on device into a named
  dish, goals ("high protein with noodles"), or an open request ("something easy tonight"). A
  dish the cook's picks can make, or a dish with nothing picked, is written straight away.
  Anything else gets five ideas from Gemma through the Worker's `/v1/ideate`, which counts them
  against their own daily limit rather than the recipes', one a line, read by `ideaLines` and put
  into the reader's language by a sorting pass each. Open requests ask for the easiest dishes first. The
  cook picks an idea, or taps Decide for Me, which sends the request, the picks, and Gemma's
  English for the ideas to Jev through the Worker, a hundred times a day per device. A set of ideas
  carries a request ID, so a retried pick is answered from the first one and not counted
  again. The picked idea is written from Gemma's own English for it.
- The generator and the editor report their progress to a `RunObserver` the app hands in, so the
  package never imports ActivityKit. `Plates/Activity/GenerationActivity` is that observer, and
  runs the Live Activity.
- `RecipeAskEditor` rewrites a recipe the cook already has, from a request in their own words.
  It asks twice over: once for a plan of what to change, then once for each change on that plan,
  each in its own session and given only the recipe and the one change to make. The plan is what
  the progress screen lists, so its rows are as many as the work turned out to be rather than
  fixed the way a generation's are. Changes to the recipe as a whole are made first and step
  changes from the last step back, so adding or dropping a step never moves one that a later
  change is counting on. A rewrite ends with a read through: the recipe is checked against what
  the cook asked for and against itself, and whatever that finds is made as more rows on the
  same checklist. It comes back as `GeneratedRecipeReview`, which is a plan in the shape the
  editor already carries out. Every
  other pass reads the method as step titles; the read through after an edit is the one pass
  handed the steps written out, because whether a recipe makes sense is in what the steps say.
  It is the largest prompt the app sends, and on the bundled recipes it runs around 600 tokens,
  so the cloud stays a fallback.
- `Plates/Views` holds the list, detail, generation, editing, and sharing views.
  `Plates/Views/Onboarding` holds `OnboardingView`, laid out the way SakuraRSS's is: one file
  per step. A new install is shown it until `Onboarding.Completed` is set: what Plates does,
  then a dish to write the first recipe from, which opens the recipe sheet with it filled in, or
  a skip straight into the app. The recipe sheet shows the ideas, when there are some, between
  the request and the progress screen, with Decide for Me under them. Writing a recipe
  and rewriting one show the same progress screen: a checklist of the work, and under it
  `RecipePreview`, the recipe as it stands at that moment. While Gemma writes, the preview is
  its text as it streams in, a finished line at a time and one `Text` a paragraph. The detail
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

### Dish icons

A recipe card and the top of the detail view show the finished dish from above, put together
from drawn parts rather than drawn whole. The parts are vector image sets in
`Plates/Assets.xcassets/Dishes`: vessels (`DishVesselBowlIndigo`), fills that cover a region of
the vessel (`DishFillRiceBowl`), and pieces scattered on top (`DishPieceTomatoDiced`). Every
catalog ingredient that can be seen once a dish is served has one or more variants, named by how
it is cut or cooked, and the rest are listed as hidden with the reason. What the layout knows
about each part, its kind, the vessels a fill goes in, a piece's size, count, and tier, and the
colours it reads as, is in the package's `Resources/DishParts.json`. The parts, the image sets,
and that file are all written together by the scripts in `Docs/DishIcons`, which also build the
review sheets every part is checked on; change a part there and export again rather than editing
an SVG by hand.

`Dish.planned(for:)` works out the dish from the recipe: the grain or the sauce is the food it
is built on, the vessel follows from that and from the tools, and what is seen on top is read off
the ingredient icons, the title, and the last step, with the cut read from the recipe's own words
in English or Japanese. `DishLayout` places the parts on a 96 point canvas, seeded from the
recipe's `id` so an icon is the same on every launch, and gives a piece an outline when its
colours sit too close to what it lands on. `DishIcon` draws the placements in a `Canvas`. The
dish is not written to the recipe file.

The catalog is never inlined into a `@Generable` schema: the on-device model has a 4,096 token
window, and an `.anyOf` over 369 ingredient names overruns it before the prompt is even added.

## Localization

All user-facing text goes through a string catalog, with English (US) as the source language
and the project's development region set to `en-US`. There are two. `Plates/Localizable.xcstrings`
holds what the views say. `CulinaryIntelligence/Sources/CulinaryIntelligence/Resources/Localizable.xcstrings`
holds what the package says: every prompt, the pass titles the Live Activity shows, the errors,
and the icon names. Package code reads its own catalog through `String(culinary:)` and
`LocalizedStringResource(culinary:)`, never `String(localized:)`, which would look in the app's.
A key both a view and the package use, such as `Edit.Progress.Planning`, is kept in both. Japanese is the second
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
  runtime from the asset name, so the entries are kept in the package's string catalog by hand with
  `extractionState` set to `manual`, and adding an icon means adding its name in both
  languages.
- Everything a model is given is a key too, Gemma's prompt included, under
  `Generate.Prompt.`, `Generate.Lookup.`, and `Edit.Prompt.`, down to the comma a list is joined
  with. Only the `@Generable` schema descriptions stay in
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
