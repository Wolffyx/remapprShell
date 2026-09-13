// How the panel closes a widget's popout.
//
// The panel used to assign `popoutVisible = false` straight onto the widget.
// That works for the fourteen widgets that keep the flag as plain state, and
// it silently breaks the one that does not: assigning to a property replaces
// its binding with a constant, so the launcher's
//
//     popoutVisible: <the provider is open, here, in menu mode>
//
// became a permanent `false` the first time a click landed outside the start
// menu -- and the start button did nothing for the rest of the session. These
// tests hold the contract that replaced it: the panel *asks*, and a widget
// whose open state lives somewhere else answers by changing it there.

import QtQuick
import QtTest
import qs.ui.primitives

TestCase {
    name: "Popouts"

    // A widget of the ordinary kind: the flag is the state.
    component Plain: BarWidget {
        bar: null
        widgetConfig: ({})
        screenName: "TEST-1"
    }

    // A widget of the launcher's kind: the flag is a view of state held
    // elsewhere, and closing means changing that.
    component Bound: BarWidget {
        id: bound
        bar: null
        widgetConfig: ({})
        screenName: "TEST-1"

        property bool openElsewhere: false
        popoutVisible: bound.openElsewhere
        function closePopout() { bound.openElsewhere = false; }
    }

    Component { id: plainFactory; Plain {} }
    Component { id: boundFactory; Bound {} }

    function test_the_plain_case_still_just_clears_the_flag() {
        const w = createTemporaryObject(plainFactory, this);
        w.popoutVisible = true;
        w.closePopout();
        verify(!w.popoutVisible);
    }

    function test_a_widget_holding_its_state_elsewhere_closes_it_there() {
        const w = createTemporaryObject(boundFactory, this);
        w.openElsewhere = true;
        verify(w.popoutVisible);
        w.closePopout();
        verify(!w.openElsewhere);
        verify(!w.popoutVisible);
    }

    // The regression itself: after the panel has closed it once, opening it
    // again must still reach the widget. It did not, because the binding was
    // gone.
    function test_it_opens_again_after_the_panel_has_closed_it() {
        const w = createTemporaryObject(boundFactory, this);
        w.openElsewhere = true;
        w.closePopout();
        w.openElsewhere = true;
        verify(w.popoutVisible);
    }
}
