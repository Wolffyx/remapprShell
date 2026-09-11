// Tests for reading the machine's numbers.

import QtQuick
import QtTest
import qs.domain.system.stats

TestCase {
    name: "Stats"

    function test_cpu_line() {
        const c = Stats.parseCpu("cpu  100 0 50 800 50 0 0 0 0 0\ncpu0 1 2 3 4\n");
        compare(c.total, 1000);
        compare(c.idle, 850);
    }

    function test_no_cpu_line_is_nothing() {
        compare(Stats.parseCpu("intr 1 2 3"), null);
        compare(Stats.parseCpu(""), null);
    }

    function test_cpu_usage_between_readings() {
        const a = { total: 1000, idle: 800 };
        const b = { total: 1200, idle: 900 };
        compare(Stats.cpuUsage(a, b), 0.5);
        compare(Stats.cpuUsage(null, b), 0);
        compare(Stats.cpuUsage(b, b), 0);
    }

    function test_memory_used_is_what_is_not_available() {
        const m = Stats.parseMemory("MemTotal:       65736332 kB\nMemFree: 1000 kB\nMemAvailable:   40044240 kB\n");
        compare(m.total, 65736332 * 1024);
        compare(m.available, 40044240 * 1024);
        compare(m.used, (65736332 - 40044240) * 1024);
    }

    function test_df() {
        compare(Stats.parseDf("    1B-blocks        Avail\n1998249316352 1469549273088\n"),
                { size: 1998249316352, free: 1469549273088 });
        compare(Stats.parseDf("nonsense"), { size: 0, free: 0 });
    }

    function test_net_dev_leaves_out_loopback() {
        const text = "Inter-|   Receive    |  Transmit\n face |bytes packets errs drop fifo frame compressed multicast|bytes\n"
                   + "    lo: 5000 10 0 0 0 0 0 0 5000 10 0 0 0 0 0 0\n"
                   + "  eth0: 1000 10 0 0 0 0 0 0 300 5 0 0 0 0 0 0\n"
                   + " wlan0: 200 1 0 0 0 0 0 0 100 1 0 0 0 0 0 0\n";
        compare(Stats.parseNetDev(text), { rx: 1200, tx: 400 });
        compare(Stats.rate({ rx: 0, tx: 0 }, { rx: 1500, tx: 500 }, 2), 1000);
        compare(Stats.rate(null, { rx: 1, tx: 1 }, 2), 0);
    }

    function test_bytes() {
        compare(Stats.bytes(0), "0 B");
        compare(Stats.bytes(512), "512 B");
        compare(Stats.bytes(1.2 * 1024 * 1024), "1.2 MiB");
        compare(Stats.bytes(9.4 * 1024 * 1024 * 1024), "9.4 GiB");
        compare(Stats.bytes(412 * 1024 * 1024 * 1024), "412 GiB");
    }

    function test_temperature_and_fraction() {
        compare(Stats.temperature("48125\n"), 48);
        compare(Stats.temperature(""), -1);
        compare(Stats.fractionOf("7\n"), 0.07);
        compare(Stats.fractionOf(""), -1);
    }
}
