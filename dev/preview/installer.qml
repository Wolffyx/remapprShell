// The installer's pages, one per render: PREVIEW_STEP=0..5 picks the page,
// and page 5 is shown part-way through an install.
import QtQuick
import Quickshell
import qs.domain.theme
import qs.features.installer

Rectangle {
    color: Theme.background

    InstallerView {
        id: view
        anchors.fill: parent
        step: Number(Quickshell.env("PREVIEW_STEP") || 0)
        Component.onCompleted: {
            if (view.step === 5) {
                view.tasks = [
                    { label: "restore point", state: "done" },
                    { label: "installing", state: "done" },
                    { label: "the window list", state: "done" },
                    { label: "window previews and the key module", state: "running" }
                ];
                view.log = "==> installing\n  copy  ~/.config/quickshell/<the shell>\n==> the window list is running\n-- Configuring done\n";
            }
        }
    }
}
