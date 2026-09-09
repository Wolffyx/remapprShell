pragma Singleton

// Pure object helpers used by the config layering. No I/O, no side effects --
// everything here is a function of its arguments, which is what makes the
// config store testable.

import QtQuick

QtObject {
    id: root

    function isPlainObject(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v);
    }

    function clone(v) {
        if (Array.isArray(v))
            return v.map(root.clone);
        if (root.isPlainObject(v)) {
            const out = {};
            for (const k of Object.keys(v))
                out[k] = root.clone(v[k]);
            return out;
        }
        return v;
    }

    // Later arguments win. Objects merge recursively; arrays and scalars are
    // replaced wholesale.
    //
    // Arrays are deliberately NOT merged element-wise: `bar.entries` is an
    // ordered list, and merging it positionally would make a profile that
    // reorders widgets produce a nonsensical hybrid of the two orders.
    function deepMerge(...layers) {
        let out = {};
        for (const layer of layers) {
            if (!root.isPlainObject(layer))
                continue;
            out = root._merge2(out, layer);
        }
        return out;
    }

    function _merge2(base, over) {
        const out = root.clone(base);
        for (const k of Object.keys(over)) {
            const ov = over[k];
            if (root.isPlainObject(ov) && root.isPlainObject(out[k]))
                out[k] = root._merge2(out[k], ov);
            else
                out[k] = root.clone(ov);
        }
        return out;
    }

    function deepEqual(a, b) {
        if (a === b)
            return true;
        if (Array.isArray(a) && Array.isArray(b))
            return a.length === b.length && a.every((v, i) => root.deepEqual(v, b[i]));
        if (root.isPlainObject(a) && root.isPlainObject(b)) {
            const ka = Object.keys(a);
            const kb = Object.keys(b);
            return ka.length === kb.length && ka.every(k => k in b && root.deepEqual(a[k], b[k]));
        }
        return false;
    }

    // "bar.entries" -> ["bar", "entries"]
    function splitPath(path) {
        return String(path).split(".").filter(s => s.length > 0);
    }

    function get(obj, path, fallback) {
        let cur = obj;
        for (const key of root.splitPath(path)) {
            if (!root.isPlainObject(cur) || !(key in cur))
                return fallback;
            cur = cur[key];
        }
        return cur;
    }

    function has(obj, path) {
        const sentinel = {};
        return root.get(obj, path, sentinel) !== sentinel;
    }

    // Returns a modified copy; the input is never touched.
    function set(obj, path, value) {
        const keys = root.splitPath(path);
        if (keys.length === 0)
            return root.clone(value);

        const out = root.isPlainObject(obj) ? root.clone(obj) : {};
        let cur = out;
        for (let i = 0; i < keys.length - 1; i++) {
            const k = keys[i];
            if (!root.isPlainObject(cur[k]))
                cur[k] = {};
            cur = cur[k];
        }
        cur[keys[keys.length - 1]] = root.clone(value);
        return out;
    }

    // Deletes a leaf and then any parent objects left empty by the deletion.
    // This is what keeps a profile file a sparse delta rather than a growing
    // copy of the defaults.
    function unset(obj, path) {
        const keys = root.splitPath(path);
        if (keys.length === 0)
            return {};

        const out = root.isPlainObject(obj) ? root.clone(obj) : {};

        // Walk down, remembering the chain so empty parents can be pruned.
        const chain = [out];
        let cur = out;
        for (let i = 0; i < keys.length - 1; i++) {
            const next = cur[keys[i]];
            if (!root.isPlainObject(next))
                return out; // nothing to delete
            chain.push(next);
            cur = next;
        }
        delete cur[keys[keys.length - 1]];

        for (let i = chain.length - 1; i > 0; i--) {
            if (Object.keys(chain[i]).length === 0)
                delete chain[i - 1][keys[i - 1]];
            else
                break;
        }
        return out;
    }
}
