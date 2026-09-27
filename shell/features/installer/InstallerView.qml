pragma ComponentBehavior: Bound

// The installer, inside whatever window holds it: the steps along the top,
// the page for the one in hand, Back and Next along the bottom.
//
// It asks, and scripts/setup.sh does: every answer is handed to setup.sh as a
// flag (InstallerEvents.setupArgs), so the window and the terminal apply
// exactly the same install, and nothing here reimplements a step of it.
//
// setup.sh is started on its own (setsid) with its output in a file under
// $XDG_RUNTIME_DIR, and this follows the file. Closing the window then leaves
// the install to finish instead of killing it halfway -- a half-applied
// install is the one outcome worse than either.
//
// An Item rather than the window itself, so dev/preview can draw any page of
// it offscreen.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.installer
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Item {
    id: root

    signal closeRequested

    readonly property var stepNames: ["Check", "Panel", "Keys", "Look", "Review", "Install"]
    readonly property int installStep: 5
    property int step: 0

    // The source the scripts are run from: named by setup.sh, which started
    // this window; otherwise the tree this window runs in. dev/preview names
    // it too, since the shell it draws from is a copy with no scripts beside it.
    readonly property string repo: Quickshell.env(`${Branding.envPrefix}_INSTALLER_SOURCE`) || `${Quickshell.shellDir}/..`
    readonly property string logFile: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/${Branding.slug}-install.log`

    property var keys: []
    property var answers: InstallerEvents.defaults([])

    property bool checking: true
    property bool passed: false
    property string plasma: ""
    property var buildMissing: []
    property string report: ""

    property var tasks: []
    property int failures: -1
    property string log: ""
    readonly property bool installing: root.step === root.installStep && root.failures < 0

    function answer(key, value) {
        const next = Object.assign({}, root.answers);
        next[key] = value;
        root.answers = next;
    }

    function install() {
        root.step = root.installStep;
        root.tasks = [];
        root.log = "";
        const extra = (Quickshell.env(`${Branding.envPrefix}_SETUP_EXTRA`) || "").split(" ").filter(s => s.length > 0);
        runner.command = ["sh", "-c", 'log=$1; shift; rm -f "$log"; setsid -f sh -c \'"$0" "$@"; echo "::exit $?"\' "$@" > "$log" 2>&1',
                          "sh", root.logFile, `${root.repo}/scripts/setup.sh`]
                         .concat(InstallerEvents.setupArgs(root.answers)).concat(extra);
        runner.running = true;
    }

    Component.onCompleted: {
        describe.running = true;
        preflight.running = true;
        buildDeps.running = true;
    }

    // ---- what the scripts say ----------------------------------------------

    readonly property Process _describe: Process {
        id: describe
        command: [`${root.repo}/scripts/setup.sh`, "--describe"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keys = JSON.parse(text).keys;
                    root.answers = Object.assign({}, root.answers, { keys: InstallerEvents.defaults(root.keys).keys });
                } catch (e) {
                    Log.warn("installer", `setup.sh --describe: ${e}`);
                }
            }
        }
    }

    // Its exit status as a line of its own: Process.exited carries a
    // QProcess::ExitStatus QML cannot name (see DbusWatch), so the code is
    // read from the output instead.
    readonly property Process _preflight: Process {
        id: preflight
        command: ["sh", "-c", '"$0" 2>&1; echo "::rc $?"', `${root.repo}/scripts/preflight.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                const rc = /^::rc (\d+)$/m.exec(text);
                root.report = text.replace(/^::rc \d+\n?/m, "").replace(/\x1b\[[0-9;]*m/g, "");
                const m = /plasmashell\s+([0-9.]+)/.exec(text);
                if (m)
                    root.plasma = m[1];
                root.passed = rc !== null && rc[1] === "0";
                root.checking = false;
            }
        }
    }

    readonly property Process _buildDeps: Process {
        id: buildDeps
        command: [`${root.repo}/scripts/deps.sh`, "check", "--build"]
        stdout: StdioCollector {
            onStreamFinished: root.buildMissing = text.split("\n").filter(s => s.length > 0)
        }
    }

    // Starts setup.sh on its own and returns at once; `tail` follows it.
    readonly property Process _runner: Process {
        id: runner
        onRunningChanged: if (!running) follow.running = true
    }

    readonly property Process _follow: Process {
        id: follow
        command: ["tail", "-n", "+1", "-F", root.logFile]
        stdout: SplitParser {
            onRead: line => {
                const ev = InstallerEvents.parse(line);
                if (!ev) {
                    root.log += line.replace(/\x1b\[[0-9;]*m/g, "") + "\n";
                    return;
                }
                if (ev.kind === "done") {
                    root.failures = InstallerEvents.failures(ev);
                } else if (ev.kind === "exit") {
                    // setup.sh has ended. Without a ::done before it, it
                    // stopped early -- which is a failure however few steps
                    // it got to.
                    if (root.failures < 0)
                        root.failures = Math.max(1, root.tasks.filter(t => t.state === "failed").length);
                    follow.running = false;
                } else {
                    root.tasks = InstallerEvents.apply(root.tasks, ev);
                }
            }
        }
    }

    // ---- the window --------------------------------------------------------

    Column {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 28
        spacing: 22

        Row {
            spacing: 12
            Glyph { name: "deployed_code"; fallback: "system-software-install"; size: 30; color: Theme.acc; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                PanelText { text: `Install ${Branding.displayName}`; font.pixelSize: 22; font.bold: true }
                PanelText { text: `Version ${Branding.version}`; font.pixelSize: 12; color: Theme.mut }
            }
        }

        Stepper {
            width: parent.width
            steps: root.stepNames
            current: root.failures >= 0 ? root.stepNames.length : root.step
            navigable: !root.installing && root.step < root.installStep
            onStepClicked: index => root.step = index
        }
    }

    Flickable {
        id: body
        anchors.top: head.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: foot.top
        anchors.bottomMargin: 16
        contentHeight: pages.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: pages
            x: 28
            width: body.width - 56

            InstallerCheckStep {
                visible: root.step === 0
                width: parent.width
                checking: root.checking
                passed: root.passed
                plasma: root.plasma
                buildMissing: root.buildMissing
                report: root.report
            }
            InstallerPanelStep {
                visible: root.step === 1
                width: parent.width
                answers: root.answers
                onAnswered: (key, value) => root.answer(key, value)
            }
            InstallerKeysStep {
                visible: root.step === 2
                width: parent.width
                answers: root.answers
                keys: root.keys
                onAnswered: (key, value) => root.answer(key, value)
            }
            InstallerLookStep {
                visible: root.step === 3
                width: parent.width
                answers: root.answers
                needsBuildTools: root.buildMissing.length > 0
                onAnswered: (key, value) => root.answer(key, value)
            }
            InstallerReviewStep {
                visible: root.step === 4
                width: parent.width
                answers: root.answers
                keys: root.keys
                onAnswered: (key, value) => root.answer(key, value)
                onJump: index => root.step = index
            }
            InstallerProgressStep {
                visible: root.step === root.installStep
                width: parent.width
                tasks: root.tasks
                failures: root.failures
                log: root.log
            }
        }
    }

    // What the whole window is as tall as it wants to be: the head, the page
    // and the foot. The window takes this, up to what the screen allows.
    readonly property real wantedHeight: head.implicitHeight + 28 + 20 + pages.implicitHeight + 16 + foot.height + 24

    Item {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        height: 36

        TextButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.installing && root.failures < 0
            text: "Cancel"
            onActivated: root.closeRequested()
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            TextButton {
                visible: root.step > 0 && root.step < root.installStep
                text: "Back"
                onActivated: root.step--
            }

            TextButton {
                visible: root.step < root.installStep
                primary: true
                enabled: root.step !== 0 || !root.checking
                text: root.step === root.installStep - 1 ? "Install"
                    : root.step === 0 && !root.checking && !root.passed ? "Continue anyway"
                    : "Next"
                onActivated: {
                    if (root.step === root.installStep - 1)
                        root.install();
                    else
                        root.step++;
                }
            }

            TextButton {
                visible: root.step === root.installStep && root.failures >= 0
                primary: true
                text: "Close"
                onActivated: root.closeRequested()
            }
        }
    }
}
