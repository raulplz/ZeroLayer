import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · AGENDA://MES, calendario del mes y próximos plazos.
// Plazos: «agendaFile» en ~/.config/zerolayer/serpantinum.json, un .md con una
// tabla cuya columna «Fecha» lleva AAAA-MM-DD (también «Qué/Evento/Título»,
// «Unidad» y «Estado»; se ocultan los «entregado/hecho»). Sin archivo: solo el calendario.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 200
    property real maxWidth: 600
    property real maxHeight: 700
    property real minAspect: 0.6
    property real maxAspect: 2.5

    ZlTheme { id: zl }
    ZlConfig { id: cfg }

    readonly property string agendaFile: typeof cfg.data.agendaFile === "string" && cfg.data.agendaFile !== "" ? cfg.expandHome(cfg.data.agendaFile) : ""
    readonly property var months: ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

    property var events: []
    property bool fileOk: false
    property var todayDate: new Date()
    property int offset: 0                       // meses respecto al actual
    readonly property var shownMonth: new Date(todayDate.getFullYear(), todayDate.getMonth() + offset, 1)

    function midnight(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
    function daysFromToday(d) { return Math.round((midnight(d) - midnight(todayDate)) / 86400000); }
    function key(d) { return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate(); }

    function clean(s) {
        return String(s || "").replace(/\[\[([^\]|]*\|)?([^\]]*)\]\]/g, "$2").replace(/\*\*|__|`/g, "").trim();
    }

    function parse(raw) {
        let out = [];
        let lines = String(raw || "").split("\n");
        let cols = null;
        for (let i = 0; i < lines.length; i++) {
            let l = lines[i].trim();
            if (!l.startsWith("|")) { cols = null; continue; }
            let cells = l.replace(/^\||\|$/g, "").split("|").map(c => c.trim());
            let next = (lines[i + 1] || "").trim();
            if (cols === null && /^\|?\s*:?-{3,}/.test(next)) {
                let find = re => cells.findIndex(c => re.test(c.toLowerCase()));
                cols = {
                    date: Math.max(0, find(/^(fecha|date|día|dia|cuándo|cuando)/)),
                    title: find(/^(qué|que|evento|título|titulo|title|tarea|asunto|entrega)/),
                    unit: find(/^(unidad|asignatura|materia|etiqueta|tag)/),
                    status: find(/^(estado|status)/)
                };
                i++;                                 // salta la fila separadora
                continue;
            }
            if (cols === null) continue;
            let m = /(\d{4})-(\d{2})-(\d{2})/.exec(cells[cols.date] || "");
            if (!m) continue;
            let status = cols.status >= 0 ? (cells[cols.status] || "").toLowerCase() : "";
            if (/entregad|hecho|done|complet|cancel/.test(status)) continue;
            let title = cols.title >= 0 ? cells[cols.title] : cells.filter((c, k) => k !== cols.date).sort((a, b) => b.length - a.length)[0];
            out.push({
                date: new Date(+m[1], +m[2] - 1, +m[3]),
                title: clean(title).replace(/\s*\([^)]*\)\s*$/, ""),
                unit: cols.unit >= 0 ? clean(cells[cols.unit]) : "",
                status: status
            });
        }
        out.sort((a, b) => a.date - b.date);
        root.events = out;
    }

    FileView {
        id: file
        path: root.agendaFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root.fileOk = true; root.parse(typeof text === "function" ? text() : text); }
        onLoadFailed: { root.fileOk = false; root.events = []; }
    }

    // Cambio de día y relectura (por si el archivo se reescribe con un renombrado).
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.todayDate = new Date();
            if (root.agendaFile !== "") file.reload();
        }
    }

    readonly property var marks: {
        let m = {};
        for (let e of root.events) {
            let k = key(e.date);
            let d = daysFromToday(e.date);
            if (m[k] === undefined || d < m[k]) m[k] = d;
        }
        return m;
    }
    readonly property var upcoming: root.events.filter(e => daysFromToday(e.date) >= 0)

    function urgency(d) {
        if (d < 0) return Qt.alpha(zl.tenue, 0.6);
        if (d <= 7) return zl.peligro;
        if (d <= 21) return zl.aviso;
        return zl.ok;
    }

    readonly property var cells: {
        let first = shownMonth;
        let lead = (first.getDay() + 6) % 7;     // lunes primero
        let out = [];
        for (let i = 0; i < 42; i++) {
            let d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i);
            out.push(d);
        }
        // Quita la última semana si es entera del mes siguiente.
        if (out[35].getMonth() !== first.getMonth()) out = out.slice(0, 35);
        return out;
    }

    ZlFrame {
        theme: zl
        title: "AGENDA://" + root.months[root.shownMonth.getMonth()] + "·" + root.shownMonth.getFullYear()
        badge: "HOY " + root.todayDate.getDate()
        headerExtra: [
            Text {
                text: "‹"
                font.family: zl.mono
                font.pixelSize: 13
                color: zl.acento
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.offset-- }
            },
            Text {
                text: "›"
                font.family: zl.mono
                font.pixelSize: 13
                color: zl.acento
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.offset++ }
            }
        ]

        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 1
                columnSpacing: 1
                readonly property real cellH: Math.max(14, Math.min(20, (root.height - 120) / 9))

                Repeater {
                    model: ["L", "M", "X", "J", "V", "S", "D"]
                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.family: zl.mono
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        color: Qt.alpha(zl.acento, 0.6)
                    }
                }

                Repeater {
                    model: root.cells
                    Rectangle {
                        id: cell
                        required property var modelData
                        readonly property bool inMonth: modelData.getMonth() === root.shownMonth.getMonth()
                        readonly property bool isToday: root.key(modelData) === root.key(root.todayDate)
                        readonly property var mark: root.marks[root.key(modelData)]
                        Layout.fillWidth: true
                        Layout.preferredHeight: grid.cellH
                        radius: 2
                        color: isToday ? Qt.alpha(zl.acento, 0.85) : mark !== undefined && inMonth ? Qt.alpha(root.urgency(mark), 0.14) : "transparent"
                        border.width: mark !== undefined && inMonth && !isToday ? 1 : 0
                        border.color: mark !== undefined ? Qt.alpha(root.urgency(mark), 0.7) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            font.family: zl.mono
                            font.pixelSize: 9
                            font.bold: cell.isToday || cell.mark !== undefined
                            color: cell.isToday ? zl.fondo : !cell.inMonth ? Qt.alpha(zl.tenue, 0.35)
                                 : cell.mark !== undefined ? root.urgency(cell.mark) : zl.texto
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.alpha(zl.acento, 0.2)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: root.upcoming.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.agendaFile === "" ? "// sin plazos · «agendaFile» en serpantinum.json"
                        : !root.fileOk ? "// no encuentro " + root.agendaFile.split("/").pop()
                        : "// nada pendiente"
                    font.family: zl.mono
                    font.pixelSize: 9
                    color: zl.tenue
                }

                Column {
                    anchors.fill: parent
                    spacing: 2
                    clip: true
                    Repeater {
                        model: root.upcoming.slice(0, 6)
                        RowLayout {
                            id: ev
                            required property var modelData
                            readonly property int d: root.daysFromToday(modelData.date)
                            width: parent.width
                            height: 17
                            spacing: 6
                            Text {
                                text: Qt.formatDate(ev.modelData.date, "dd/MM")
                                font.family: zl.mono
                                font.pixelSize: 9
                                color: zl.tenue
                            }
                            Text {
                                visible: ev.modelData.unit !== ""
                                text: /^\d+$/.test(ev.modelData.unit) ? "U" + ev.modelData.unit : ev.modelData.unit
                                font.family: zl.mono
                                font.pixelSize: 9
                                font.bold: true
                                color: zl.acento2
                            }
                            Text {
                                Layout.fillWidth: true
                                text: ev.modelData.title
                                elide: Text.ElideRight
                                font.family: zl.mono
                                font.pixelSize: 9
                                color: zl.texto
                            }
                            Text {
                                text: ev.d === 0 ? "HOY" : ev.d + " D"
                                font.family: zl.mono
                                font.pixelSize: 9
                                font.bold: true
                                color: root.urgency(ev.d)
                            }
                        }
                    }
                }
            }
        }
    }
}
