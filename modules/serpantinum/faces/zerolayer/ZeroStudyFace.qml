import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · STUDY://ZERØ, resumen de ZeroStudy en el escritorio.
// Lee $XDG_DATA_HOME/zerostudy/widget.json (lo escribe la app) en caliente:
//   { pendientes_hoy, racha, dominio (0..1), proximo_plazo: { titulo, unidad, dias } | null, actualizado }
// «Repasar» ejecuta «zerostudy --repaso» y «Abrir», «zerostudy». Si la app no
// está instalada, lo dice en vez de fallar.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 260
    property real minHeight: 160
    property real maxWidth: 520
    property real maxHeight: 360
    property real minAspect: 1.1
    property real maxAspect: 3.2

    ZlTheme { id: zl }

    readonly property string dataFile: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/zerostudy/widget.json"

    property bool installed: false
    property bool hasData: false
    property int pendientes: 0
    property int racha: 0
    property real dominio: 0
    property var plazo: null
    property string actualizado: ""
    property real nowTick: Date.now()

    readonly property bool shown: root.visible

    function applyData(raw) {
        try {
            let j = JSON.parse(raw || "");
            root.pendientes = Math.max(0, parseInt(j.pendientes_hoy) || 0);
            root.racha = Math.max(0, parseInt(j.racha) || 0);
            root.dominio = Math.max(0, Math.min(1, parseFloat(j.dominio) || 0));
            let p = j.proximo_plazo;
            root.plazo = (p && typeof p === "object" && p.titulo)
                ? { titulo: String(p.titulo), unidad: p.unidad !== undefined && p.unidad !== null ? String(p.unidad) : "", dias: parseInt(p.dias) }
                : null;
            root.actualizado = j.actualizado ? String(j.actualizado) : "";
            root.hasData = true;
        } catch (e) {
            root.hasData = false;
        }
        root.nowTick = Date.now();
    }

    FileView {
        id: data
        path: root.dataFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyData(typeof text === "function" ? text() : text)
        onLoadFailed: root.hasData = false
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v zerostudy >/dev/null"]
        onExited: (code) => root.installed = (code === 0)
    }

    // Relectura periódica: el archivo puede crearse o sustituirse (renombrado
    // atómico) sin que llegue el aviso, y la app puede instalarse después.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            data.reload();
            if (!probe.running) probe.running = true;
            root.nowTick = Date.now();
        }
    }

    function launch(args) {
        Quickshell.execDetached(["sh", "-c", 'exec zerostudy "$@"', "zerostudy"].concat(args));
    }

    function parseLocal(s) {
        let m = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?/.exec(s || "");
        if (!m) return null;
        return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0));
    }

    readonly property string ageText: {
        let d = parseLocal(root.actualizado);
        if (!d) return "";
        let min = Math.floor((root.nowTick - d.getTime()) / 60000);
        if (min < 1) return "AHORA";
        if (min < 60) return "HACE " + min + " MIN";
        if (min < 1440) return "HACE " + Math.floor(min / 60) + " H";
        return "HACE " + Math.floor(min / 1440) + " D";
    }
    readonly property bool stale: {
        let d = parseLocal(root.actualizado);
        return !!d && (root.nowTick - d.getTime()) > 86400000;
    }

    function daysColor(d) {
        if (isNaN(d)) return zl.tenue;
        if (d <= 7) return zl.peligro;
        if (d <= 21) return zl.aviso;
        return zl.ok;
    }
    function daysText(d) {
        if (isNaN(d)) return "--";
        if (d < 0) return "VENCIDO";
        if (d === 0) return "HOY";
        if (d === 1) return "MAÑANA";
        return d + " D";
    }

    ZlFrame {
        theme: zl
        title: "STUDY://ZERØ"
        badge: !root.installed && !root.hasData ? "OFFLINE"
             : !root.installed ? "SIN APP"
             : root.hasData ? root.ageText : "SIN DATOS"
        badgeColor: root.stale || (!root.installed && root.hasData) ? zl.aviso : Qt.alpha(zl.acento, 0.7)

        // ---------- no instalado ----------
        ColumnLayout {
            anchors.fill: parent
            visible: !root.installed && !root.hasData
            spacing: 4
            Item { Layout.fillHeight: true }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰑴"
                font.family: zl.mono
                font.pixelSize: 26
                color: Qt.alpha(zl.acento, 0.5)
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "// ZEROSTUDY NO ESTÁ INSTALADO"
                font.family: zl.mono
                font.pixelSize: 10
                font.letterSpacing: 1
                color: zl.texto
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "instala la app y aquí verás tu repaso del día"
                font.family: zl.mono
                font.pixelSize: 9
                color: zl.tenue
            }
            Item { Layout.fillHeight: true }
        }

        // ---------- datos ----------
        ColumnLayout {
            anchors.fill: parent
            visible: root.installed || root.hasData
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: root.hasData ? String(root.pendientes) : "--"
                        font.family: zl.mono
                        font.pixelSize: 38
                        font.bold: true
                        color: root.hasData && root.pendientes === 0 ? zl.ok : zl.texto
                    }
                    Text {
                        text: root.hasData && root.pendientes === 0 ? "TODO AL DÍA" : "PENDIENTES HOY"
                        font.family: zl.mono
                        font.pixelSize: 8
                        font.letterSpacing: 1.5
                        color: zl.tenue
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    implicitWidth: 1
                    color: Qt.alpha(zl.acento, 0.25)
                }

                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "󰈸 " + (root.hasData ? root.racha : "-")
                        font.family: zl.mono
                        font.pixelSize: 18
                        font.bold: true
                        color: root.racha > 0 ? zl.aviso : zl.tenue
                    }
                    Text {
                        text: root.racha === 1 ? "DÍA SEGUIDO" : "DÍAS SEGUIDOS"
                        font.family: zl.mono
                        font.pixelSize: 8
                        font.letterSpacing: 1.5
                        color: zl.tenue
                    }
                }

                Item { Layout.fillWidth: true }

                Item {
                    Layout.preferredWidth: 66
                    Layout.preferredHeight: 66
                    Layout.alignment: Qt.AlignVCenter
                    ZlRing {
                        anchors.fill: parent
                        value: root.hasData ? root.dominio : 0
                        fillColor: zl.acento
                        trackColor: Qt.alpha(zl.acento, 0.18)
                        lineWidth: 4
                    }
                    Column {
                        anchors.centerIn: parent
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.hasData ? Math.round(root.dominio * 100) + "%" : "--"
                            font.family: zl.mono
                            font.pixelSize: 13
                            font.bold: true
                            color: zl.texto
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DOMINIO"
                            font.family: zl.mono
                            font.pixelSize: 6
                            font.letterSpacing: 1
                            color: zl.tenue
                        }
                    }
                }
            }

            // Próximo plazo
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 22
                radius: 2
                color: Qt.alpha(zl.superficie, 0.6)
                border.width: 1
                border.color: Qt.alpha(root.plazo ? root.daysColor(root.plazo.dias) : zl.borde, 0.45)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6
                    Text {
                        text: "PLAZO"
                        font.family: zl.mono
                        font.pixelSize: 8
                        font.letterSpacing: 1.5
                        color: zl.tenue
                    }
                    Text {
                        visible: !!root.plazo && root.plazo.unidad !== ""
                        text: root.plazo ? "U" + root.plazo.unidad : ""
                        font.family: zl.mono
                        font.pixelSize: 9
                        font.bold: true
                        color: zl.acento2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.plazo ? root.plazo.titulo : (root.hasData ? "sin plazos a la vista" : "abre ZeroStudy para ver tus datos")
                        elide: Text.ElideRight
                        font.family: zl.mono
                        font.pixelSize: 9
                        color: root.plazo ? zl.texto : zl.tenue
                    }
                    Text {
                        visible: !!root.plazo
                        text: root.plazo ? root.daysText(root.plazo.dias) : ""
                        font.family: zl.mono
                        font.pixelSize: 10
                        font.bold: true
                        color: root.plazo ? root.daysColor(root.plazo.dias) : zl.tenue
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ZlButton {
                    theme: zl
                    Layout.fillWidth: true
                    primary: true
                    active: root.installed
                    glyph: "▶"
                    text: "REPASAR"
                    onClicked: root.launch(["--repaso"])
                }
                ZlButton {
                    theme: zl
                    Layout.fillWidth: true
                    active: root.installed
                    glyph: "↗"
                    text: "ABRIR"
                    onClicked: root.launch([])
                }
            }
        }
    }
}
