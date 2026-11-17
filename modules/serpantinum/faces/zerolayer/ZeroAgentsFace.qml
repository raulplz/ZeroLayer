import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · AGENTS://ZERØ, lanzador de ZeroAgents.
// Abre «zeroagents-gui» si existe; si no, «zeroagents» en la terminal.
// Muestra cuántas sesiones de Claude Code hay en marcha (procesos «claude»).
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 220
    property real minHeight: 70
    property real maxWidth: 600
    property real maxHeight: 200
    property real minAspect: 2.0
    property real maxAspect: 8.0

    ZlTheme { id: zl }

    readonly property string probe: decodeURIComponent(Qt.resolvedUrl("zl_probe.py").toString().replace(/^file:\/\//, ""))
    property bool gui: false
    property bool cli: false
    property int claude: 0
    property bool loaded: false

    Process {
        id: proc
        command: ["python3", "-I", root.probe, "agents"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let j = JSON.parse(this.text);
                    root.gui = j.gui;
                    root.cli = j.cli;
                    root.claude = j.claude;
                    root.loaded = true;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 10000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    function open() {
        if (root.gui)
            Quickshell.execDetached(["sh", "-c", "exec zeroagents-gui"]);
        else if (root.cli)
            Quickshell.execDetached(["xdg-terminal-exec", "--title=ZEROAGENTS", "bash", "-lc", "exec zeroagents"]);
    }

    ZlFrame {
        theme: zl
        title: "AGENTS://ZERØ"
        badge: !root.loaded ? "…" : root.gui ? "GUI" : root.cli ? "TUI" : "NO INSTALADO"

        RowLayout {
            anchors.fill: parent
            spacing: 8
            Text {
                text: "󰚩"
                font.family: zl.mono
                font.pixelSize: 18
                color: root.claude > 0 ? zl.acento : Qt.alpha(zl.acento, 0.45)
            }
            Text {
                text: String(root.claude)
                font.family: zl.mono
                font.pixelSize: 18
                font.bold: true
                color: root.claude > 0 ? zl.texto : zl.tenue
            }
            Text {
                Layout.fillWidth: true
                text: root.claude === 1 ? "SESIÓN CLAUDE ACTIVA" : "SESIONES CLAUDE ACTIVAS"
                elide: Text.ElideRight
                font.family: zl.mono
                font.pixelSize: 8
                font.letterSpacing: 1.2
                color: zl.tenue
            }
            ZlButton {
                theme: zl
                implicitHeight: 22
                active: root.gui || root.cli
                text: "ABRIR"
                glyph: "↗"
                fontSize: 9
                onClicked: root.open()
            }
        }
    }
}
