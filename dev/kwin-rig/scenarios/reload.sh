# A declarative script reloaded runs its new code: dev/kwin-rig/run.sh scenarios/reload.sh
#
# KWin compiles a QML file once per path and keeps it for as long as it runs,
# so a script unloaded and loaded again from the same path runs what it had
# before. kwin_declarative_reload (scripts/lib/kwin.sh) loads a copy named by
# its content instead, and this is the proof that it works: the installed
# package is changed, reloaded both ways, and only the copy says so. The
# change is a warning in Picker.qml's listen(), which runs once a load.

load kwin/snap
id=$KWIN_SNAP_SCRIPT_ID
ui=$XDG_DATA_HOME/kwin/scripts/$id/contents/ui
marks() { grep -ac "reload-mark" "$RUN/kwin.log"; }

sed -i 's|function listen() {|function listen() {\n        console.warn("reload-mark");|' "$ui/Picker.qml"

scripting unloadScript "$id" >/dev/null
scripting loadDeclarativeScript "$ui/main.qml" "$id" >/dev/null
scripting start >/dev/null
sleep 1
check "loaded again from the same path, the old code runs" "$(marks)" "0"

kwin_declarative_reload "$id" "$ui/main.qml"
sleep 1
check "reloaded from a copy, the new code runs" "$(marks)" "1"
check "and KWin has it loaded" "$(scripting isScriptLoaded "$id")" "true"
copies() { find "$KWIN_LOAD_DIR" -mindepth 1 -maxdepth 1 -name "$id-*" -printf '%f\n'; }
first=$(copies)
check "one copy kept" "$(copies | wc -l)" "1"

kwin_declarative_reload "$id" "$ui/main.qml"
sleep 1
check "the same code again loads from the same copy" "$(copies)" "$first"
check "and runs again" "$(marks)" "2"
