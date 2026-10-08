pragma Singleton

// GENERATED FILE -- DO NOT EDIT.
// Source: branding.json, VERSION          Regenerate: scripts/gen-branding.sh
//
// The project name is a variable, not a constant. Nothing outside this file
// and branding.json may contain the literal slug; scripts/lint-slug.sh enforces it.
//
// Committed, and identity only: nothing here depends on the machine. Where
// this machine keeps things is core/Paths.qml.

import QtQuick

QtObject {
    readonly property string slug: "remappr-shell"
    readonly property string shortName: "rmpr"
    readonly property string displayName: "Remappr Shell"
    readonly property string appId: "com.remappr.shell"
    readonly property string dbusName: "com.remappr.Shell"
    readonly property string envPrefix: "REMAPPR_SHELL"
    readonly property string shellPackageId: "remappr-shell.desktop"
    readonly property string version: "0.2.0"

    // The control binary's name. Where it is installed is Paths.ctlBin.
    readonly property string ctlName: "remappr-shell-ctl"

    readonly property string safeModeVar: "REMAPPR_SHELL_SAFE_MODE"
    readonly property string debugVar: "REMAPPR_SHELL_DEBUG"
}
