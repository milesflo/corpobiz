# Biz7thHell / CorpoBiz Framework

A Cyberpunk 2077 redscript mod, built on a small reusable framework
("CorpoBiz") for owning and running businesses in the city. 7th Hell (a
nightclub, Downtown/City Center) is the first business implemented on it:
after finishing the side gig "An Inconvenient Killer," the player can buy it
and run it from its in-world terminal — hire/fire staff, change their look,
restock, and collect revenue.

## How it's structured

- `scripts/Biz7thHell/src/` — the generic CorpoBiz framework (`module
  CorpoBiz`). Knows nothing about any specific business:
  - `Biz.reds` — the data model: `BizDef`, `BizPrereq`/`BizPrereqKind`,
    `BizRoleDef`, `BizResource`.
  - `BizModule.reds` — the module contract: an `abstract class BizModule`
    every business implements (`Def()`, `GetRole()`,
    `RoleVariantCount/TemplatePath/Name`).
  - `CorpoBizState.reds` — Facts-backed persistence, namespaced by bizId
    (and role/resource id where relevant).
  - `CorpoBizPrereqs.reds` — checks a `BizDef`'s purchase gates (quest
    completion / player level / player stat).
  - `CorpoBiz.reds` — buy/hire/fire/restock/collect actions and lazy
    revenue + stock-decay accrual.
  - `Registry.reds` — the composition root: the only file in `src/`
    allowed to name a specific business module by name.
  - `StaffSpawner.reds` — proximity-based spawn/despawn of hired staff,
    for every registered module.
  - `HostileCleanup.reds` — despawns leftover hostile NPCs in a venue
    once it's owned, for every registered module.
  - `TerminalUI.reds` — injects a "Biz" tab into any terminal whose
    position matches a registered module's business (see below).
- `scripts/Biz7thHell/modules/<BusinessName>/` — one folder per business,
  each independently installable. Currently just:
  - `modules/7thHell/SeventhHell.reds` — `SeventhHellModule extends
    BizModule`: its `BizDef` (price, prereqs, terminal position, roles,
    input resource), role lookup, and look-variant catalog.
- `info.json` — REDmod manifest (kept for compatibility; see caveat below).

### Installing a second business module

Add a new folder under `modules/` (Title-Case business name) with a class
extending `BizModule`, then register one instance of it in
`CorpoBizRegistry.All()` in `src/Registry.reds` — that's the only place in
the generic engine allowed to reference a concrete module. Staff spawning,
hostile cleanup, and the terminal UI all pick it up automatically with no
other changes, since they only ever talk to modules through the
`BizModule` interface.

`TerminalUI.StaffDashboard` builds its role rows via count-based branching
rather than a loop (supports 0–4 roles) — `array<Struct>` has no `PushBack`
in this redscript build, so a fixed-size array literal is the only way to
return a variable number of rows; a module with more than 4 roles needs
another branch added there.

**Not yet verified to compile.** The `src`/`modules` split and the
`BizModule` abstract-class refactor were done just before a session pause;
the last known-good, fully-verified state was the flatter
`CorpoBizRegistry`-dispatch-by-id version (see git history). Run the
compile loop described below before relying on this structure in-game.

### Inputs/outputs (supply chains) — modeled, not yet playable

`BizDef.inputs`/`outputs: array<BizResource>` name the goods a business
consumes/produces (7th Hell's input is "Alcohol", consumed as its stock).
Actually moving a resource between businesses — GTA Online-style supply
runs — is intentionally not implemented yet; this is just the data shape
that feature will hang off of later.

## The terminal UI, and why it's built the way it is

There's no way to add a brand-new top-level tab widget to a computer
terminal without WolvenKit-authored UI assets. Instead, `TerminalUI.reds`
`@wrapMethod`s `ComputerInkGameController.InitializeMenuButtons` and
`InitializeMailsThumbnails` to:

- rebuild the top tab bar for *this specific terminal only* (matched by
  world position) as Web / Network / **Biz**, where "Biz" reuses the
  vanilla Mail tab's plumbing (`widgetName = "mails"`) so the game's own
  `GoToMenu` dispatch shows/hides it correctly;
- replace the Mail tab's contents with a small in-list menu (Home → Staff /
  Stock, with a "← Back" row), navigated via a persisted `UIView` fact.

Every row needs a **unique** `widgetName` (see `MakeEntry` in
`TerminalUI.reds`) — the game dedups cached widgets by
`ownerID+widgetName+widgetTweakDBID+libraryPath+libraryID`, not by document
address, so rows sharing a widgetName silently overwrite each other.

## Deploying to the game

**Do not use REDmod's own `mods/` + `redmod.exe deploy` pipeline** — in
testing (Steam/Proton on Linux) it reported success without ever actually
updating the compiled script cache. What actually works is the standalone
[redscript](https://github.com/jac3km4/redscript) package's auto-compile-at-launch
mechanism:

1. Install, in the Cyberpunk 2077 install directory:
   - [RED4ext](https://github.com/WopsS/RED4ext)
   - [Cyber Engine Tweaks](https://github.com/maximegmd/CyberEngineTweaks) (for live debugging via Facts/console; not required to just play)
   - [Codeware](https://github.com/psiberx/cp2077-codeware) (RED4ext plugin + its own `.reds` scripts)
   - standalone `redscript` (provides `engine/tools/scc.exe` and
     `engine/config/base/scripts.ini`) — this is what actually compiles
     `.reds` files at game launch.
2. Copy `scripts/Biz7thHell/` into `<game>/r6/scripts/Biz7thHell/`.
3. Launch the game normally; redscript compiles automatically. Compile
   errors show as a blocking dialog in-game.

## Fast local iteration (no game launch needed)

`engine/tools/scc.exe` (the standalone redscript compiler, not REDmod's
bundled one) can be invoked directly:

```sh
wine engine/tools/scc.exe -compile r6/scripts \
  -compilePathsFile _scratch/paths_win.txt \
  -outputCacheFile _scratch/test.redscripts \
  r6/cache/final.redscripts
```

`_scratch/paths_win.txt` needs to list Codeware's `.reds` files
(`z:/`-prefixed, forward slashes) alongside `r6/scripts` so the compiler can
resolve Codeware types. This catches script errors in seconds instead of a
full game relaunch.
