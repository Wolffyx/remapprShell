pragma ComponentBehavior: Bound

// The taskbar's popout: one card, two contents -- a button's menu (TaskMenu)
// after a right click, or the preview (TaskPreview) while the pointer rests
// on a button. The menu and the preview only say what was chosen; this does
// it, through the widget.

import QtQuick
import qs.domain.config
import qs.domain.windows
import qs.domain.windows.events

Item {
    id: card

    // The tasks widget: which of the two is showing and what it is about, and
    // the popout that choosing from either puts away.
    required property var taskbar

    // The loaded contents are Items; the linter only knows they are QObjects,
    // so they are read through a typed alias.
    readonly property Item shownContent: (menuLoader.item ?? previewLoader.item) as Item

    // In menu mode the width is the widget's to state, not the menu's to work
    // out: the rows are as wide as the menu and the menu as wide as the card,
    // so asking the menu how wide it wants to be is a loop. The card's own
    // width is what breaks it.
    implicitWidth: card.taskbar.popoutMode === "menu" ? card.taskbar.menuWidth
                                                      : (card.shownContent?.implicitWidth ?? 1)
    implicitHeight: card.shownContent?.implicitHeight ?? 1

    Loader {
        id: menuLoader

        // The menu's rows are as wide as the menu, and the menu is as wide as
        // it is given: `popoutWidth` on the widget fixes the card at 262 and
        // this Loader is what passes that on. Without a width here every row
        // laid out 0 wide inside a card the right size, which is a right click
        // that does nothing at all.
        width: parent.width
        active: card.taskbar.popoutMode === "menu" && card.taskbar.menuItem !== null
        sourceComponent: TaskMenu {
            item: card.taskbar.menuItem
            entry: WindowsService.entryById(WindowEvents.appIdOf(card.taskbar.menuItem))
            pinned: card.taskbar.menuItem?.pinned === true

            onLaunch: action => {
                WindowsService.launch(WindowEvents.appIdOf(card.taskbar.menuItem), action);
                card.taskbar.popoutVisible = false;
            }
            onTogglePin: {
                ConfigStore.set("widgets.tasks.pinned",
                                WindowEvents.togglePinned(card.taskbar.pinned, WindowEvents.appIdOf(card.taskbar.menuItem)));
                card.taskbar.popoutVisible = false;
            }
            onCloseWindows: {
                for (const w of card.taskbar.menuItem?.windows ?? [])
                    WindowsService.close(w.uuid);
                card.taskbar.popoutVisible = false;
            }
        }
    }

    // The preview.
    //
    // It shows a live picture of the window where the compositor gives one --
    // KWin's screencast protocol, through this project's one compiled part
    // (plugin/) -- and the application's icon where it does not.
    //
    // A group of several windows is a picture each, not a list of titles, and
    // every one of them is a target: hovering a grouped button and then being
    // unable to say which window you meant is the whole complaint against a
    // grouped taskbar, and "click to move through them" is an answer only for
    // somebody who already knows which one is next.
    //
    // The previous note here said a picture was impossible. It was wrong in an
    // instructive way: the protocol is restricted rather than absent, and KWin
    // gives it to a client whose desktop file asks for it by name.
    Loader {
        id: previewLoader
        active: card.taskbar.popoutMode !== "menu"
        sourceComponent: TaskPreview {
            item: card.taskbar.previewItem
            showHeader: card.taskbar.previewHeader
            showScreen: card.taskbar.previewScreen
            windows: item?.windows ?? []

            onPicked: card.taskbar.popoutVisible = false
        }
    }

    // The card is as tall as whichever is loaded. The menu's height is the sum
    // of its rows, which it only knows once it has a width.
}
