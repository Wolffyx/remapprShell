pragma Singleton

// How a search result is scored.
//
// Pure, and a module of its own so the tests can load it -- like Actions
// beside it. Nothing here reads a file, opens a bus or draws.
//
// The old ranking was five buckets (exact, prefix, substring, generic,
// keyword) with ties broken alphabetically, which is why the list read as
// KRunner's with none of its learning: "s" put Settings above Spotify
// forever, whatever the person actually ran. Two things fix that, and both
// live here:
//
//   match    a continuous score rather than a bucket, so an acronym, a word
//            in the middle of a name and the binary's own name all find
//            something, and a better match always sorts above a worse one
//   recency  a weight from how often and how recently a thing was chosen,
//            added to the match -- what makes the second search for a thing
//            easier than the first
//
// Scores are numbers with no unit; only their order matters. They are spread
// far enough apart that a recency weight can lift a result within its class
// without ever jumping it over a whole class -- an exact name match is still
// the first row, however long ago it was last used.

import QtQuick

QtObject {
    id: root

    // The classes, a thousand apart -- which is more than every bonus below
    // can add together, so a bonus orders results of the same kind and can
    // never reorder the kinds themselves.
    readonly property int exact:      10000
    readonly property int prefix:      8000
    readonly property int wordPrefix:  7000
    readonly property int acronym:     6000
    readonly property int substring:   5000
    readonly property int execMatch:   4000
    readonly property int generic:     3000
    readonly property int keyword:     2000
    readonly property int fuzzy:       1000
    readonly property int none:          -1

    // The bonuses, largest first. They sum to less than the gap above, so a
    // bonus orders results of the same kind and never reorders the kinds.
    //
    //   recency    it has been opened lately
    //   preferred  the system opens this kind of thing with it
    //
    // Pinning is deliberately NOT here. A bonus cannot cross a class, so a
    // pinned text editor still sat below every application with "Editor" in
    // its name -- which is not what "pin it and it is first" means to the
    // person who pinned it. A pin is a sort key of its own, ahead of the
    // score entirely: see Results.byScore.
    readonly property int recencyMax:    250
    readonly property int preferredBonus: 150

    // A thing used once a day for a fortnight is as recommended as this gets;
    // past that the weight stops growing, so a terminal opened a thousand
    // times cannot bury everything else forever.
    readonly property real recencySaturation: 14

    // Half of the weight of a use is gone after this long. Short enough that
    // last month's project stops crowding out this one.
    readonly property int halfLifeDays: 21

    function _lower(value) {
        return String(value ?? "").toLowerCase();
    }

    // Words, for the word-prefix and acronym rules: "Visual Studio Code" ->
    // ["visual", "studio", "code"], and a hyphen or a dot is a break too, so
    // "7-Zip" and "org.kde.kate" both split the way a person reads them.
    function words(text) {
        return root._lower(text).split(/[\s\-_.:/]+/).filter(w => w.length > 0);
    }

    // The binary's own words, without what a desktop entry's Exec line
    // carries besides it. A flag is not the program's name -- matching them
    // made "unity" find Visual Studio Code, whose Exec has --unity-launch in
    // it -- and neither is a field code (%F, %u).
    function execWords(exec) {
        return String(exec ?? "").split(/\s+/)
            .filter(t => t.length > 0 && !t.startsWith("-") && !t.startsWith("%"))
            .reduce((out, token) => out.concat(root.words(token)), []);
    }

    // Is `q` spread through `text` in order? "vsc" is in "visual studio code";
    // "csv" is not. The last resort, and scored as one.
    function subsequence(text, q) {
        let i = 0;
        for (const ch of text) {
            if (ch === q[i])
                i++;
            if (i === q.length)
                return true;
        }
        return q.length === 0;
    }

    // What a candidate offers to be matched on. Every field is optional: a
    // window has no keywords, an action has no exec.
    //
    //   name     what is drawn, and what is matched hardest
    //   generic  the "Web Browser" under the name
    //   keywords whatever the desktop entry lists
    //   exec     the command, so typing the binary works ("nvim", "code")
    //   id       the desktop id, for the same reason
    //   prose    the name is a sentence, not a name: no loose matching
    function score(query, fields) {
        const q = root._lower(query).trim();
        if (q.length === 0)
            return root.none;

        // Several words: every one of them has to match something, and the
        // weakest is what the result is worth. Typing more words may only
        // ever narrow the list.
        const parts = q.split(/\s+/).filter(p => p.length > 0);
        if (parts.length > 1) {
            let worst = Infinity;
            for (const part of parts) {
                const s = root.score(part, fields);
                if (s === root.none)
                    return root.none;
                worst = Math.min(worst, s);
            }
            return worst;
        }

        const name = root._lower(fields?.name);
        const generic = root._lower(fields?.generic);
        const keywords = root._lower(fields?.keywords);
        const exec = root._lower(fields?.exec);
        const id = root._lower(fields?.id);

        if (name === q)
            return root.exact;
        if (name.startsWith(q))
            // Within the class, the shorter name wins: typing "ka" should
            // offer Kate before Kate's own helper with a longer name.
            return root.prefix + root._shortness(name);

        const nameWords = root.words(name);
        if (nameWords.some(w => w.startsWith(q)))
            return root.wordPrefix + root._shortness(name);

        // The initials, as anybody types a long name: "vsc", "ss".
        if (q.length >= 2 && nameWords.length >= 2) {
            const initials = nameWords.map(w => w[0]).join("");
            if (initials.startsWith(q))
                return root.acronym + root._shortness(name);
        }

        if (name.includes(q))
            return root.substring + root._shortness(name);

        // The binary, not the pretty name. `exec` carries flags and field
        // codes, so only its words are matched -- "code --unity-launch" must
        // not match "unity".
        const execWords = root.execWords(exec).concat(root.words(id));
        if (execWords.some(w => w === q))
            return root.execMatch + 100;
        if (execWords.some(w => w.startsWith(q)))
            return root.execMatch;

        if (generic.includes(q))
            return root.generic;

        if (root.words(keywords).some(w => w.startsWith(q)))
            return root.keyword;

        // Last: the letters are all there, in order. Two things keep that
        // from matching everything, both learned from what it did match:
        //
        //   - the name has to be short enough for the letters to mean
        //     anything. "terminal" is scattered through any long enough
        //     sentence, which put a browser window titled with a video's
        //     name under a search for terminals; "image" is scattered
        //     through "SchedExt GUI Manager".
        //   - prose is never matched this way at all. A window title is a
        //     sentence somebody's application wrote, not a name somebody
        //     chose, and the caller says which it is handing over.
        if (q.length >= 2 && !fields?.prose && name.length <= q.length * 3 + 2
            && root.subsequence(name, q))
            return root.fuzzy + Math.round(200 * q.length / Math.max(name.length, 1));

        return root.none;
    }

    // A tie-break inside a class: shorter names first, and small enough that
    // the bonuses below still decide between two names of similar length.
    function _shortness(name) {
        return Math.max(0, 150 - 3 * Math.min(50, name.length));
    }

    // What a thing's history is worth, added to its match.
    //
    //   uses     how many times it has been chosen
    //   lastMs   when, in epoch milliseconds
    //   nowMs    the same clock, passed in so this stays pure
    //
    // Every use decays by half every `halfLifeDays`, so this is "how much has
    // it been used lately" rather than "how much has it ever been used" --
    // which is the difference between a launcher that learns and one that
    // remembers 2019.
    function recency(uses, lastMs, nowMs) {
        const n = Number(uses ?? 0);
        const last = Number(lastMs ?? 0);
        const now = Number(nowMs ?? 0);
        if (!(n > 0) || !(last > 0) || !(now > 0))
            return 0;

        const ageDays = Math.max(0, (now - last) / 86400000);
        const decayed = n * Math.pow(0.5, ageDays / root.halfLifeDays);
        if (decayed <= 0)
            return 0;

        // Logarithmic: the first few uses are what a launcher should learn
        // from, and the hundredth adds almost nothing.
        const fraction = Math.log2(1 + decayed) / Math.log2(1 + root.recencySaturation);
        return Math.round(root.recencyMax * Math.min(1, fraction));
    }

    // What a candidate is worth beyond its match: the three bonuses, which
    // are the whole of "this machine's answer" as opposed to "any machine's".
    //
    // `pinned` is the person saying so outright and outranks the other two
    // together; `preferred` is the system's own answer to "what opens this
    // kind of thing", which is why the default terminal should be the first
    // terminal even the first time anybody searches for one.
    function bonus(fields, history, nowMs) {
        return (fields?.preferred ? root.preferredBonus : 0)
             + root.recency(history?.uses, history?.lastMs, nowMs);
    }

    // Everything above, for one candidate. Returns `none` when it does not
    // match at all -- a thing pinned and used every day is still not a result
    // for a query it has nothing to do with, which is why pinning sorts the
    // matches rather than creating one.
    function rank(query, fields, history, nowMs) {
        const base = root.score(query, fields);
        if (base === root.none)
            return root.none;
        return base + root.bonus(fields, history, nowMs);
    }
}
