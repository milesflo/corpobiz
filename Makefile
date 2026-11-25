# Deploys the mod into the game's standalone-redscript source tree and runs
# the standalone redscript compiler against it, without launching the game.
#
# Everything here is self-contained (doesn't depend on any file sitting
# untracked in the game directory) so it works the same on another machine
# -- override GAME_DIR / APP_ID / PROTONTRICKS below (via `make VAR=value`
# or env vars) if your Steam library or game lives somewhere else.

GAME_DIR     ?= $(HOME)/.local/share/Steam/steamapps/common/Cyberpunk 2077
APP_ID       ?= 1091500
PROTONTRICKS ?= flatpak run com.github.Matoking.protontricks

BASE_DIR    := base
MODULES_DIR := modules
DEST_ROOT   := $(GAME_DIR)/r6/scripts

SCRATCH_DIR := $(GAME_DIR)/_scratch
PATHS_FILE  := $(SCRATCH_DIR)/paths_win.txt
COMPILE_LOG := $(SCRATCH_DIR)/compile.log

# Codeware's own .reds files, which the standalone compiler needs listed
# alongside r6/scripts to resolve Codeware types. Win-style (z:/-prefixed,
# forward-slash) paths, as the Windows redscript compiler running under
# Wine expects.
CODEWARE_SCRIPTS_DIR := $(GAME_DIR)/red4ext/plugins/Codeware/Scripts
CODEWARE_FILES := \
	Codeware.Localization.reds \
	Codeware.UI.reds \
	Codeware.UI.TextInput.reds \
	Codeware.Global.reds \
	Codeware.reds

.ONESHELL:
SHELL := /bin/bash
.PHONY: all deploy compile paths-file clean-deploy check-deps doctor logos

all: compile

# Regenerate assets/brand/ (base logo, icon, one 16:9 card per module).
# Run after adding or renaming a module -- see BRAND.md.
logos:
	python3 tools/brand/gen_logos.py

# Environment sanity check -- run this first on a new machine (e.g. after
# moving this repo to a laptop) before `make compile`, since a missing
# piece here produces much more confusing errors from deploy/compile.
doctor:
	ok=1
	check() {
		if eval "$$2"; then
			echo "  OK   $$1"
		else
			echo "  FAIL $$1"
			ok=0
		fi
	}
	echo "GAME_DIR = $(GAME_DIR)"
	check "GAME_DIR exists"                 '[ -d "$(GAME_DIR)" ]'
	check "engine/tools/scc.exe present"    '[ -f "$(GAME_DIR)/engine/tools/scc.exe" ]'
	check "Codeware Scripts dir present"    '[ -d "$(CODEWARE_SCRIPTS_DIR)" ]'
	for f in $(CODEWARE_FILES); do
		check "Codeware file: $$f" '[ -f "$(CODEWARE_SCRIPTS_DIR)/$$f" ]'
	done
	check "jq on PATH"                      'command -v jq >/dev/null'
	check "wine on PATH"                    'command -v wine >/dev/null'
	check "xdotool on PATH"                 'command -v xdotool >/dev/null'
	check "flatpak protontricks installed"  'flatpak list 2>/dev/null | grep -qi protontricks'
	check "DISPLAY is set"                  '[ -n "$$DISPLAY" ]'
	if [ "$$ok" -ne 1 ]; then
		echo "doctor: one or more checks failed -- see README for prerequisites"
		exit 1
	fi
	echo "doctor: all checks passed"

# Modules are meant to be distributable independently (a user could obtain
# modules/7thHell/ without base/, e.g. from a separate download), so the
# dependency a module declares on base -- or on another module -- in its
# own info.json ("dependencies": [{"name": ...}]) is real, not decorative.
# The redscript compiler would already catch a genuinely missing dependency
# (SeventhHell.reds's "import CorpoBiz.*" fails to resolve without base/),
# but only with a cryptic unresolved-symbol error; this gives the same
# check a clear message, before spending time on a deploy/compile cycle.
# Nothing here is read or enforced by REDmod or the game itself -- this is
# our own convention, checked by our own tooling.
check-deps:
	names_file=$$(mktemp)
	if [ -f "$(BASE_DIR)/info.json" ]; then
		jq -r '.name' "$(BASE_DIR)/info.json" >> "$$names_file"
	fi
	for info in $(MODULES_DIR)/*/info.json; do
		jq -r '.name' "$$info" >> "$$names_file"
	done
	ok=1
	for info in $(MODULES_DIR)/*/info.json; do
		mod_name=$$(jq -r '.name' "$$info")
		deps=$$(jq -r '.dependencies[]?.name // empty' "$$info")
		if [ -n "$$deps" ]; then
			while IFS= read -r dep; do
				if ! grep -qxF "$$dep" "$$names_file"; then
					echo "MISSING DEPENDENCY: '$$mod_name' requires '$$dep', which isn't present in this checkout"
					ok=0
				fi
			done <<< "$$deps"
		fi
	done
	rm -f "$$names_file"
	if [ "$$ok" -ne 1 ]; then
		exit 1
	fi
	echo "All module dependencies satisfied."

# Copies base/ and every modules/<Name>/ into the game's r6/scripts (the
# standalone redscript auto-compile-at-launch path -- NOT REDmod's own
# mods/ + redmod.exe deploy pipeline, which reports success without ever
# actually updating the compiled script cache; see README). Each module
# under modules/ is deployed independently and in a loop, so adding a new
# module folder needs no Makefile change.
deploy: check-deps
	rm -rf "$(DEST_ROOT)/base"
	mkdir -p "$(DEST_ROOT)/base"
	cp -r "$(BASE_DIR)/." "$(DEST_ROOT)/base/"
	echo "Deployed $(BASE_DIR) -> $(DEST_ROOT)/base"
	for mod_dir in $(MODULES_DIR)/*/; do
		name=$$(basename "$$mod_dir")
		rm -rf "$(DEST_ROOT)/modules/$$name"
		mkdir -p "$(DEST_ROOT)/modules/$$name"
		cp -r "$${mod_dir}." "$(DEST_ROOT)/modules/$$name/"
		echo "Deployed module $$name -> $(DEST_ROOT)/modules/$$name"
	done

clean-deploy:
	rm -rf "$(DEST_ROOT)/base" "$(DEST_ROOT)/modules"

paths-file:
	mkdir -p "$(SCRATCH_DIR)"
	rm -f "$(PATHS_FILE)"
	for f in $(CODEWARE_FILES); do
		echo "z:$(CODEWARE_SCRIPTS_DIR)/$$f" >> "$(PATHS_FILE)"
	done

# Deploys, then compiles via the standalone redscript compiler
# (engine/tools/scc.exe -- NOT REDmod's own bundled scc.exe, which has a
# separate, genuine bug under Wine that makes it report "no script files
# found"). Any blocking "Compilation error" dialog is auto-dismissed from
# the host X session (must run outside any flatpak sandbox, or xdotool
# can't see the window) so this never hangs waiting for a click.
compile: deploy paths-file
	rm -f "$(COMPILE_LOG)"
	$(PROTONTRICKS) -c "cd '$(GAME_DIR)' && wine engine/tools/scc.exe -compile r6/scripts -compilePathsFile _scratch/paths_win.txt -outputCacheFile _scratch/test.redscripts r6/cache/final.redscripts" $(APP_ID) > "$(COMPILE_LOG)" 2>&1 &
	COMPILE_PID=$$!
	export DISPLAY=:0
	for i in $$(seq 1 40); do
		WIN=$$(xdotool search --name "Compilation error" 2>/dev/null | head -1)
		if [ -n "$$WIN" ]; then
			xdotool windowactivate --sync "$$WIN"
			xdotool key Return
		fi
		if grep -qE "Compilation complete|\[ERROR" "$(COMPILE_LOG)" 2>/dev/null; then
			break
		fi
		sleep 1
	done
	wait $$COMPILE_PID 2>/dev/null
	cat "$(COMPILE_LOG)"
	if grep -q "\[ERROR" "$(COMPILE_LOG)"; then
		echo "COMPILE FAILED"
		exit 1
	else
		echo "COMPILE OK"
	fi
