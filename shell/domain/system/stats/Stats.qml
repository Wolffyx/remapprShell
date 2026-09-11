pragma Singleton

// The arithmetic behind the machine's numbers: CPU from /proc/stat, memory
// from /proc/meminfo, disk from df, network from /proc/net/dev, temperatures
// from hwmon. Pure, and a module of its own so the tests can load it; the
// reading is SystemStats'.

import QtQuick

QtObject {
    id: root

    // The aggregate "cpu" line: { total, idle } in jiffies, idle counting
    // iowait. Null when there is no such line.
    function parseCpu(text) {
        const line = String(text ?? "").split("\n").find(l => /^cpu\s/.test(l));
        if (!line)
            return null;
        const v = line.trim().split(/\s+/).slice(1).map(Number);
        if (v.length < 4 || !v.every(Number.isFinite))
            return null;
        // user nice system idle iowait irq softirq steal; guest time is
        // already inside user and nice, so it is not added again.
        const total = v.slice(0, 8).reduce((a, b) => a + b, 0);
        return { total: total, idle: v[3] + (v[4] ?? 0) };
    }

    // How busy the CPU was between two readings, 0..1.
    function cpuUsage(prev, cur) {
        if (!prev || !cur)
            return 0;
        const dt = cur.total - prev.total;
        const di = cur.idle - prev.idle;
        return dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
    }

    // Bytes: { total, available, used }. Used is what is not available,
    // which is what "used" means to a person -- caches are available.
    function parseMemory(text) {
        const get = key => {
            const m = new RegExp(`^${key}:\\s+(\\d+)\\s*kB`, "m").exec(String(text ?? ""));
            return m ? Number(m[1]) * 1024 : 0;
        };
        const total = get("MemTotal");
        const available = get("MemAvailable");
        return { total: total, available: available, used: Math.max(0, total - available) };
    }

    // `df -B1 --output=size,avail <path>`: { size, free } in bytes.
    function parseDf(text) {
        const lines = String(text ?? "").trim().split("\n");
        const last = (lines[lines.length - 1] ?? "").trim().split(/\s+/).map(Number);
        return last.length >= 2 && last.every(Number.isFinite) ? { size: last[0], free: last[1] } : { size: 0, free: 0 };
    }

    // Bytes received and sent by every interface but loopback.
    function parseNetDev(text) {
        let rx = 0;
        let tx = 0;
        for (const line of String(text ?? "").split("\n")) {
            const m = /^\s*([^:\s]+):\s*(.*)$/.exec(line);
            if (!m || m[1] === "lo")
                continue;
            const f = m[2].trim().split(/\s+/).map(Number);
            if (f.length >= 9 && f.every(Number.isFinite)) {
                rx += f[0];
                tx += f[8];
            }
        }
        return { rx: rx, tx: tx };
    }

    // Bytes a second, in and out together, between two readings.
    function rate(prev, cur, seconds) {
        if (!prev || !cur || !(seconds > 0))
            return 0;
        return Math.max(0, ((cur.rx - prev.rx) + (cur.tx - prev.tx)) / seconds);
    }

    // "412 GiB", "9.4 GiB", "1.2 MiB": binary units, a decimal below ten.
    function bytes(n) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"];
        let v = Math.max(0, Number(n) || 0);
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return `${i > 0 && v < 10 ? v.toFixed(1) : Math.round(v)} ${units[i]}`;
    }

    // hwmon's millidegrees as whole degrees; -1 for nothing.
    function temperature(milli) {
        const v = Number(String(milli ?? "").trim());
        return Number.isFinite(v) && v > 0 ? Math.round(v / 1000) : -1;
    }

    // A percentage file (the GPU's gpu_busy_percent) as 0..1; -1 for nothing.
    function fractionOf(percentText) {
        const v = Number(String(percentText ?? "").trim());
        return String(percentText ?? "").trim().length > 0 && Number.isFinite(v) ? Math.max(0, Math.min(1, v / 100)) : -1;
    }
}
