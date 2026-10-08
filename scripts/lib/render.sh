# shellcheck shell=bash
# Renders a *.in template by replacing @VAR@ placeholders.
#
# Deliberately not envsubst: these templates are shell and QML, both of which
# use $VAR legitimately. A distinct @VAR@ marker means template substitution
# and the target language can never collide.
#
# An unresolved @VAR@ left in the output is a hard error -- a typo must fail
# loudly rather than silently render an empty string into a path.

RENDER_VARS=(SLUG ALIAS DISPLAY_NAME APP_ID DBUS_NAME ENV_PREFIX SHELL_PACKAGE_ID
             VERSION QS_CONFIG_DIR CONFIG_DIR DATA_DIR STATE_DIR BIN_DIR
             SESSION_BIN CTL_BIN SYSTEMD_UNIT SAFE_MODE_VAR DEBUG_VAR
             REPO_PUSH REPO_FETCH REPO_ROOT LNF_PACKAGE_ID LNF_DARK_PACKAGE_ID
             LNF_ID LNF_NAME LNF_VARIANT
             PLASMA_SHELL_PACKAGE_ID PLASMA_DESKTOPTHEME_DIR
             WINDOWSD_BIN KWIN_SCRIPT_ID KWIN_EDGES_SCRIPT_ID KWIN_SCRIPTS_DIR
             EDGE_BINDINGS
             SWITCHER_LAYOUT SWITCHER_SUFFIX SWITCHER_LABEL
             ACCEL_KEYCODES SHORTCUT_ACTIONS)

# Tables the session daemon shares with these scripts. Each is kept in one file
# under scripts/lib, which the scripts read, and is rendered into the daemon as
# a literal on one line -- the only shape a @VAR@ can take. Worked out once,
# the first time anything is rendered, rather than by everything that sources
# this file.
#
#   ACCEL_KEYCODES    keycodes.tsv as {name: Qt key code}; see lib/accel.sh
#   SHORTCUT_ACTIONS  shortcut-actions.tsv as {id: [name, [CLI arguments]]}
render_tables() {
    [ -n "${ACCEL_KEYCODES:-}" ] || ACCEL_KEYCODES=$(jq -R -s -c '
        [split("\n")[] | select(test("^[^\t]+\t[0-9]+$")) | split("\t")
         | {(.[0]): (.[1] | tonumber)}] | add // {}' "$REPO_ROOT/scripts/lib/keycodes.tsv") || return 1
    [ -n "${SHORTCUT_ACTIONS:-}" ] || SHORTCUT_ACTIONS=$(jq -R -s -c '
        [split("\n")[] | select(test("^[^#\t][^\t]*\t[^\t]+\t[^\t]+$")) | split("\t")
         | {(.[0]): [.[1], (.[2] | split(" "))]}] | add // {}' "$REPO_ROOT/scripts/lib/shortcut-actions.tsv") || return 1
}

# Paths under the home directory are rendered through it, not as this
# machine's: an installed file says "$HOME/.local/bin", not /home/<someone>/
# .local/bin (2026-10-08). What stands for the home directory depends on what
# reads the file, so each kind of template has its word for it:
#
#   *.sh.in, share/dbus/*  $HOME   every use is in double quotes, or in the
#                                  sh -c a D-Bus Exec= runs
#   *.py.in                ~       every use goes through os.path.expanduser
#   share/systemd/*        %h      systemd's specifier for the home directory
#
# Anything else -- a desktop entry, a QML file, a KWin script -- expands
# nothing, gets the absolute path, and its template must not need one.
# Rendered with the HOME it will run under; a path outside it stays absolute.
RENDER_HOME_PATHS=(QS_CONFIG_DIR CONFIG_DIR DATA_DIR STATE_DIR BIN_DIR REPO_ROOT)

render_home_word() {   # <template>: the word for the home directory in it
    case "$1" in
        *.sh.in|share/dbus/*.in|*/share/dbus/*.in) printf '%s' '$HOME' ;;
        *.py.in)                                   printf '%s' '~' ;;
        share/systemd/*.in|*/share/systemd/*.in)   printf '%s' '%h' ;;
    esac
}

render_template() {
    local src=$1 dest=$2 tmp v val word
    render_tables || { log_error "could not read the tables $src may be rendered with"; return 1; }
    tmp=$(mktemp)

    local -A from_home=()
    word=$(render_home_word "$src")
    if [ -n "$word" ]; then
        for v in "${RENDER_HOME_PATHS[@]}"; do
            val=${!v-}
            [[ "$val" == "$HOME"/* ]] || continue
            from_home[$v]="$word/${val#"$HOME"/}"
        done
    fi

    local args=()
    for v in "${RENDER_VARS[@]}"; do
        # Escape the replacement for sed: \ & and the | delimiter are special.
        val=${from_home[$v]-${!v-}}
        val=${val//\\/\\\\}
        val=${val//&/\\&}
        val=${val//|/\\|}
        args+=(-e "s|@$v@|$val|g")
    done

    sed "${args[@]}" "$src" > "$tmp"

    if grep -qE '@[A-Z_]+@' "$tmp"; then
        log_error "unresolved placeholders in $src:"
        grep -oE '@[A-Z_]+@' "$tmp" | sort -u | sed 's/^/  /' >&2
        rm -f "$tmp"
        return 1
    fi

    mkdir -p "$(dirname "$dest")"
    mv "$tmp" "$dest"
    chmod 755 "$dest"
}

# render_package <src dir> <dest dir>: a directory of modules, rendered as one.
#
# Each *.in in it is rendered as render_template renders a file, the suffix
# dropped; everything else is copied as it is. The session daemon is the one
# user: a package of which only the module holding the install's names is a
# template, so a placeholder is written once rather than in every module.
# Modules rather than programs, so every file is left 644; whatever Python
# cached beside the sources is not a source, and is not copied.
render_package() {
    local src=$1 dest=$2 file rel out
    [ -d "$src" ] || { log_error "not a directory to render: $src"; return 1; }
    mkdir -p "$dest" || return 1
    while IFS= read -r -d '' file; do
        rel=${file#"$src"/}
        out=$dest/${rel%.in}
        mkdir -p "$(dirname "$out")" || return 1
        case "$rel" in
            *.in) render_template "$file" "$out" || return 1 ;;
            *)    cp "$file" "$out" || return 1 ;;
        esac
        chmod 644 "$out"
    done < <(find "$src" -type f -not -path '*/__pycache__/*' -not -name '*.pyc' -print0 | sort -z)
}
