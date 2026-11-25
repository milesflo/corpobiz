# Agent notes for CorpoBiz

Read this before touching `.reds` files or the build tooling in this repo.
Everything here was learned the hard way, via the compiler/engine actually
rejecting or silently misbehaving with something that looked reasonable --
re-deriving it would waste a lot of turns. If a project doc elsewhere
(`README.md`) conflicts with this file, trust the actual compiler.

## Workflow

- `make doctor` -- run this first on a new machine before anything else.
  Checks GAME_DIR, `engine/tools/scc.exe`, Codeware's script files, and
  that `jq`/`wine`/`xdotool`/protontricks/`$DISPLAY` are all present.
- `make compile` -- the only loop that matters while iterating. Runs
  `check-deps` -> `deploy` -> the standalone redscript compiler, with
  compile-error dialogs auto-dismissed. Takes seconds; never launch the
  full game just to check whether a change compiles.
- `make compile-mod MOD=<module>` -- compiles Base plus only that module. Run it
  after touching a module's imports: it's the only thing that proves the module
  stays standalone (Base as its sole dependency). `make package MOD=<module|base>`
  builds that mod's zip into `dist/`.
- `make deploy` alone, if you just want the files copied without compiling.
- Override `GAME_DIR` / `APP_ID` / `PROTONTRICKS` as `make VAR=value ...`
  if the Steam library lives somewhere else.
- **Commit messages are conventional commits** (`feat: ...`, `fix(scope): ...`,
  `docs: ...`; see README "Commit messages and releases"). The
  `git-commit-api` path skips the local commit-msg hook: check your subject
  first with `python3 tools/release/release.py check-title "<subject>"`.
- **Releases come from `info.json`, not from commits.** Bumping a mod's
  `version` in its `info.json` and merging to `main` cuts that mod's release
  (and publishes it unless it's listed in `tools/release/unreleased.txt`). Never
  bump a version as a side effect of other work; do it only when asked to release.
- **Before every commit, run `pre-commit run --all-files` and `make compile`
  yourself.** Commits made with `git-commit-api` (the required agent commit
  path) are created through the GitHub API, so the local git pre-commit /
  pre-push hooks never fire for them -- only CI backs you up, and CI can't
  compile redscript. The pre-commit config's grep hooks encode the gotchas
  below; if one blocks you, fix the code, don't loosen the hook without a
  failing compile to justify it. The gitleaks hook only scans *staged*
  changes, so `git add` first or it checks nothing.

## redscript (.reds) language gotchas

These are specific to the redscript build in use here (confirmed via the
actual compiler, not assumption) -- don't re-litigate them without a new
failing compile to prove otherwise:

- **`array<SomeStruct>` has no callable methods.** `.PushBack()`, `.Size()`,
  etc. all fail with `has no members`, for any user-defined struct, in any
  calling style (direct, `script_ref`, local variable). Only two things
  work: building the array as a **literal** (`let arr = [a, b, c];`) and
  consuming it with a `for x in arr` loop. Indexing (`arr[i]`) and
  `.Size()`/`.PushBack()` are not proven to work and shouldn't be assumed.

- **`array<ref<SomeClass>>` literals don't covariantly widen**, even with
  an explicit `let` type annotation. `let mods: array<ref<Base>> = [new
  Derived()];` fails with `can't coerce '[ref<Derived>]' into
  '[ref<Base>]'`. Fix: declare the array empty and use the **global
  function** `ArrayPush(arr, item)` to add elements one at a time --
  Codeware's own source (`red4ext/plugins/Codeware/Scripts/*.reds`) uses
  `ArrayPush` exclusively and never calls `.PushBack()` as a method. If a
  literal's elements are all the *exact* declared type (no widening
  needed), the literal works fine -- it's specifically widening-on-
  construction that fails.

- **User-declared `static let` class fields don't resolve reliably.**
  `ClassName.fieldName` access errors with "expected a value, found a
  symbol"; bare `fieldName` access from within the class's own static
  method errors with "unresolved reference". Don't use a static field for
  mutable singleton-ish state. Instead, extend Codeware's
  `ScriptableSystem` (the engine auto-instantiates one persistent instance
  per game session) and use a normal **instance** field, retrieved via
  `GameInstance.GetScriptableSystemsContainer(game).Get(n"Module.ClassName")
  as ClassName`. See `base/Registry.reds` for the working pattern.

- **Enum values need explicit integers.** `enum X { A, B, C }` is a
  syntax error ("expected '='"); must be `enum X { A = 0, B = 1, C = 2 }`.
  No C-style auto-increment.

- **`abstract class` with bodiless methods works** as a real interface --
  `public func Foo() -> Void;` (semicolon, no `{}`) in the base class
  compiles, and a subclass provides the body. See `base/BizModule.reds`
  and `base/Resource.reds`.

- **`@wrapMethod` composes across independent files.** Multiple different
  `.reds` files can each wrap the *same* vanilla method with no conflict
  (each `wrappedMethod()` call chains to the next wrapper, eventually
  reaching the vanilla implementation). This is how modules self-register
  with `base/Registry.reds` without `base/` needing to import or name
  them: each module wraps `ScriptedPuppet.OnGameAttached` independently
  (the same hook `base/StaffSpawner.reds` already wraps for its own
  purpose) and calls `CorpoBizRegistry.Register(...)` from there.

- **Raw strings still process backslash escapes.** `r"path\with\backslash"`
  is a syntax error. Use forward slashes in every resource path:
  `r"base/characters/entities/..."`.

- **`script_ref<array<T>>`, not `ref<array<T>>`,** matches a native
  method's mutable-array-by-reference parameter. `array<T>` isn't a
  class, so `ref<>` is the wrong wrapper for it.

- **Decompiled `.script`'s `self`-first-param static functions become
  instance methods in `.reds`.** A decompiled signature like
  `static function GetComponent(self: X): Y` is called in modern redscript
  as `x.GetComponent()`, not `X.GetComponent(x)`.

- **No `.reds` method-pointer/callback parameters confirmed working.**
  Don't design an API around passing a function as a value between
  modules; resolve whatever a generic function needs in the caller and
  pass plain data instead (this is why `CorpoBiz.reds` never calls back
  into a specific business's role/variant catalog -- see
  `base/Registry.reds`'s `RoleVariantCount/TemplatePath/Name` for the one
  place that needed this, kept to a single file by design).

- **Procedural ink widgets (`inkCanvas`/`inkText`/`inkRectangle`) are a
  real, pure-script alternative to WolvenKit-authored UI assets** -- they
  compile against the game's native type info (same as any other native
  class), so wrong method names/signatures are caught by the compiler
  like anything else. Confirmed working, found by letting real compile
  errors correct wrong guesses (see `base/WebUI.reds`):
  - `new inkCanvas()` / `new inkText()` / `new inkRectangle()`, then
    `.Reparent(parent)` to attach -- not a `parent.AddChild(widget)` call.
  - `inkEAnchor.TopLeft` works; `TopFillHorizontally` doesn't exist on
    that enum (didn't check which fill-style members, if any, do).
  - Removing a previously-built widget is `parent.RemoveChild(widget)`
    (called on the *parent*) -- `widget.Unparent()` and
    `widget.RemoveFromParent()` don't exist on `inkWidget`, despite both
    being very plausible-sounding guesses.
  - `inkCompoundWidget.GetWidgetByPathName(name: CName)` takes a bare
    `CName`, not an `inkWidgetPath` -- no need to build one.
  - `ComputerInkGameController.GetRootCompoundWidget()` returns the
    terminal's actual on-screen root widget -- confirmed by compiling,
    NOT yet confirmed to be the right attach point visually (z-order
    versus the vanilla Mail-thumbnail list it sits alongside, whether it
    actually renders where expected) -- that needs an in-game look, which
    the compiler can't tell you.
  - Color is `HDRColor(r, g, b, a)` with 0.0-1.0 float components, passed
    to `SetTintColor` -- worked first try, unconfirmed whether a
    non-HDR `Color` overload also exists.

- **Checking real vanilla quest/gig completion: use `JournalManager`, not
  a guessed Fact name.** A quest's completion Fact is hand-authored per
  quest with no naming convention (confirmed via redmodding.org's own
  docs: "There is no strict naming convention") -- guessing one is a
  silent-failure risk with zero compiler safety net, unlike guessing a
  method/class name (which a failed `make compile` catches immediately).
  `JournalManager` sidesteps needing the Fact at all:
  - Find the quest/gig's real internal resource path first -- e.g. via
    [CDPR-Modding-Documentation/Cyberpunk-Modding-Docs' quest-id
    reference](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs/blob/main/for-mod-creators-theory/references-lists-and-overviews/reference-quest-ids.md)
    on GitHub (gigs are listed under "Street Stories", e.g. "An
    Inconvenient Killer" -> `quests/street_stories/city_center/downtown/sts_cct_dtn_02`).
  - `GameInstance.GetJournalManager(game).GetEntryByString(path: String,
    "gameJournalQuest")` resolves that path to a journal entry (confirmed
    compiling AND confirmed live in-game via the CET console one-liner
    in the "Useful CET console commands" section below).
  - `.GetEntryState(entry)` returns a `gameJournalEntryState` (`Succeeded`
    confirmed as the completed state, ordinal 3) -- compare with
    `Equals(state, gameJournalEntryState.Succeeded)`.
  - See `base/CorpoBizPrereqs.reds`'s `BizPrereqKind.Gig` case and
    `modules/7thHell/SeventhHell.reds`'s `GigDonePrereq()` for the working
    pattern -- this replaced 7th Hell's earlier self-asserted
    `corpobiz_seventh_hell_gig_done` Fact, which is no longer used.
  - **If a future module's gig isn't in that GitHub doc, find its short id
    live in-game instead** (confirmed working end-to-end for 7th Hell's
    `sts_cct_dtn_02`, matching the docs exactly): with the gig active and
    its current objective tracked on-screen, `jm:GetTrackedEntry()`
    returns that *objective*, not the gig -- one `jm:GetParentEntry(...)`
    hop up lands on the gig-level entry, whose `tostring(entry:GetId())`
    is the short id (e.g. `"sts_cct_dtn_02"`). **Use `tostring()`, never
    CET's `Dump()`, on an id value** -- see the CET gotcha below for why.
    The short id alone isn't enough for `GetEntryByString` (which needs
    the full dictionary path, e.g.
    `quests/street_stories/city_center/downtown/sts_cct_dtn_02`) --
    untested whether repeatedly walking `GetParentEntry()` all the way to
    the root and joining each ancestor's id with `/` reconstructs that
    full path without needing the docs reference at all.

## Tooling / environment gotchas

- **REDmod's own `mods/<name>/` + `redmod.exe deploy` pipeline doesn't
  work reliably under Proton** -- it reports success without ever
  updating the compiled script cache. The standalone
  [redscript](https://github.com/jac3km4/redscript) package's
  `r6/scripts/` auto-compile-at-launch mechanism, driven directly via
  `engine/tools/scc.exe`, is what actually works (and what `make compile`
  uses).

- **REDmod's own *bundled* `scc.exe`** (under `tools/redmod/bin/`) is a
  *different binary* from the standalone one, with a genuine bug under
  Wine that makes it report "no script files found" even when the files
  are plainly there. Always use `engine/tools/scc.exe` (standalone
  redscript package), never the REDmod-bundled one.

- **`make compile`'s error-detection grep was silently broken from the
  start** (fixed now, but worth knowing why): it looked for the literal
  substring `[ERROR]` and `[INFO] Compilation complete`, but scc.exe's
  real log format always embeds a timestamp inside the brackets --
  `[ERROR - Thu, 29 Oct 2026 14:24:17 -0700] [CODE] ...` -- so the exact
  string `[ERROR]` never appears and the check always fell through to
  "COMPILE OK" even with real errors present. Every prior session's
  compiles happened to have zero errors, so this never got exercised
  until it did. Fixed to match `\[ERROR` / `Compilation complete`
  (dropping the exact-closing-bracket requirement) -- if `make compile`
  ever reports OK but something still seems off, grep the actual
  `_scratch/compile.log` by hand to be sure, same as this was caught.

- **A blocking "Compilation error" dialog stops the Wine process** when a
  `.reds` file fails to compile. `make compile` auto-dismisses it with
  `xdotool`, but `xdotool` **must run from the host X session**, not from
  inside the flatpak-sandboxed protontricks `-c "..."` command -- inside
  that sandbox, `xdotool search` sees no windows at all, even ones that
  are visibly open.

- **CET (Cyber Engine Tweaks) console: bare Lua expressions do not
  auto-print.** `Game.GetQuestsSystem():GetFact("x")` typed alone produces
  no visible output. Wrap in `print(...)`:
  `print("x="..Game.GetQuestsSystem():GetFact("x"))`. The console is also
  single-line only -- it doesn't accept multi-line pasted input.

- **CET's `Dump(obj, detailed)` crashed the whole game (not a Lua error --
  the process went down) when called on the value returned by a journal
  entry's `GetId()`.** `Dump()` is apparently only safe on real object
  handles (`GameDataType`s like `Game.GetPlayer()`), not on whatever
  value/struct type an id-like getter returns. Don't call `Dump()` on a
  return value until its type is known to be a real object -- `tostring()`
  on it directly is the safe fallback for value types.

## Useful CET console commands for manual testing

Paste into the CET console in-game (single line each):

```lua
-- Give the player money
Game.GetTransactionSystem():GiveItem(Game.GetPlayer(), MarketSystem.Money(), 50000)

-- Read any Fact (must use print -- see console gotcha above)
print("value="..Game.GetQuestsSystem():GetFact("fact_name_here"))

-- Check a gig/quest's real journal state by its internal resource path
-- (see the "JournalManager" gotcha below for how this path was found and
-- confirmed) -- Succeeded is ordinal 3 in gameJournalEntryState
local jm = Game.GetJournalManager(); local e = jm:GetEntryByString("quests/street_stories/city_center/downtown/sts_cct_dtn_02", "gameJournalQuest"); print(e ~= nil and tostring(jm:GetEntryState(e)) or "NOT FOUND")
```

## Architecture quick reference

See `README.md` for the full picture. In short: `base/` is the generic
CorpoBiz engine and must never import or name a specific business module;
`modules/<Name>/` holds one folder per business, each extending
`BizModule` and self-registering. If you're about to add a second
business, copy `modules/7thHell/`'s shape and read the "Installing a
second business module" section of the README first.
