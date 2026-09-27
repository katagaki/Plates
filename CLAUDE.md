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
  models, the generator and the editor, and llama.cpp. The app links it as its one package
  product and imports it wherever it touches a recipe. The package's code runs on the main actor
  by default in Swift 5 mode, as the app's does, and what the app uses is `public`.
- llama.cpp comes in as a `binaryTarget` pointing at ggml-org's release xcframework, pinned by
  URL and checksum. It is pinned to b10456, the newest release that still carries an iOS
  simulator slice; later releases ship the device slice only. Check for the simulator slice
  before moving the pin.
- `CulinaryIntelligence/Sources/CulinaryIntelligence/Models` holds `Recipe`, `RecipeList`, and
  the icon catalog. Files are read through `Decodable` and written by hand in `RecipeJSON`,
  because `JSONEncoder` hands its keys back in whatever order its own storage holds them.
  Property order is the key order written back to disk, so keep the properties and
  `Recipe.json` matching the schema and each other. A step carries a title, the icons it works
  with, and its points. It has no hint or image, which is where the file shape parts from the
  site's. The public types carry hand written `public` initializers, since Swift does not make
  a memberwise one public.
- `Plates/Storage` holds the storage location and the file-backed `RecipeStore`.
- The cook picks who writes the recipes, in onboarding and again from "Choose Model" in the
  menu: Granite, Apple Foundation Models, Claude, or OpenAI. `ModelSettings` in `Models` holds
  the pick in the app's defaults and the API keys in the Keychain, readable after first unlock
  so a run in the background can still send its requests. Claude and OpenAI each take two
  models: a generation model, which writes recipes, translates the cook's request, and plans and
  makes edits, and a verification model, which runs the sorting passes and the editor's read
  through. The verification model is asked for low effort where the model takes it, since a
  recipe is sorted in dozens of small passes. The model lists are Claude Haiku 4.5, Sonnet 5,
  and Opus 5.5, and GPT-6 Astra, Sol, and Luna, by the identifiers their APIs take.
- `RemoteLanguageModel` in `Intelligence` is Claude or OpenAI as a Foundation Models
  `LanguageModel`, so every pass runs through the same `LanguageModelSession` code whoever
  answers. Its executor turns the transcript into a Messages API or Responses API request,
  streams the reply back as text, and sends a `@Generable` schema as the API's JSON schema
  format. `GenerationSchema` encodes as JSON Schema already, but carries `x-order`, `title`, and
  count and length limits that the APIs turn down, so those keywords are taken out, leaving
  property names alone. Tools are not passed on. `ModelCheck` says hello to the picked model,
  to both remote models when they differ, and is what onboarding's connection step runs.
- `CulinaryIntelligence/Sources/CulinaryIntelligence/Writer` holds the writer model and its
  runner. `WriterModel` is IBM's Granite 4.0 1B at Q4_K_M, the build the Plates Kitchen evals in
  `../PlatesKitchen` ran, downloaded from a pinned Hugging Face revision into Application
  Support and kept out of backups. `WriterModelDownload` fetches it in a background URL session,
  so the download carries on when the app is left, and the app hands the session identifier to
  `backgroundTask(.urlSession(_:))`. `RecipeWriter` runs it through llama.cpp with the evals'
  settings: a 4,096 token window, up to 1,400 tokens, temperature 0.7. It loads the model for one
  recipe and frees it before Apple Intelligence runs. It runs on the GPU only where the GPU is
  Metal family Apple10 (A19, M5, and later) and on the CPU everywhere else, Simulator included:
  without Metal's tensor API, b10456's kernels write nothing but "@" for Granite. Reproduce it
  on a Mac with `GGML_METAL_TENSOR_DISABLE=1`. Newer builds fix it, so this can go when the pin
  moves.
  `WrittenRecipe` and `Measures` sit beside it: they read what Granite wrote before any model
  sorts it.
- `CulinaryIntelligence/Sources/CulinaryIntelligence/Intelligence` holds the Apple Intelligence
  `@Generable` types, the generator, and the editor. A recipe is written by two models, the way
  the evals ran them, and every step of it is shaped by what the Mac runs of it showed:
  - Granite writes in English, always. A 1B model gets the cooking right in English and badly
    wrong in Japanese, so its instructions, the house style it is given, and the names of the
    cook's picks are read from the English catalog through `String(culinaryEnglish:)` in every
    locale. Those keys still carry Japanese values, marked in their comments as never sent.
  - A request the cook typed in anything but plain ASCII is put into English by Apple
    Intelligence first. Granite read "卵チャーハン" as egg curry.
  - `WrittenRecipe` cuts Granite's text into its sections in code. The time and the serving
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
  - What code can read off Granite's English line, code decides rather than the pass: an
    ingredient's icon is the longest run of the line's words the catalog knows (measure words
    such as "cloves" skipped), whether an ingredient or a tool is optional is whether the line
    says so, and a figure the pass wrote without its metric unit gets the unit back. When the
    line names a catalog ingredient, the pass is handed the catalog's name for it, so "frozen
    peas" is not translated as green peppers.
  - Text a sorting pass returns goes through `withoutLeakedSyntax`, because the on-device model
    sometimes runs past a Japanese string into `」} ```json{` or a `<ctrl46>` token, and then
    through `Measures.tidied`, which puts a spoon measure written back as "2大さじ" right and
    writes every range with "to", or から in Japanese.
  With Apple Foundation Models, Claude, or OpenAI picked, that model writes in Granite's place,
  from Granite's own English prompt, since the reading below is of English text; the rest of
  the run is the same. An Apple pass runs on device first, and only a pass the on-device model
  rejects with `contextSizeExceeded` is run again on `PrivateCloudComputeLanguageModel`. That
  fallback, the background time a pass runs in, whether the model is there at all, and which
  model a pass goes to are written down once in `ModelPasses`, which both the generator and the
  editor run through. A `ModelPasses` is made for a role, generation or verification, and sends
  every pass to the cook's remote model for that role when one is picked. A generation has no read
  through at the end. It had one, and once the sorting was faithful line for line, the read
  through was what made recipes wrong: it rewrote whole lists, dropping and duplicating lines
  and adding ones Granite never wrote. Rewriting a recipe stays on Apple Intelligence alone,
  and keeps its read through, since there it checks the result against what the cook asked.
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
- `Plates/Views` holds the list, detail, generation, editing, and sharing views, and
  `ModelDownloadView`. `Plates/Views/Onboarding` holds `OnboardingView`, laid out the way
  SakuraRSS's is: one file per step. A new install is shown it until `Onboarding.Completed` is
  set: what Plates does, the model to use, then either Granite's download or a hello to the
  picked model, and last a dish to write the first recipe from, which opens the recipe sheet
  with it filled in, or a skip straight into the app. "Choose Model" opens it at the model step
  and closes it once the model has answered. While Granite is picked and not on disk after
  onboarding, `MainView` shows `ModelDownloadView`, which cannot be dismissed and closes by
  itself once the file lands. Both show the download as a ring with the percentage in the
  middle, and offer to try again when the download fails. Writing a recipe
  and rewriting one show the same progress screen: a checklist of the work, and under it
  `RecipePreview`, the recipe as it stands at that moment. While Granite writes, the preview is
  its text as it streams in. The detail
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
- Everything a model is given is a key too, Granite's prompt included, under
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
