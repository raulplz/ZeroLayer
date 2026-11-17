import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · PLAY://ZERØ, juegos recientes y estado del equipo.
// Lista los últimos juegos de Steam (appmanifest) y Heroic (si están instalados)
// y los lanza con un clic. Abajo: temperatura y uso de la GPU y batería del mando.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 180
    property real maxWidth: 600
    property real maxHeight: 700
    property real minAspect: 0.5
    property real maxAspect: 3.0

    ZlTheme { id: zl }

    readonly property string probe: decodeURIComponent(Qt.resolvedUrl("zl_probe.py").toString().replace(/^file:\/\//, ""))
    property bool loaded: false
    property bool steam: false
    property bool heroic: false
    property var games: []
    property var gpu: ({ temp: null, busy: null })
    property var pads: []
    property real nowTick: Date.now()

    Process {
        id: proc
        command: ["python3", "-I", root.probe, "games"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let j = JSON.parse(this.text);
                    root.steam = j.steam;
                    root.heroic = j.heroic;
                    root.games = j.games;
                    root.gpu = j.gpu;
                    root.pads = j.pads;
                    root.loaded = true;
                    root.nowTick = Date.now();
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 20000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    function rel(ts) {
        if (!ts || ts <= 0) return "";
        let d = Math.floor((root.nowTick / 1000 - ts) / 86400);
        if (d < 1) return "HOY";
        if (d < 2) return "AYER";
        if (d < 30) return d + " D";
        return Qt.formatDate(new Date(ts * 1000), "dd/MM/yy");
    }

    function tempColor(t) {
        if (t === null || t === undefined) return zl.tenue;
        if (t >= 85) return zl.peligro;
        if (t >= 70) return zl.aviso;
        return zl.ok;
    }

    readonly property string padText: {
        if (root.pads.length === 0) return "—";
        let p = root.pads[0];
        let v = p.capacity !== null ? p.capacity + "%" : (p.level || "?").toUpperCase();
        return (p.charging ? "⚡" : "") + v + (root.pads.length > 1 ? " +" + (root.pads.length - 1) : "");
    }

    ZlFrame {
        theme: zl
        title: "PLAY://ZERØ"
        badge: !root.loaded ? "…" : [root.steam ? "STEAM" : "", root.heroic ? "HEROIC" : ""].filter(x => x).join(" · ") || "SIN TIENDAS"

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: root.loaded && root.games.length === 0
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰊴"
                        font.family: zl.mono
                        font.pixelSize: 26
                        color: Qt.alpha(zl.acento, 0.45)
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "// sin juegos instalados"
                        font.family: zl.mono
                        font.pixelSize: 10
                        color: zl.texto
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Steam " + (root.steam ? "✓" : "✕") + "   ·   Heroic " + (root.heroic ? "✓" : "✕")
                        font.family: zl.mono
                        font.pixelSize: 9
                        color: zl.tenue
                    }
                }

                ListView {
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    visible: root.games.length > 0
                    model: root.games
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 30
                        radius: 3
                        color: hover.containsMouse ? Qt.alpha(zl.acento, 0.16) : "transparent"
                        border.width: hover.containsMouse ? 1 : 0
                        border.color: Qt.alpha(zl.acento, 0.6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            Text {
                                text: "[0" + (row.index + 1) + "]"
                                font.family: zl.mono
                                font.pixelSize: 9
                                color: Qt.alpha(zl.acento, 0.6)
                            }
                            Text {
                                text: row.modelData.store === "steam" ? "󰓓" : "󰮂"
                                font.family: zl.mono
                                font.pixelSize: 13
                                color: zl.acento2
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name.toUpperCase()
                                elide: Text.ElideRight
                                font.family: zl.mono
                                font.pixelSize: 11
                                font.letterSpacing: 0.5
                                color: hover.containsMouse ? zl.texto : Qt.alpha(zl.texto, 0.85)
                            }
                            Text {
                                text: hover.containsMouse ? "▶" : root.rel(row.modelData.last)
                                font.family: zl.mono
                                font.pixelSize: 8
                                color: hover.containsMouse ? zl.acento : zl.tenue
                            }
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(row.modelData.launch)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.alpha(zl.acento, 0.2)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "GPU"
                    font.family: zl.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                    color: zl.tenue
                }
                Text {
                    text: root.gpu.temp !== null && root.gpu.temp !== undefined ? root.gpu.temp + "°" : "--"
                    font.family: zl.mono
                    font.pixelSize: 12
                    font.bold: true
                    color: root.tempColor(root.gpu.temp)
                }
                Text {
                    text: root.gpu.busy !== null && root.gpu.busy !== undefined ? root.gpu.busy + "%" : ""
                    font.family: zl.mono
                    font.pixelSize: 10
                    color: zl.texto
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "󰊴 MANDO"
                    font.family: zl.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1.2
                    color: zl.tenue
                }
                Text {
                    text: root.padText
                    font.family: zl.mono
                    font.pixelSize: 11
                    font.bold: true
                    color: root.pads.length && root.pads[0].capacity !== null && root.pads[0].capacity <= 20 ? zl.peligro : zl.texto
                }
            }
        }
    }
}
