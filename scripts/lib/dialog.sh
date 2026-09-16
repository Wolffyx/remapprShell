# shellcheck shell=bash
# Asking a person a question, in whatever front end this machine has.
#
# Sourced, never executed. Requires log.sh and brand.sh already sourced.
#
# There are four front ends and one API. The point is that a guided install is
# the same script whether it is run from the desktop, from a TTY on a machine
# with no Plasma yet, over SSH, or from CI with nothing on the other end:
#
#   kdialog    a graphical session, and kdialog installed -- KDE's own dialogs
#   whiptail   a terminal (also `dialog`, whichever is there)
#   plain      a terminal with neither -- numbered prompts and `read`
#   none       nothing is attached: every question answers with its default
#
# `none` is what makes `--unattended` need no separate code path: the caller
# passes the same defaults either way, and this decides whether anybody is
# asked about them. The front end can be forced with <ENV_PREFIX>_UI, which is
# also how the tests drive this without a terminal.
#
# Every function prints its answer on stdout and nothing else: the prompts go
# to stderr (kdialog and whiptail draw on the terminal or the screen), so a
# caller may write `choice=$(ui_menu ...)` safely.
#
# Cancel is not "no". A question that was dismissed returns 2, and a setup
# stops rather than carrying on with the default -- somebody who presses Escape
# on "which renderer?" has not chosen the first one.

: "${DIALOG_UI:=}"

_ui_var="${ENV_PREFIX}_UI"

# Which front end to use. Decided once, then remembered: asking twice can give
# two answers when a session starts between the calls.
ui_backend() {
    [ -n "$DIALOG_UI" ] && { printf '%s' "$DIALOG_UI"; return; }

    local forced=${!_ui_var:-}
    case "$forced" in
        kdialog|whiptail|dialog|plain|none) DIALOG_UI=$forced ;;
        "") DIALOG_UI=$(_ui_detect) ;;
        *)  log_warn "unknown ${_ui_var} '$forced'; detecting instead"
            DIALOG_UI=$(_ui_detect) ;;
    esac
    printf '%s' "$DIALOG_UI"
}

_ui_detect() {
    if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v kdialog >/dev/null 2>&1; then
        printf 'kdialog'; return
    fi
    # A terminal on both ends: a prompt with no keyboard behind it hangs.
    if [ -t 0 ] && [ -t 2 ]; then
        command -v whiptail >/dev/null 2>&1 && { printf 'whiptail'; return; }
        command -v dialog   >/dev/null 2>&1 && { printf 'dialog';   return; }
        printf 'plain'; return
    fi
    printf 'none'
}

# Is anybody there? A caller that wants to skip a whole step rather than
# default it asks this.
ui_interactive() { [ "$(ui_backend)" != none ]; }

# --- primitives -----------------------------------------------------------

# The curses front ends want a size. One size, large enough for the longest
# thing this project asks, rather than a measurement per call site.
_UI_H=22; _UI_W=76; _UI_LIST=12

ui_info() {
    local title=$1 text=$2
    case "$(ui_backend)" in
        kdialog)          kdialog --title "$title" --msgbox "$text" ;;
        whiptail|dialog)  "$(ui_backend)" --title "$title" --msgbox "$text" $_UI_H $_UI_W ;;
        plain)            printf '\n%s\n%s\n' "$title" "$text" >&2 ;;
        none)             log_info "$title: $text" ;;
    esac
}

ui_error() {
    local text=$1
    case "$(ui_backend)" in
        kdialog)          kdialog --title "$DISPLAY_NAME" --error "$text" ;;
        whiptail|dialog)  "$(ui_backend)" --title "$DISPLAY_NAME" --msgbox "$text" $_UI_H $_UI_W ;;
        *)                log_error "$text" ;;
    esac
}

# ui_yesno <text> <default: yes|no>
#   0 yes   1 no   2 cancelled
ui_yesno() {
    local text=$1 default=${2:-yes} answer
    case "$(ui_backend)" in
        kdialog)
            # --yesno returns 0 for yes and 1 for no; there is no third
            # button, so a closed window is a no here and cannot be told
            # apart from one.
            if [ "$default" = yes ]; then
                kdialog --title "$DISPLAY_NAME" --yes-label Yes --no-label No --yesno "$text"
            else
                kdialog --title "$DISPLAY_NAME" --yes-label Yes --no-label No --warningyesno "$text"
            fi
            ;;
        whiptail|dialog)
            local defaultno=()
            [ "$default" = no ] && defaultno=(--defaultno)
            "$(ui_backend)" --title "$DISPLAY_NAME" "${defaultno[@]}" --yesno "$text" $_UI_H $_UI_W
            ;;
        plain)
            local hint='[Y/n]'; [ "$default" = no ] && hint='[y/N]'
            read -r -p "$text $hint " answer >&2 || return 2
            answer=${answer:-$default}
            case "${answer,,}" in y|yes) return 0 ;; n|no) return 1 ;; *) return 1 ;; esac
            ;;
        none)
            [ "$default" = yes ]
            ;;
    esac
}

# ui_menu <title> <text> <default-tag> <tag> <label> [<tag> <label> ...]
# Prints the chosen tag. Returns 2 when the question was dismissed.
ui_menu() {
    local title=$1 text=$2 default=$3; shift 3
    local -a pairs=("$@")
    local chosen rc

    case "$(ui_backend)" in
        kdialog)
            # kdialog takes the default as the initially selected tag.
            chosen=$(kdialog --title "$title" --default "$default" --menu "$text" "${pairs[@]}") || return 2
            ;;
        whiptail|dialog)
            chosen=$("$(ui_backend)" --title "$title" --default-item "$default" \
                     --menu "$text" $_UI_H $_UI_W $_UI_LIST "${pairs[@]}" 3>&1 1>&2 2>&3) || return 2
            ;;
        plain)
            local i=1 tag label answer
            printf '\n%s\n%s\n' "$title" "$text" >&2
            for ((i = 0; i < ${#pairs[@]}; i += 2)); do
                tag=${pairs[i]}; label=${pairs[i+1]}
                printf '  %2d) %-22s %s%s\n' $((i / 2 + 1)) "$tag" "$label" \
                       "$([ "$tag" = "$default" ] && printf '  (default)')" >&2
            done
            read -r -p "choice [$default]: " answer >&2 || return 2
            [ -z "$answer" ] && { printf '%s' "$default"; return 0; }
            # A number picks a row; anything else is taken as the tag itself,
            # because typing "quickshell" is what a person does.
            if [[ $answer =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le $((${#pairs[@]} / 2)) ]; then
                chosen=${pairs[$(((answer - 1) * 2))]}
            else
                chosen=$answer
            fi
            ;;
        none)
            chosen=$default
            ;;
    esac

    # Whatever the front end returned has to be one of the offered tags: a
    # typed answer, or a kdialog that was closed in a way that prints nothing.
    for ((rc = 0; rc < ${#pairs[@]}; rc += 2)); do
        [ "$chosen" = "${pairs[rc]}" ] && { printf '%s' "$chosen"; return 0; }
    done
    log_warn "no such choice: '${chosen}'"
    return 2
}

# ui_checklist <title> <text> <on-tags, space separated> <tag> <label> ...
# Prints the chosen tags, one per line.
ui_checklist() {
    local title=$1 text=$2 on=$3; shift 3
    local -a pairs=("$@") args=()
    local i tag label state chosen

    for ((i = 0; i < ${#pairs[@]}; i += 2)); do
        tag=${pairs[i]}; label=${pairs[i+1]}
        state=off
        printf '%s\n' $on | grep -qxF "$tag" && state=on
        args+=("$tag" "$label" "$state")
    done

    case "$(ui_backend)" in
        kdialog)
            chosen=$(kdialog --title "$title" --checklist "$text" "${args[@]}") || return 2
            # kdialog answers with quoted tags on one line.
            printf '%s\n' $chosen | tr -d '"'
            ;;
        whiptail|dialog)
            chosen=$("$(ui_backend)" --title "$title" --checklist "$text" \
                     $_UI_H $_UI_W $_UI_LIST "${args[@]}" 3>&1 1>&2 2>&3) || return 2
            printf '%s\n' $chosen | tr -d '"'
            ;;
        plain)
            printf '\n%s\n%s\n' "$title" "$text" >&2
            for ((i = 0; i < ${#pairs[@]}; i += 2)); do
                tag=${pairs[i]}; label=${pairs[i+1]}
                state=' '
                printf '%s\n' $on | grep -qxF "$tag" && state='x'
                printf '  [%s] %-22s %s\n' "$state" "$tag" "$label" >&2
            done
            read -r -p "tags to turn on, space separated [$on]: " chosen >&2 || return 2
            printf '%s\n' ${chosen:-$on}
            ;;
        none)
            printf '%s\n' $on
            ;;
    esac
    return 0
}

# ui_input <title> <text> <default>
ui_input() {
    local title=$1 text=$2 default=$3 answer
    case "$(ui_backend)" in
        kdialog)          answer=$(kdialog --title "$title" --inputbox "$text" "$default") || return 2 ;;
        whiptail|dialog)  answer=$("$(ui_backend)" --title "$title" --inputbox "$text" \
                                   $_UI_H $_UI_W "$default" 3>&1 1>&2 2>&3) || return 2 ;;
        plain)            read -r -p "$text [$default]: " answer >&2 || return 2 ;;
        none)             answer=$default ;;
    esac
    printf '%s' "${answer:-$default}"
}

# What a step is doing, where a graphical front end has no terminal to say it
# in. Never a dialog: a progress note nobody dismisses is worse than none.
ui_note() { log_step "$*"; }
