// Tests for what the first-run wizard writes, and what it draws while it is
// still being answered.
//
// The preview has to be what Finish would leave behind: a preset in place of
// the saved profile, never merged into it, and the answers on top of both.

import QtQuick
import QtTest
import qs.domain.wizard

TestCase {
    name: "WizardAnswers"

    readonly property var answers: ({ position: "top", thickness: 40, launcher: "builtin", ai: "off" })

    function test_every_answer_is_a_write() {
        const w = WizardAnswers.writes(answers);
        compare(w["panel.position"], "top");
        compare(w["panel.thickness"], 40);
        compare(w["launcher.provider"], "builtin");
        compare(w["ai.enabled"], false);
    }

    // "off" is not a provider, and must not replace the one chosen before.
    function test_no_assistant_leaves_the_provider_alone() {
        verify(!("ai.provider" in WizardAnswers.writes(answers)));
    }

    function test_an_assistant_is_turned_on_and_named() {
        const w = WizardAnswers.writes(Object.assign({}, answers, { ai: "claude-code" }));
        compare(w["ai.enabled"], true);
        compare(w["ai.provider"], "claude-code");
    }

    // The renderer and the theme change KDE's own settings; they wait for
    // Finish and are never drawn early.
    function test_nothing_outside_the_shell_is_previewed() {
        const w = WizardAnswers.writes(answers);
        for (const path of Object.keys(w))
            verify(!path.startsWith("theme.") && !path.startsWith("panel.renderer"), path);
    }

    function test_the_answers_go_on_the_saved_profile() {
        const saved = { panel: { position: "bottom", floating: true }, clock: { seconds: true } };
        const p = WizardAnswers.preview(saved, null, WizardAnswers.writes(answers));
        compare(p.panel.position, "top");
        compare(p.panel.thickness, 40);
        compare(p.panel.floating, true);
        compare(p.clock.seconds, true);
    }

    // A preset replaces the profile at Finish, so nothing of the saved one
    // may show through it in the preview.
    function test_a_preset_replaces_the_saved_profile() {
        const saved = { clock: { seconds: true }, panel: { floating: true } };
        const preset = { panel: { position: "left" }, bar: { entries: [{ id: "clock" }] } };
        const p = WizardAnswers.preview(saved, preset, {});
        compare(p.panel.position, "left");
        compare(p.bar.entries.length, 1);
        verify(!("clock" in p));
        verify(!("floating" in p.panel));
    }

    // The answers are written after the preset lands, so they win over it.
    function test_the_answers_win_over_a_preset() {
        const preset = { panel: { position: "left", thickness: 60 } };
        const p = WizardAnswers.preview({}, preset, WizardAnswers.writes(answers));
        compare(p.panel.position, "top");
        compare(p.panel.thickness, 40);
    }

    function test_nothing_handed_in_is_touched() {
        const saved = { panel: { position: "bottom" } };
        const preset = { panel: { position: "left" } };
        WizardAnswers.preview(saved, null, WizardAnswers.writes(answers));
        WizardAnswers.preview(saved, preset, WizardAnswers.writes(answers));
        compare(saved.panel.position, "bottom");
        compare(preset.panel.position, "left");
    }

    function test_an_empty_profile_is_a_preview_of_the_answers_alone() {
        const p = WizardAnswers.preview(undefined, null, { "panel.position": "right" });
        compare(JSON.stringify(p), JSON.stringify({ panel: { position: "right" } }));
    }
}
