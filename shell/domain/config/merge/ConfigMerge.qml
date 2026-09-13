pragma Singleton

// What a flush should write, as a pure function of what is in hand -- so the
// rule that decides between the user's file and ours is tested rather than
// trusted. See ConfigStore for when it is asked.

import QtQuick
import qs.core

QtObject {
    // The schema version belongs to whoever writes the file, not to the
    // configuration: it is added on the way out and stripped on the way in.
    // Comparisons and merges are done without it, because comparing a parsed
    // file (which carries it) against our own copy (which does not) answered
    // "changed" every single time -- so every write took the merging path
    // below, and a key dropped because it had returned to its default came
    // straight back off the disk. Choosing the default value in the settings
    // window did nothing at all, which is how it was found.
    function withoutVersion(data) {
        const copy = Obj.clone(data ?? {});
        delete copy.schemaVersion;
        return copy;
    }

    // Has the file moved under us since we last read it? True means somebody
    // else wrote it -- a hand edit, or one of the CLI commands that writes
    // this file -- and their content is the base our own changes go onto.
    function changedOnDisk(onDisk, lastParsed) {
        return !Obj.deepEqual(withoutVersion(onDisk), withoutVersion(lastParsed));
    }

    // The profile to write: our copy, on top of anything the file gained since
    // we read it, minus the keys we have deliberately dropped.
    //
    // The removals are the whole point. The profile is a sparse delta, so a
    // value returning to its shipped default removes the key rather than
    // writing it -- and a merge that does not know this resurrects every one
    // of them from the file it is merging with.
    function flushData(onDisk, lastParsed, profileData, removed) {
        if (!changedOnDisk(onDisk, lastParsed))
            return profileData;

        let merged = Obj.deepMerge(withoutVersion(onDisk), profileData);
        for (const path of removed ?? [])
            merged = Obj.unset(merged, path);
        return merged;
    }
}
