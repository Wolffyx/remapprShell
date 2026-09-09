// Tests for the pure object helpers behind config layering.
//
// These matter more than their size suggests: `unset` pruning empty parents is
// what keeps a user's profile a sparse delta, and deepMerge NOT merging arrays
// element-wise is what stops a reordered widget list producing a hybrid order.

import QtQuick
import QtTest
import qs.core

TestCase {
    name: "Obj"

    function test_deepMerge_later_wins() {
        const r = Obj.deepMerge({ a: 1, b: 2 }, { b: 3 });
        compare(r.a, 1);
        compare(r.b, 3);
    }

    function test_deepMerge_recurses_objects() {
        const r = Obj.deepMerge({ p: { x: 1, y: 2 } }, { p: { y: 9 } });
        compare(r.p.x, 1);
        compare(r.p.y, 9);
    }

    function test_deepMerge_replaces_arrays_wholesale() {
        // Element-wise merging would turn a reordered list into a hybrid of
        // both orders; bar.entries is ordered, so replacement is correct.
        const r = Obj.deepMerge({ e: [1, 2, 3] }, { e: [9] });
        compare(r.e.length, 1);
        compare(r.e[0], 9);
    }

    function test_deepMerge_does_not_mutate_inputs() {
        const base = { p: { x: 1 } };
        Obj.deepMerge(base, { p: { x: 2 } });
        compare(base.p.x, 1);
    }

    function test_get_and_has() {
        const o = { a: { b: { c: 7 } } };
        compare(Obj.get(o, "a.b.c"), 7);
        compare(Obj.get(o, "a.b.zzz", "fallback"), "fallback");
        verify(Obj.has(o, "a.b.c"));
        verify(!Obj.has(o, "a.b.zzz"));
    }

    function test_get_handles_falsy_values() {
        // A stored `false` or `0` must not be mistaken for "absent".
        const o = { a: { off: false, zero: 0 } };
        compare(Obj.get(o, "a.off", "WRONG"), false);
        compare(Obj.get(o, "a.zero", "WRONG"), 0);
        verify(Obj.has(o, "a.off"));
    }

    function test_set_creates_intermediate_objects() {
        const r = Obj.set({}, "a.b.c", 5);
        compare(r.a.b.c, 5);
    }

    function test_set_does_not_mutate_input() {
        const o = { a: { b: 1 } };
        Obj.set(o, "a.b", 2);
        compare(o.a.b, 1);
    }

    function test_unset_prunes_empty_parents() {
        // The whole point of sparseness: removing the only leaf must not leave
        // `{ a: { b: {} } }` behind to accumulate forever.
        const r = Obj.unset({ a: { b: { c: 1 } } }, "a.b.c");
        compare(Object.keys(r).length, 0);
    }

    function test_unset_keeps_non_empty_parents() {
        const r = Obj.unset({ a: { b: { c: 1 }, keep: 2 } }, "a.b.c");
        compare(r.a.keep, 2);
        verify(!("b" in r.a));
    }

    function test_unset_missing_path_is_a_noop() {
        const r = Obj.unset({ a: 1 }, "x.y.z");
        compare(r.a, 1);
    }

    function test_deepEqual() {
        verify(Obj.deepEqual({ a: [1, { b: 2 }] }, { a: [1, { b: 2 }] }));
        verify(!Obj.deepEqual({ a: 1 }, { a: 1, b: 2 }));
        verify(!Obj.deepEqual([1, 2], [2, 1]));
        verify(Obj.deepEqual(0, 0));
        verify(!Obj.deepEqual(0, false));
    }
}
