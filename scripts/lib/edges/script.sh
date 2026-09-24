# shellcheck shell=bash
# This shell's own screen edges, which KWin's cannot be: a KWin script of our
# own, its bindings in kwinrc, and the two commands that set them.
#
# Sourced by edges.sh, never executed. Requires brand.sh, log.sh, kconfig.sh,
# accel.sh, kwin.sh, render.sh and config.sh -- and borders.sh, for the names
# of the edges.
#
# borders.sh configures KWin's edges, which run KWin's actions: the
# overview, the desktop grid, KRunner. None of them can open a surface this
# shell draws, and no KWin setting makes them able to -- so a sidebar that
# appears when the pointer reaches the left of the screen needs an edge this
# project registers itself. `kwin/edges/` is that script.
#
# The bindings live in kwinrc, in the script's own group, so they are ledgered
# and `revert` puts them back with everything else. The script is re-rendered
# from them and reloaded on every change: a KWin script can only read its
# configuration through a KConfigXT file, and one setting in two places drifts.
EDGES_SCRIPT_SRC="$REPO_ROOT/kwin/edges"
EDGES_SCRIPT_DEST="$KWIN_SCRIPTS_DIR/$KWIN_EDGES_SCRIPT_ID"
EDGES_GROUP="Script-$KWIN_EDGES_SCRIPT_ID"

# The actions an edge can run: the shortcut actions, which is the same list a
# key can be bound to -- lib/accel.sh's, from the file the daemon that runs
# them is rendered from, so the two can never disagree about what exists.
shell_actions() { printf '%s\n' "${ACCEL_ACTIONS[@]}"; }

shell_bindings_raw() {
    kreadconfig6 --file kwinrc --group "$EDGES_GROUP" --key Bindings --default ''
}

# "left:sidebar,right:launcher" -> the JS array the script is rendered with.
shell_bindings_js() {
    local raw=$1 pair edge action idx out=""
    local IFS=','
    for pair in $raw; do
        [ -n "$pair" ] || continue
        edge=${pair%%:*}; action=${pair#*:}
        idx=$(edge_index "$edge") || continue
        out="$out[$idx,\"$action\"],"
    done
    printf '[%s]' "${out%,}"
}

shell_install() {
    local raw js
    raw=$(shell_bindings_raw)
    js=$(shell_bindings_js "$raw")
    EDGE_BINDINGS=$js kwin_script_render "$EDGES_SCRIPT_SRC" "$EDGES_SCRIPT_DEST" "the edge script"
}

shell_reload() {
    session_available || { log_info "not loading it now: no session"; return 0; }
    # Reloaded, not loaded: a re-render must not keep running the old bindings.
    kwin_script_reload "$KWIN_EDGES_SCRIPT_ID" "$EDGES_SCRIPT_DEST/contents/code/main.js"
}

shell_remove() {
    kwin_scripting unloadScript "$KWIN_EDGES_SCRIPT_ID" >/dev/null
    [ -d "$EDGES_SCRIPT_DEST" ] || return 0
    rm -rf "$EDGES_SCRIPT_DEST"
    log_step "removed $EDGES_SCRIPT_DEST"
}

edges_shell() {   # [<edge> <action|none>]
    local edge action raw kept local_ifs pair
    edge=${1:-}
    action=${2:-}

    if [ -z "$edge" ]; then
        raw=$(shell_bindings_raw)
        if [ -z "$raw" ]; then
            echo "nothing bound to an edge by this shell"
        else
            printf '%s\n' "$raw" | tr ',' '\n' | while IFS=: read -r e a; do
                [ -n "$e" ] || continue
                printf '  %-12s %s\n' "$e" "$a"
            done
        fi
        echo
        if kwin_plugin_enabled "$KWIN_EDGES_SCRIPT_ID"; then
            if kwin_script_loaded "$KWIN_EDGES_SCRIPT_ID"; then
                echo "the edge script is enabled and loaded"
            else
                echo "the edge script is enabled but KWin has not loaded it"
            fi
        else
            echo "the edge script is not enabled"
        fi
        echo
        echo "actions: $(shell_actions | tr '\n' ' ')"
        exit 0
    fi

    [ -n "$action" ] || die "usage: $ALIAS edges shell <edge> <action|none>"
    edge_index "$edge" >/dev/null \
        || die "unknown edge: $edge (one of: ${EDGE_NAMES[*]})"
    [ "$action" = none ] || shell_actions | grep -qxF "$action" \
        || die "unknown action: $action (one of: $(shell_actions | tr '\n' ' '))"

    # Rebuilt rather than appended to: an edge can run one action, and
    # setting it twice must replace rather than bind it twice over.
    raw=$(shell_bindings_raw)
    kept=""
    local_ifs=$IFS; IFS=','
    for pair in $raw; do
        [ -n "$pair" ] || continue
        [ "${pair%%:*}" = "$edge" ] && continue
        kept="$kept$pair,"
    done
    IFS=$local_ifs
    [ "$action" = none ] || kept="$kept$edge:$action,"
    kept=${kept%,}

    kconfig_set edges kwinrc "$EDGES_GROUP" Bindings "$kept"
    kconfig_set edges kwinrc Plugins "${KWIN_EDGES_SCRIPT_ID}Enabled" \
        "$([ -n "$kept" ] && printf 'true' || printf 'false')"

    if [ -z "$kept" ]; then
        shell_remove
        log_step "no edge is this shell's any more"
        exit 0
    fi

    shell_install || die "nothing was loaded"
    shell_reload
    kwin_script_check_loaded "$KWIN_EDGES_SCRIPT_ID" "the edge script" \
        && log_step "$edge -> $action"
}

# The sidebar draws down one side (sidebar.position) and is opened by an
# edge. Pushing the pointer into the right-hand edge and having a panel
# appear on the left is nobody's idea of following, so this moves the edge
# to the side the panel is on -- and does nothing at all when no edge is
# bound to the sidebar, because binding one is the user's decision, not
# a side effect of choosing a side.
#
# Called by hand, and by the shell itself when the setting changes.
edges_follow() {
    local want trigger raw have local_ifs pair
    want=Right
    [ "$(config_get '.sidebar.position' right)" = left ] && want=Left
    trigger=$(config_get '.sidebar.trigger' drag)

    raw=$(shell_bindings_raw)
    have=""
    local_ifs=$IFS; IFS=','
    for pair in $raw; do
        [ "${pair#*:}" = sidebar ] && have=${pair%%:*}
    done
    IFS=$local_ifs

    # The sidebar is pulled out by its own strip now (sidebar.trigger
    # "drag"), so KWin's edge would open it a second way -- on a pointer
    # that merely reaches the edge, which is the thing the strip exists to
    # stop. Choosing anything but "hover" gives the edge back.
    if [ "$trigger" != hover ]; then
        if [ -n "$have" ]; then
            exec "$0" shell "$have" none
        fi
        log_info "sidebar.trigger is '$trigger'; no screen edge opens the sidebar"
        exit 0
    fi

    if [ -z "$have" ]; then
        log_info "sidebar.trigger is 'hover'; binding the $want edge"
        exec "$0" shell "$want" sidebar
    fi
    if [ "$have" = "$want" ]; then
        log_info "the sidebar's edge is already $want"
        exit 0
    fi

    "$0" shell "$have" none >/dev/null || die "could not free the $have edge"
    exec "$0" shell "$want" sidebar
}
