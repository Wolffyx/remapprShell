// Lines of `busctl --json=short monitor`, for the tests of the parsers that
// read them.
//
// Five tests each built these by hand, and a line is only worth testing
// against if it is shaped the way busctl shapes it. The fields come out in
// busctl's order, and only those given: a test that leaves out `sender` gets
// a line without one, the way a test that writes the object literal would.
.pragma library

// message(type, interface, member, signature, data, fields) -> JSON text
//
// `signature` null leaves the payload's type out. `fields` may carry `sender`
// and `path`, which go where busctl puts them, and anything else, which is
// laid over the top -- so a test can make the same line a different member,
// or not a method call at all.
function message(type, iface, member, signature, data, fields) {
    const extra = Object.assign({}, fields ?? {});
    const line = { type: type };
    for (const key of ["sender", "path"]) {
        if (key in extra) {
            line[key] = extra[key];
            delete extra[key];
        }
    }
    line.interface = iface;
    line.member = member;
    line.payload = signature === null ? { data: data } : { type: signature, data: data };
    return JSON.stringify(Object.assign(line, extra));
}

function signal(iface, member, signature, data, fields) {
    return message("signal", iface, member, signature, data, fields);
}

function methodCall(iface, member, signature, data, fields) {
    return message("method_call", iface, member, signature, data, fields);
}

// A notification client's Notify, as the notification listener sees it.
function notify(data, fields, signature) {
    return methodCall("org.freedesktop.Notifications", "Notify",
                      signature === undefined ? "susssasa{sv}i" : signature, data, fields);
}

// n bytes as busctl renders a byte array: one JSON integer each. An icon sent
// as pixels arrives like this, and a big one is what took the shell down.
function pixels(n) {
    const a = [];
    for (let i = 0; i < n; i++)
        a.push(i % 256);
    return a;
}
