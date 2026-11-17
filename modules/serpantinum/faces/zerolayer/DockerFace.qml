import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · DOCKER://PS, contenedores en modo solo lectura.
// Ejecuta «docker [--context X] ps -a»; nunca arranca, para ni borra nada.
// Contexto: «dockerContext» en ~/.config/zerolayer/serpantinum.json (vacío = el actual).
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 120
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.8
    property real maxAspect: 4.0

    ZlTheme { id: zl }
    ZlConfig {
        id: cfg
        onChanged: root.refresh()
    }

    readonly property string context: typeof cfg.data.dockerContext === "string" ? cfg.data.dockerContext : ""
    readonly property string probe: decodeURIComponent(Qt.resolvedUrl("zl_probe.py").toString().replace(/^file:\/\//, ""))

    property bool loaded: false
    property bool hasDocker: true
    property bool engine: false
    property string error: ""
    property var containers: []
    readonly property int up: containers.filter(c => c.state === "running").length

    function refresh() {
        if (!cfg.ready) return;
        if (!proc.running) proc.running = true;
    }

    Process {
        id: proc
        command: ["python3", "-I", root.probe, "docker", root.context]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let j = JSON.parse(this.text);
                    root.hasDocker = j.docker;
                    root.engine = j.running;
                    root.error = j.error || "";
                    root.containers = j.containers || [];
                    root.loaded = true;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }
    onVisibleChanged: if (visible) refresh()

    function stateColor(s) {
        if (s === "running") return zl.ok;
        if (s === "restarting" || s === "paused") return zl.aviso;
        if (s === "dead") return zl.peligro;
        return zl.tenue;
    }

    ZlFrame {
        theme: zl
        title: "DOCKER://PS"
        badge: !root.loaded ? "…"
             : !root.hasDocker ? "NO INSTALADO"
             : !root.engine ? "MOTOR PARADO"
             : root.up + "/" + root.containers.length + " ON"
        badgeColor: root.loaded && root.hasDocker && !root.engine ? zl.aviso : Qt.alpha(zl.acento, 0.7)

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width
            visible: root.loaded && (!root.engine || root.containers.length === 0)
            spacing: 4
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰡨"
                font.family: zl.mono
                font.pixelSize: 24
                color: Qt.alpha(zl.acento, root.engine ? 0.6 : 0.35)
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: !root.hasDocker ? "// docker no está instalado"
                    : !root.engine ? "// el motor no está en marcha"
                    : "// sin contenedores"
                font.family: zl.mono
                font.pixelSize: 10
                color: zl.texto
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasDocker && root.context !== ""
                text: "contexto " + root.context
                font.family: zl.mono
                font.pixelSize: 8
                color: zl.tenue
            }
        }

        ListView {
            anchors.fill: parent
            clip: true
            spacing: 2
            visible: root.engine && root.containers.length > 0
            model: root.containers
            boundsBehavior: Flickable.StopAtBounds

            delegate: RowLayout {
                id: row
                required property var modelData
                width: ListView.view.width
                height: 22
                spacing: 7

                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: root.stateColor(row.modelData.state)
                }
                Text {
                    Layout.preferredWidth: parent.width * 0.42
                    text: row.modelData.name
                    elide: Text.ElideRight
                    font.family: zl.mono
                    font.pixelSize: 10
                    color: row.modelData.state === "running" ? zl.texto : zl.tenue
                }
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.image
                    elide: Text.ElideMiddle
                    font.family: zl.mono
                    font.pixelSize: 8
                    color: zl.tenue
                }
                Text {
                    text: row.modelData.status.replace(/^Up /, "↑ ").replace(/^Exited \((\d+)\).*/, "✕ $1").replace(/ (seconds?|minutes?|hours?|days?|weeks?|months?)/, m => " " + m.trim()[0])
                    font.family: zl.mono
                    font.pixelSize: 8
                    color: root.stateColor(row.modelData.state)
                }
            }
        }
    }
}
