// The QML redaction, over the same corpus the shell implementation is held to.
//
// Two implementations of a privacy boundary is a drift risk worth taking -- the
// crash reporter has to work when the shell is dead -- but only if a rule
// changed in one and not the other fails a test. That is what this file and
// tests/test-redact.sh are for: one fixture, two runners.

import QtQuick
import QtTest
import qs.domain.diagnostics.redact

TestCase {
    id: root
    name: "Redact"

    property var fixtures: null

    function initTestCase() {
        const req = new XMLHttpRequest();
        req.open("GET", Qt.resolvedUrl("fixtures/redact-cases.json"), false);
        req.send(null);
        root.fixtures = JSON.parse(req.responseText);
        Redact.home = root.fixtures.home;
        Redact.user = root.fixtures.user;
    }

    // Sorted keys, so two objects that differ only in insertion order compare
    // equal -- the shell implementation goes through jq, which reorders.
    function canonical(value) {
        if (value === null || value === undefined)
            return "null";
        if (Array.isArray(value))
            return "[" + value.map(canonical).join(",") + "]";
        if (typeof value === "object")
            return "{" + Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonical(value[k])}`).join(",") + "}";
        return JSON.stringify(value);
    }

    function test_corpus() {
        verify(root.fixtures !== null, "fixtures did not load");
        verify(root.fixtures.cases.length > 0, "corpus is empty");

        for (const c of root.fixtures.cases) {
            const got = canonical(Redact.value(c.input));
            const want = canonical(c.expected);
            compare(got, want, c.name);
        }
    }

    // Called out separately from the corpus because it is the rule with the
    // most ways to go subtly wrong, and the one whose failure is silent.
    function test_home_is_replaced_before_the_username() {
        compare(Redact.text("/home/testuser/x"), "~/x");
    }

    function test_empty_home_redacts_nothing() {
        const home = Redact.home;
        Redact.home = "";
        compare(Redact.text("/home/testuser/x"), "/home/<user>/x");
        Redact.home = home;
    }

    function test_secret_key_detection() {
        verify(Redact.isSecret("apiToken"));
        verify(Redact.isSecret("PASSWORD"));
        verify(Redact.isSecret("auth"));
        verify(!Redact.isSecret("thickness"));
        verify(!Redact.isSecret("position"));
    }
}
