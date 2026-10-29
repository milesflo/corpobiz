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
- `make deploy` alone, if you just want the files copied without compiling.
- Override `GAME_DIR` / `APP_ID` / `PROTONTRICKS` as `make VAR=value ...`
  if the Steam library lives somewhere else.

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

## Useful CET console commands for manual testing

Paste into the CET console in-game (single line each):

```lua
-- Give the player money
Game.GetTransactionSystem():GiveItem(Game.GetPlayer(), MarketSystem.Money(), 50000)

-- Unlock 7th Hell's purchase gate (the real "An Inconvenient Killer"
-- completion fact was never identified; this is the self-asserted flag
-- SeventhHell.reds checks instead -- see its GigPrereq() comment)
Game.GetQuestsSystem():SetFact("corpobiz_seventh_hell_gig_done", 1)

-- Read any Fact (must use print -- see console gotcha above)
print("value="..Game.GetQuestsSystem():GetFact("fact_name_here"))
```

## Git commit signing

This machine's global git config requires commit signing with a hardware
security key (`ED25519-SK`), and `ssh-askpass` isn't installed, so git
can't even prompt for the key's PIN -- commits fail with "Couldn't sign
message: device not found" or "incorrect passphrase". Signing is disabled
for *this repo only* (`git config commit.gpgsign false`, stored in this
clone's local `.git/config`, not tracked by git). If this repo ever gets
a fresh `git clone` (as opposed to copying the folder) on a machine with
the same global signing requirement, that local override won't carry
over and this will resurface -- rerun `git config commit.gpgsign false`
in the new clone rather than fighting the signing prompt again.

## Architecture quick reference

See `README.md` for the full picture. In short: `base/` is the generic
CorpoBiz engine and must never import or name a specific business module;
`modules/<Name>/` holds one folder per business, each extending
`BizModule` and self-registering. If you're about to add a second
business, copy `modules/7thHell/`'s shape and read the "Installing a
second business module" section of the README first.
