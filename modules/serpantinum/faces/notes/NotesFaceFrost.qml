import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

// ZerØLayer (ZeroLayer) · notas rápidas como archivos .md/.txt sueltos.
// Carpeta: «notesDir» en ~/.config/zerolayer/serpantinum.json (por defecto ~/Notas).
// «+» crea una nota y se escribe dentro del widget (guardado automático).
// Esc o «‹» guarda y vuelve a la lista; «↗» abre en el editor de Omarchy;
// la papelera mueve el archivo a <carpeta>/.papelera (no borra).
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 220
    property real minHeight: 160
    property real maxWidth: 700
    property real maxHeight: 700
    property real minAspect: 0.5
    property real maxAspect: 3.0

    readonly property color ice: ThemeBackend.blue
    readonly property string mono: "JetBrainsMono Nerd Font"
    property string notesDir: Quickshell.env("HOME") + "/Notas"

    property var notes: []
    property bool editing: false
    property string editPath: ""          // vacío = nota nueva aún sin archivo
    property string editName: ""
    property bool dirty: false
    property bool pendingSave: false
    property bool loadingNote: false
    property bool confirmDelete: false
    property string statusText: ""
    property real nowTick: Date.now()

    // Widget.qml da foco de teclado a la capa cuando la cara lo pide
    readonly property bool keyboardFocus: editing

    readonly property bool shown: root.Window.window ? root.Window.window.visible : true
    onShownChanged: if (!shown && editing) closeEditor()

    // ---------- utilidades ----------
    function relTime(sec) {
        let d = Math.max(0, Math.floor(root.nowTick / 1000 - sec));
        if (d < 60) return "ahora";
        if (d < 3600) return Math.floor(d / 60) + " min";
        if (d < 86400) return Math.floor(d / 3600) + " h";
        if (d < 86400 * 7) return Math.floor(d / 86400) + " d";
        return Qt.formatDate(new Date(sec * 1000), "dd/MM");
    }

    function slugify(text) {
        let first = (text || "").split("\n").find(l => l.trim() !== "") || "";
        first = first.replace(/^#+\s*/, "").trim().toLowerCase();
        first = first.normalize("NFD").replace(/[̀-ͯ]/g, "");
        first = first.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").substring(0, 40).replace(/-+$/, "");
        return first === "" ? "nota" : first;
    }

    FileView {
        id: zlConfig
        path: Quickshell.env("HOME") + "/.config/zerolayer/serpantinum.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyConfig(typeof text === "function" ? text() : text)
        onLoadFailed: root.applyConfig("{}")   // sin configuración: carpeta por defecto
    }

    function expandHome(p) {
        return String(p).replace(/^~(?=\/|$)/, Quickshell.env("HOME")).replace(/\/+$/, "");
    }

    function applyConfig(raw) {
        try {
            let c = JSON.parse(raw || "{}");
            let d = c.notesDir ? root.expandHome(c.notesDir) : "";
            if (d !== "") root.notesDir = d;
        } catch (e) {}
        root.configReady = true;
        root.refresh();
    }

    // ---------- lista ----------
    readonly property string listScript: '
d="$1"; mkdir -p "$d"
find "$d" -maxdepth 1 -type f \\( -name "*.md" -o -name "*.txt" \\) -printf "%T@\\t%f\\n" | sort -rn | head -60 |
while IFS=$(printf "\\t") read -r t f; do
  title=$(grep -m1 -v "^[[:space:]]*$" "$d/$f" | sed "s/^#\\+ *//" | tr "\\t" " ")
  snip=$(grep -v "^[[:space:]]*$" "$d/$f" | sed -n "2,3p" | tr "\\t\\n" "  ")
  printf "%s\\t%s\\t%s\\t%s\\n" "${t%.*}" "$f" "$title" "$snip"
done'

    property bool configReady: false
    property bool refreshPending: false

    function refresh() {
        if (!root.configReady) return;      // la primera lectura espera a la configuración
        if (listProc.running) {
            root.refreshPending = true;     // se repite al terminar la lectura en curso
            return;
        }
        listProc.running = true;
    }

    Process {
        id: listProc
        command: ["bash", "-c", root.listScript, "_", root.notesDir]
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                root.refresh();
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let out = [];
                let lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i] === "") continue;
                    let p = lines[i].split("\t");
                    if (p.length < 2) continue;
                    out.push({ mtime: parseInt(p[0]) || 0, file: p[1], title: p[2] || p[1], snippet: p[3] || "" });
                }
                root.notes = out;
                root.nowTick = Date.now();
            }
        }
    }

    Timer {
        interval: 15000
        running: root.shown && !root.editing
        repeat: true
        onTriggered: root.refresh()
    }


    // ---------- edición ----------
    function newNote() {
        root.editPath = "";
        root.editName = "nueva nota";
        root.confirmDelete = false;
        editor.text = "";
        root.dirty = false;
        root.statusText = "sin guardar";
        root.editing = true;
        Qt.callLater(() => editor.forceActiveFocus());
    }

    function openNote(n) {
        root.editPath = root.notesDir + "/" + n.file;
        root.editName = n.file;
        root.confirmDelete = false;
        editor.text = "";
        root.statusText = "cargando…";
        root.loadingNote = true;
        readProc.command = ["cat", "--", root.editPath];
        readProc.running = true;
        root.editing = true;
    }

    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: {
                editor.text = this.text;
                root.loadingNote = false;
                root.dirty = false;
                root.statusText = "guardado";
                editor.cursorPosition = editor.length;
                Qt.callLater(() => editor.forceActiveFocus());
            }
        }
    }

    function saveNow() {
        saveTimer.stop();
        if (!root.dirty) return;
        if (saveProc.running) {
            root.pendingSave = true;
            return;
        }
        let content = editor.text;
        if (root.editPath === "") {
            if (content.trim() === "") return;   // no crear archivos vacíos
            let stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HHmm");
            root.editName = stamp + "_" + root.slugify(content) + ".md";
            root.editPath = root.notesDir + "/" + root.editName;
        }
        root.dirty = false;
        root.statusText = "guardando…";
        saveProc.command = ["bash", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv -f -- "$1.tmp" "$1"',
            "_", root.editPath, content];
        saveProc.running = true;
    }

    Process {
        id: saveProc
        onExited: (code, status) => {
            root.statusText = code === 0 ? "guardado " + Qt.formatTime(new Date(), "HH:mm") : "error al guardar";
            if (code !== 0) root.dirty = true;
            if (root.pendingSave) {
                root.pendingSave = false;
                root.saveNow();
            }
            if (!root.editing) root.refresh();
        }
    }

    Timer {
        id: saveTimer
        interval: 1200
        onTriggered: root.saveNow()
    }

    function closeEditor() {
        root.saveNow();
        root.editing = false;
        root.confirmDelete = false;
        editor.focus = false;
        root.refresh();
    }

    function openExternal() {
        root.saveNow();
        let path = root.editPath;
        if (path === "") return;
        root.editing = false;
        Quickshell.execDetached(["bash", "-lc", 'exec omarchy-launch-editor "$1"', "_", path]);
    }

    function trashNote() {
        if (root.editPath === "") {
            root.dirty = false;
            root.editing = false;
            return;
        }
        if (!root.confirmDelete) {
            root.confirmDelete = true;
            confirmTimer.restart();
            return;
        }
        saveTimer.stop();
        root.dirty = false;
        Quickshell.execDetached(["bash", "-c",
            'mkdir -p "$1/.papelera" && mv -n -- "$2" "$1/.papelera/$(date +%s)_$(basename "$2")"',
            "_", root.notesDir, root.editPath]);
        root.editing = false;
        root.confirmDelete = false;
        refreshLater.restart();
    }

    Timer { id: confirmTimer; interval: 3000; onTriggered: root.confirmDelete = false }
    Timer { id: refreshLater; interval: 400; onTriggered: root.refresh() }

    // ---------- botón pequeño reutilizable ----------
    component TinyButton: Rectangle {
        id: tb
        property string glyph: ""
        property color tint: root.ice
        signal clicked()
        width: 24
        height: 22
        radius: 3
        color: tbArea.containsMouse ? Qt.alpha(tb.tint, 0.2) : "transparent"
        border.width: 1
        border.color: Qt.alpha(tb.tint, tbArea.containsMouse ? 0.8 : 0.35)
        Text {
            anchors.centerIn: parent
            text: tb.glyph
            font.family: ThemeBackend.iconFont
            font.pixelSize: 13
            color: tb.tint
        }
        MouseArea {
            id: tbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tb.clicked()
        }
    }

    // ---------- interfaz ----------
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.crust, 0.62)
        radius: 4
        border.width: 1
        border.color: Qt.alpha(root.ice, 0.35)

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        // ===== Lista =====
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            visible: !root.editing

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "> NOTAS://LOCAL"
                    font.family: root.mono
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    color: root.ice
                }
                Text {
                    Layout.fillWidth: true
                    text: "[" + (root.notes.length < 10 ? "0" : "") + root.notes.length + "]"
                    font.family: root.mono
                    font.pixelSize: 10
                    color: Qt.alpha(root.ice, 0.6)
                }
                TinyButton {
                    glyph: "󰉋"
                    onClicked: Quickshell.execDetached(["xdg-open", root.notesDir])
                }
                TinyButton {
                    glyph: "󰐕"
                    onClicked: root.newNote()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(root.ice, 0.3)
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.notes
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: list.width
                    height: 40
                    radius: 3
                    color: rowArea.containsMouse ? Qt.alpha(root.ice, 0.16) : "transparent"
                    border.width: rowArea.containsMouse ? 1 : 0
                    border.color: Qt.alpha(root.ice, 0.55)

                    Rectangle {
                        width: 2
                        height: parent.height - 12
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.ice
                        opacity: rowArea.containsMouse ? 0.9 : 0.35
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                font.family: root.mono
                                font.pixelSize: 12
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.relTime(modelData.mtime)
                                font.family: root.mono
                                font.pixelSize: 9
                                color: Qt.alpha(root.ice, 0.65)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.snippet !== "" ? modelData.snippet : modelData.file
                            font.family: root.mono
                            font.pixelSize: 10
                            color: Qt.alpha(ThemeBackend.text, 0.5)
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openNote(modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.notes.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "// sin notas\npulsa + para crear una"
                    font.family: root.mono
                    font.pixelSize: 10
                    lineHeight: 1.3
                    color: Qt.alpha(root.ice, 0.55)
                }
            }
        }

        // ===== Editor =====
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            visible: root.editing

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TinyButton {
                    glyph: "󰁍"
                    onClicked: root.closeEditor()
                }
                Text {
                    Layout.fillWidth: true
                    text: "> " + root.editName
                    font.family: root.mono
                    font.pixelSize: 10
                    font.bold: true
                    color: root.ice
                    elide: Text.ElideMiddle
                }
                TinyButton {
                    glyph: "󰏌"
                    visible: root.editPath !== ""
                    onClicked: root.openExternal()
                }
                TinyButton {
                    glyph: root.confirmDelete ? "󰄬" : "󰩹"
                    tint: root.confirmDelete ? ThemeBackend.red : root.ice
                    onClicked: root.trashNote()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(root.ice, 0.3)
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                TextArea {
                    id: editor
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    persistentSelection: true
                    font.family: root.mono
                    font.pixelSize: 12
                    color: ThemeBackend.text
                    selectionColor: Qt.alpha(root.ice, 0.45)
                    selectedTextColor: ThemeBackend.text
                    placeholderText: "# título\nescribe aquí…"
                    placeholderTextColor: Qt.alpha(root.ice, 0.4)
                    leftPadding: 2
                    rightPadding: 2
                    topPadding: 2
                    bottomPadding: 2
                    background: null

                    onTextChanged: {
                        if (!root.editing || root.loadingNote) return;
                        root.dirty = true;
                        root.statusText = "editando…";
                        saveTimer.restart();
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.closeEditor();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                            root.saveNow();
                            event.accepted = true;
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.statusText + "  ·  esc guarda y cierra"
                font.family: root.mono
                font.pixelSize: 9
                font.letterSpacing: 1
                color: Qt.alpha(root.ice, 0.55)
                elide: Text.ElideRight
            }
        }
    }
}
