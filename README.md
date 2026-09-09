# Remappr Shell

A configurable, themeable desktop shell for KDE Plasma 6.

**This is not a Hyprland alternative.** Plasma already has a notification daemon, an OSD,
a lock screen, a wallpaper engine, an overview and a task switcher. Remappr Shell's job is
to draw a good panel, *retheme* Plasma's own components, and *expose* Plasma's settings —
not to replace subsystems that already work. Every replacement is opt-in and never the
default.

> Status: early. Phase 0 (skeleton) is in place — the shell starts and draws a panel on
> every monitor. It is not yet useful as a daily driver.

## What it aims to be

- **One panel, two renderers.** A Quickshell layer-shell panel (default, total visual
  freedom) or a native Plasma panel generated from the same configuration — selectable in
  settings, and mutually exclusive so two panels can never overlap.
- **Pluggable launcher and search.** Kickoff, KRunner, a built-in launcher, rofi, fuzzel or
  a custom command, chosen at runtime.
- **Configurable everywhere.** A sparse JSON config with live reload, layered as
  defaults → profile → per-monitor, plus an in-shell settings GUI generated from the schema.
- **Widget plugins.** Drop a directory with a `widget.json` and a QML file into the widgets
  path; no core code changes.
- **Reversible.** Every change to KDE configuration is recorded in a ledger with its prior
  value, and `rmpr restore` puts it back.

## Requirements

- KDE Plasma 6, Wayland
- `quickshell`, `qt6-declarative`, `jq`

## Development

```bash
make link     # symlink into ~/.config/quickshell/<slug>; edits are live
make run      # run in the foreground against the working tree
make lint     # slug, layer and QML lints
make test     # QML tests, plus shell tests in a throwaway HOME
make uninstall
```

`make help` lists every target.

### Command line

```bash
rmpr preflight          # what would change, and whether this machine is ready
rmpr snapshot create    # take a restore point now
rmpr snapshot list      # what exists, with sizes
rmpr restore            # put KDE back the way it was
rmpr theme apply        # install and activate the look and feel
rmpr status
```

### Restore points are never deleted automatically

Not on restore, not on uninstall, not to reclaim space, not to prune old ones.
A restore point the software may delete by itself is not a restore point, and
an early version of the restore code proved the point by deleting its own
archive mid-restore and taking a user's configuration with it.

They are removed only when asked:

```bash
rmpr snapshot remove <name>   # delete one, after confirming
rmpr snapshot prune --keep 5  # delete all but the newest N, after confirming
```

Both prompt first. Every delete path in the codebase goes through a guard that
refuses to touch anything inside the snapshot store, so the rule holds even if
a future call site forgets it.

### Changing KDE settings

Every key this project writes is recorded with its prior state first, including
whether the key existed at all, so `revert` restores exactly what was there.
Anything outside `scripts/lib/protected.sh` is never touched, and restore never
deletes a file it did not create -- a restore that leaves an extra file behind
is a nuisance, one that deletes the wrong file is not recoverable.

Destructive code is tested against a throwaway `HOME`, never a real one.

### Project name

The name is a variable, not a constant. `branding.json` is the only place it exists;
`shell/core/Branding.qml` is generated from it and `scripts/lint-slug.sh` fails the build if
the slug is hardcoded anywhere else.

### Code layout

A strict dependency ladder, enforced by `scripts/lint-layers.sh`. A layer may import from
layers below it, never sideways and never up.

| Layer | May import | Contains |
| --- | --- | --- |
| `core/` | — | primitives with no dependencies |
| `platform/` | core | KDE, Wayland and system integration |
| `domain/` | core, platform | headless logic, no visuals |
| `ui/` | core, platform, domain | presentation only, no side effects |
| `features/` | all of the above | self-contained vertical slices |

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).

This project is written from scratch. It takes no code from other shells.
