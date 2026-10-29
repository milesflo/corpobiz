# Biz7thHell

A Cyberpunk 2077 redscript mod. After finishing the side gig "An Inconvenient
Killer," the player can buy the nightclub 7th Hell (Downtown/City Center) and
run it as a business from its in-world terminal: hire/fire staff, change
their look, restock, and collect revenue.

## How it's structured

- `scripts/Biz7thHell/*.reds` — all mod logic.
  - `State.reds` — persistence, backed by the game's Facts system.
  - `Config.reds` — roles, costs, positions, look variants.
  - `Economy.reds` — lazy revenue/stock-decay accrual based on elapsed game time.
  - `StaffSpawner.reds` — proximity-based spawning/despawning of hired staff.
  - `HostileCleanup.reds` — despawns leftover hostile NPCs in the venue once owned.
  - `Terminal.reds` — the actual buy/hire/fire/restock/collect actions.
  - `TerminalUI.reds` — injects a "Biz" tab into the terminal's UI (see below).
- `info.json` — REDmod manifest (kept for compatibility; see caveat below).

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
