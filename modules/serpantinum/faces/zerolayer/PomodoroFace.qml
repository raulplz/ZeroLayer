import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · FOCUS://POMODORO.
// Foco y descansos con aviso al terminar (notify-send). Duraciones en
// ~/.config/zerolayer/serpantinum.json → "pomodoro": { focus: 25, break: 5, long: 15, every: 4 }.
// El estado sobrevive a recargas: ~/.local/state/zerolayer/pomodoro.json.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 140
    property real maxWidth: 520
    property real maxHeight: 400
    property real minAspect: 1.0
    property real maxAspect: 3.5

    ZlTheme { id: zl }
    ZlConfig {
        id: cfg
        onChanged: if (!root.running && !root.paused) root.remaining = root.duration(root.phase)
    }

    readonly property var conf: {
        let p = cfg.data.pomodoro || {};
        let n = (v, d) => (typeof v === "number" && v > 0 && v < 600) ? v : d;
        return { focus: n(p.focus, 25), brk: n(p["break"], 5), long: n(p.long, 15), every: Math.round(n(p.every, 4)) };
    }
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/zerolayer"

    property string phase: "focus"         // focus | break | long
    property bool running: false
    property real endAt: 0
    property real remaining: 25 * 60000
    property int done: 0
    property string day: ""
    property real now: Date.now()
    property bool restored: false

    readonly property bool paused: !running && remaining < duration(phase) - 999
    readonly property real left: running ? Math.max(0, endAt - now) : remaining
    readonly property real progress: 1 - left / duration(phase)

    function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd"); }
    function duration(ph) {
        return (ph === "focus" ? conf.focus : ph === "long" ? conf.long : conf.brk) * 60000;
    }
    function fmt(ms) {
        let s = Math.ceil(ms / 1000);
        let m = Math.floor(s / 60);
        return (m < 10 ? "0" : "") + m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }

    function save() {
        let j = JSON.stringify({ phase: phase, running: running, endAt: endAt, remaining: remaining, done: done, day: day });
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/pomodoro.json"', "_", stateDir, j]);
    }
    function rollDay() {
        if (day !== today()) { day = today(); done = 0; }
    }
    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "ZerØ", "-i", "alarm-symbolic", title, body]);
    }

    function start() {
        rollDay();
        endAt = Date.now() + remaining;
        running = true;
        save();
    }
    function pause() {
        remaining = Math.max(0, endAt - Date.now());
        running = false;
        save();
    }
    function reset() {
        running = false;
        remaining = duration(phase);
        save();
    }
    function finish(natural, quiet) {
        rollDay();
        if (phase === "focus") {
            if (natural) done += 1;
            phase = (done > 0 && done % conf.every === 0) ? "long" : "break";
            remaining = duration(phase);
            // El descanso empieza solo; el siguiente foco espera a que pulses.
            endAt = Date.now() + remaining;
            running = true;
            if (!quiet) notify("Pomodoro · foco terminado", "Descanso de " + Math.round(duration(phase) / 60000) + " min. Llevas " + done + " hoy.");
        } else {
            phase = "focus";
            running = false;
            remaining = duration("focus");
            if (!quiet && natural) notify("Pomodoro · descanso terminado", "Cuando quieras, otro bloque de " + conf.focus + " min.");
        }
        save();
    }

    FileView {
        path: root.stateDir + "/pomodoro.json"
        printErrors: false
        onLoaded: {
            try {
                let j = JSON.parse(typeof text === "function" ? text() : text);
                root.phase = ["focus", "break", "long"].includes(j.phase) ? j.phase : "focus";
                root.done = j.done || 0;
                root.day = j.day || "";
                root.remaining = j.remaining > 0 ? j.remaining : root.duration(root.phase);
                root.endAt = j.endAt || 0;
                root.running = !!j.running;
                root.rollDay();
                if (root.running && root.endAt <= Date.now()) root.finish(true, true);
            } catch (e) {}
            root.restored = true;
        }
        onLoadFailed: {
            root.remaining = root.duration("focus");
            root.day = root.today();
            root.restored = true;
        }
    }

    Timer {
        interval: 500
        running: root.running
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.now >= root.endAt) root.finish(true, false);
        }
    }

    readonly property color phaseColor: phase === "focus" ? zl.acento : zl.ok

    ZlFrame {
        theme: zl
        title: "FOCUS://POMODORO"
        badge: root.done + " HOY"

        RowLayout {
            anchors.fill: parent
            spacing: 14

            Item {
                Layout.preferredWidth: Math.min(parent.height, 118)
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter
                ZlRing {
                    anchors.fill: parent
                    value: root.progress
                    fillColor: root.phaseColor
                    trackColor: Qt.alpha(root.phaseColor, 0.16)
                    lineWidth: 5
                    ticks: 30
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.fmt(root.left)
                        font.family: zl.mono
                        font.pixelSize: 20
                        font.bold: true
                        color: zl.texto
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.phase === "focus" ? "FOCO" : root.phase === "long" ? "DESCANSO+" : "DESCANSO"
                        font.family: zl.mono
                        font.pixelSize: 8
                        font.letterSpacing: 1.5
                        color: root.phaseColor
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Item { Layout.fillHeight: true }

                Row {
                    spacing: 5
                    Repeater {
                        model: root.conf.every
                        Rectangle {
                            required property int index
                            width: 14
                            height: 6
                            radius: 1
                            color: index < (root.done % root.conf.every) || (root.done > 0 && root.done % root.conf.every === 0 && root.phase === "long")
                                ? zl.acento : Qt.alpha(zl.acento, 0.18)
                        }
                    }
                }
                Text {
                    text: root.conf.focus + " / " + root.conf.brk + " MIN" + (root.running ? "  ·  EN MARCHA" : root.paused ? "  ·  EN PAUSA" : "")
                    font.family: zl.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1.2
                    color: zl.tenue
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    ZlButton {
                        theme: zl
                        Layout.fillWidth: true
                        primary: true
                        glyph: root.running ? "❚❚" : "▶"
                        text: root.running ? "PAUSA" : root.paused ? "SEGUIR" : "EMPEZAR"
                        onClicked: root.running ? root.pause() : root.start()
                    }
                    ZlButton {
                        theme: zl
                        implicitWidth: 30
                        text: "󰑐"
                        onClicked: root.reset()
                    }
                    ZlButton {
                        theme: zl
                        implicitWidth: 30
                        text: "󰒭"
                        onClicked: root.finish(false, false)
                    }
                }
            }
        }
    }
}
