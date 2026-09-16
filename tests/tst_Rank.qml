// Tests for how a search result is scored: the match, and what a history of
// opening the thing is worth.

import QtQuick
import QtTest
import qs.domain.launcher.apps

TestCase {
    name: "Rank"

    function fields(name, generic, keywords, exec, id) {
        return { name: name, generic: generic ?? "", keywords: keywords ?? "",
                 exec: exec ?? "", id: id ?? "" };
    }

    readonly property var code: fields("Visual Studio Code", "Code Editing", "vscode ide",
                                       "/usr/bin/code --unity-launch %F", "code")
    readonly property var kate: fields("Kate", "Advanced Text Editor", "text editor",
                                       "kate -b %U", "org.kde.kate")
    readonly property var firefox: fields("Firefox", "Web Browser", "internet www browser",
                                          "/usr/lib/firefox/firefox %u", "firefox")
    readonly property var settings: fields("System Settings", "Configuration Tools", "preferences",
                                           "systemsettings", "systemsettings")

    function test_nothing_typed_matches_nothing() {
        compare(Rank.score("", kate), Rank.none);
        compare(Rank.score("   ", kate), Rank.none);
    }

    function test_the_classes_are_ordered() {
        verify(Rank.score("kate", kate) > Rank.score("kat", kate));          // exact over prefix
        verify(Rank.score("studio", code) > Rank.score("ual", code));        // a word over the middle
        verify(Rank.score("vsc", code) > Rank.score("ual", code));           // initials over the middle
        verify(Rank.score("ual", code) > Rank.score("editing", code));       // the name over the generic
        verify(Rank.score("editing", code) > Rank.score("ide", code));       // the generic over a keyword
    }

    function test_an_acronym_finds_a_long_name() {
        verify(Rank.score("vsc", code) > Rank.none);
        verify(Rank.score("ss", settings) > Rank.none);
        // Initials in the wrong order are neither an acronym nor a
        // subsequence: there is no "s" after the "c" of Code.
        compare(Rank.score("csv", code), Rank.none);
        compare(Rank.score("zzz", code), Rank.none);
    }

    function test_a_word_in_the_middle_is_found() {
        verify(Rank.score("code", code) > Rank.none);
        verify(Rank.score("settings", settings) > Rank.none);
    }

    function test_the_binary_is_matched() {
        // Nothing in the name, the generic name or the keywords says
        // "systemsettings"; the exec does.
        const onlyExec = fields("System Settings", "Configuration Tools", "preferences",
                                "/usr/bin/systemsettings", "");
        verify(Rank.score("systemsettings", onlyExec) > Rank.none);
        // A flag in the exec is not the program's name: "unity" must find
        // nothing here, though --unity-launch is in Code's Exec line.
        compare(Rank.score("unity", code), Rank.none);
        // Nor is a field code.
        compare(Rank.score("%f", code), Rank.none);
    }

    function test_the_letters_in_order_are_the_last_resort() {
        const fox = Rank.score("fox", firefox);          // f-i-r-e-f-o-x
        verify(fox > Rank.none);
        verify(fox < Rank.score("fire", firefox));       // a prefix beats it
        compare(Rank.score("xof", firefox), Rank.none);  // out of order is not a match
    }

    function test_every_word_has_to_match() {
        verify(Rank.score("visual code", code) > Rank.none);
        compare(Rank.score("visual banana", code), Rank.none);
        // More words may only narrow: the pair is worth its weakest half.
        compare(Rank.score("visual code", code) <= Rank.score("visual", code), true);
    }

    function test_a_shorter_name_wins_a_tie() {
        const kwrite = fields("KWrite", "Text Editor", "", "kwrite", "org.kde.kwrite");
        const longer = fields("KWrite Document Viewer Companion", "Text Editor", "", "kwrite2", "x");
        verify(Rank.score("kw", kwrite) > Rank.score("kw", longer));
    }

    // --- what a history is worth ------------------------------------------

    readonly property real day: 86400000

    function test_no_history_is_worth_nothing() {
        compare(Rank.recency(0, 0, Date.now()), 0);
        compare(Rank.recency(undefined, undefined, Date.now()), 0);
        compare(Rank.recency(5, 0, Date.now()), 0);
    }

    function test_more_uses_are_worth_more() {
        const now = Date.now();
        verify(Rank.recency(5, now, now) > Rank.recency(1, now, now));
        // Logarithmic: the hundredth use adds almost nothing over the fiftieth.
        verify(Rank.recency(100, now, now) - Rank.recency(50, now, now) <
               Rank.recency(4, now, now) - Rank.recency(1, now, now));
    }

    function test_a_use_decays() {
        const now = Date.now();
        const fresh = Rank.recency(4, now, now);
        const old = Rank.recency(4, now - 21 * day, now);      // one half-life
        const ancient = Rank.recency(4, now - 120 * day, now);
        verify(old < fresh);
        verify(ancient < old);
    }

    function test_a_history_is_capped() {
        const now = Date.now();
        verify(Rank.recency(100000, now, now) <= Rank.recencyMax);
    }

    function test_a_history_never_jumps_a_class() {
        const now = Date.now();
        const used = { uses: 100000, lastMs: now };
        // Kate, opened all day every day, still does not outrank an exact
        // match on something never opened at all.
        const kateOnPrefix = Rank.rank("kat", kate, used, now);
        const exactUnused = Rank.rank("firefox", firefox, null, now);
        verify(exactUnused > kateOnPrefix);
        // But it does outrank the same class with no history.
        verify(kateOnPrefix > Rank.rank("kat", kate, null, now));
    }

    function test_a_history_does_not_invent_a_match() {
        const now = Date.now();
        compare(Rank.rank("banana", kate, { uses: 500, lastMs: now }, now), Rank.none);
    }

    // --- what this machine would say --------------------------------------

    function test_a_history_beats_a_default() {
        const now = Date.now();
        const used = { uses: 1000, lastMs: now };
        verify(Rank.recencyMax > Rank.preferredBonus);
        // Both together still cannot lift a result past its class.
        verify(Rank.recencyMax + Rank.preferredBonus < Rank.wordPrefix - Rank.acronym);

        const preferred = Object.assign({}, kate, { preferred: true });
        verify(Rank.rank("kat", preferred, used, now) > Rank.rank("kat", kate, null, now));
        verify(Rank.rank("kat", kate, used, now) > Rank.rank("kat", preferred, null, now));
    }

    function test_pinning_is_not_a_score() {
        // It is a sort key, and Results owns it: the score of a pinned thing
        // is the score of the same thing unpinned.
        const now = Date.now();
        const pinned = Object.assign({}, kate, { pinned: true });
        compare(Rank.rank("kat", pinned, null, now), Rank.rank("kat", kate, null, now));
    }

    function test_the_default_terminal_is_the_first_terminal() {
        // Eight terminals, none ever opened: the one the system runs commands
        // in is the one that should be offered first.
        const now = Date.now();
        const alacritty = fields("Alacritty", "Terminal", "", "alacritty", "Alacritty");
        const konsole = Object.assign(fields("Konsole", "Terminal", "", "konsole", "org.kde.konsole"),
                                      { preferred: true });
        verify(Rank.rank("terminal", konsole, null, now) > Rank.rank("terminal", alacritty, null, now));
    }

    function test_prose_is_never_matched_loosely() {
        // A window title is a sentence its application wrote. Its own words
        // still match; its letters do not.
        const title = Object.assign(fields("Shijima - Google Chrome"), { prose: true });
        compare(Rank.score("image", title), Rank.none);
        verify(Rank.score("chrome", title) > Rank.none);
    }

    function test_letters_scattered_through_a_sentence_are_not_a_match() {
        // The bug this gate exists for: a browser window whose title happened
        // to contain t-e-r-m-i-n-a-l in order, under a search for terminals.
        const title = fields("He Is The Only One Who Can Use GOD-TIER Martial Arts And Gods BEG To Learn");
        compare(Rank.score("terminal", title), Rank.none);
        // Nor through a name that merely happens to be long enough.
        compare(Rank.score("image", fields("SchedExt GUI Manager")), Rank.none);
        // A name short enough for the letters to mean something still matches.
        verify(Rank.score("fox", firefox) > Rank.none);
    }
}
