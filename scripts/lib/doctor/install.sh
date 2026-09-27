# shellcheck shell=bash
# The install: every path the manifest puts in place, and the command on PATH.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh.

doctor_install() {
    local missing kind src dest
    section "install"

    missing=0
    while IFS='|' read -r kind src dest; do
        [ -n "$kind" ] || continue
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            continue
        fi
        bad "missing: $dest"
        missing=$((missing + 1))
    done < <(source "$REPO_ROOT/scripts/lib/manifest.sh"; manifest_entries)

    if [ "$missing" -eq 0 ]; then
        ok "every installed path is present"
    else
        fix "run: make link   (or make install)"
    fi

    case ":$PATH:" in
        *":$BIN_DIR:"*) ok "$BIN_DIR is on PATH" ;;
        *) warn "$BIN_DIR is not on PATH"
           fix "add it, or run $BIN_DIR/$CTL_BIN by full path" ;;
    esac
}
