pragma Singleton

// The machine's numbers -- CPU, memory, disk, network, the GPU and the
// temperatures -- read only while something on screen shows them.
//
// Every two seconds from /proc and /sys, the disk once a minute from df. The
// arithmetic is Stats', tested. Which hwmon is the CPU's and which card is the
// GPU differs from machine to machine, so they are looked for once; one that
// is not there reads as -1 and is simply not shown.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.domain.system.stats

QtObject {
    id: root

    // How many things on screen show these. The start menu and the sidebar
    // count themselves in and out; with none, nothing is read.
    property int watchers: 0
    function watch(on) {
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));
    }
    readonly property bool running: root.watchers > 0

    property real cpu: 0
    property int cpuTemp: -1
    property real memTotal: 0
    property real memUsed: 0
    property real diskSize: 0
    property real diskFree: 0
    property real gpu: -1
    property int gpuTemp: -1
    property real netRate: 0

    property var _cpuPrev: null
    property var _netPrev: null
    property real _netTime: 0

    property string _cpuTempPath: ""
    property string _gpuTempPath: ""
    property string _gpuBusyPath: ""

    readonly property Process _find: Process {
        running: true
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); "
            + "case \"$n\" in k10temp|coretemp|zenpower|cpu_thermal) [ -r \"$d/temp1_input\" ] && echo \"cpu $d/temp1_input\";; "
            + "amdgpu|radeon|nouveau) [ -r \"$d/temp1_input\" ] && echo \"gpu $d/temp1_input\";; esac; done; "
            + "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && { echo \"busy $f\"; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const [kind, path] = line.split(" ");
                    if (kind === "cpu" && !root._cpuTempPath)
                        root._cpuTempPath = path;
                    else if (kind === "gpu" && !root._gpuTempPath)
                        root._gpuTempPath = path;
                    else if (kind === "busy" && !root._gpuBusyPath)
                        root._gpuBusyPath = path;
                }
            }
        }
    }

    readonly property FileView _stat: FileView {
        path: root.running ? "/proc/stat" : ""
        printErrors: false
        onLoaded: {
            const c = Stats.parseCpu(text());
            root.cpu = Stats.cpuUsage(root._cpuPrev, c);
            root._cpuPrev = c;
        }
    }

    readonly property FileView _memory: FileView {
        path: root.running ? "/proc/meminfo" : ""
        printErrors: false
        onLoaded: {
            const m = Stats.parseMemory(text());
            root.memTotal = m.total;
            root.memUsed = m.used;
        }
    }

    readonly property FileView _net: FileView {
        path: root.running ? "/proc/net/dev" : ""
        printErrors: false
        onLoaded: {
            const now = Date.now();
            const n = Stats.parseNetDev(text());
            root.netRate = Stats.rate(root._netPrev, n, (now - root._netTime) / 1000);
            root._netPrev = n;
            root._netTime = now;
        }
    }

    readonly property FileView _cpuTemp: FileView {
        path: root.running ? root._cpuTempPath : ""
        printErrors: false
        onLoaded: root.cpuTemp = Stats.temperature(text())
    }

    readonly property FileView _gpuTemp: FileView {
        path: root.running ? root._gpuTempPath : ""
        printErrors: false
        onLoaded: root.gpuTemp = Stats.temperature(text())
    }

    readonly property FileView _gpuBusy: FileView {
        path: root.running ? root._gpuBusyPath : ""
        printErrors: false
        onLoaded: root.gpu = Stats.fractionOf(text())
    }

    readonly property Process _df: Process {
        command: ["df", "-B1", "--output=size,avail", Quickshell.env("HOME") || "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = Stats.parseDf(text);
                root.diskSize = d.size;
                root.diskFree = d.free;
            }
        }
    }

    readonly property Timer _tick: Timer {
        interval: 2000
        repeat: true
        running: root.running
        onTriggered: {
            for (const view of [root._stat, root._memory, root._net, root._cpuTemp, root._gpuTemp, root._gpuBusy]) {
                if (view.path.length > 0)
                    view.reload();
            }
        }
    }

    readonly property Timer _diskTick: Timer {
        interval: 60000
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: {
            root._df.running = false;
            root._df.running = true;
        }
    }
}
