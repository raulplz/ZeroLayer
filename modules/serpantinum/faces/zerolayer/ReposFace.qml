import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · GIT://REPOS, repos con cambios o commits sin subir.
// Carpetas: «reposDirs» en ~/.config/zerolayer/serpantinum.json (lista o texto).
// Solo lee (git status sin bloqueos). Un clic abre la terminal en el repo
// (con lazygit si está instalado).
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 140
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.6
    property real maxAspect: 3.5

    ZlTheme { id: zl }
    ZlConfig {
        id: cfg
        onChanged: root.refresh()
    }

    readonly property var defaultDirs: ["~/Proyectos", "~/proyectos", "~/Projects", "~/projects", "~/src", "~/code", "~/dev"]
    readonly property var dirs: {
        let d = cfg.data.reposDirs;
        if (typeof d === "string" && d !== "") d = [d];
        if (!Array.isArray(d) || d.length === 0) d = root.defaultDirs;
        return d.map(x => cfg.expandHome(x));
    }
    readonly property string probe: decodeURIComponent(Qt.resolvedUrl("zl_probe.py").toString().replace(/^file:\/\//, ""))

    property var repos: []
    property int total: 0
    property bool loaded: false
    property bool gitOk: true

    function refresh() {
        if (!cfg.ready) return;
        if (!proc.running) proc.running = true;
    }

    Process {
        id: proc
        command: ["python3", "-I", root.probe, "repos"].concat(root.dirs)
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let j = JSON.parse(this.text);
                    root.gitOk = j.git;
                    root.total = j.total;
                    root.repos = j.repos;
                    root.loaded = true;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 90000
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }
    onVisibleChanged: if (visible) refresh()

    function openRepo(path) {
        Quickshell.execDetached([
            "xdg-terminal-exec", "--title=GIT · " + path.split("/").pop(),
            "bash", "-lc", 'cd "$1" || exit; if command -v lazygit >/dev/null; then exec lazygit; else exec "${SHELL:-bash}"; fi', "_", path
        ]);
    }

    function shortPath(p) {
        return p.startsWith(cfg.home) ? "~" + p.substring(cfg.home.length) : p;
    }

    ZlFrame {
        theme: zl
        title: "GIT://REPOS"
        badge: root.loaded ? (root.repos.length + "/" + root.total + " PENDIENTES") : "…"
        badgeColor: root.repos.length > 0 ? zl.aviso : Qt.alpha(zl.acento, 0.7)

        Text {
            anchors.centerIn: parent
            width: parent.width
            visible: root.loaded && root.repos.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            lineHeight: 1.3
            text: !root.gitOk ? "// git no está instalado"
                : root.total === 0 ? "// sin repos en\n" + root.dirs.map(root.shortPath).join(" · ")
                : "✓ todo subido\n" + root.total + " repos al día"
            font.family: zl.mono
            font.pixelSize: 10
            color: root.total > 0 ? zl.ok : zl.tenue
        }

        ListView {
            anchors.fill: parent
            clip: true
            spacing: 2
            visible: root.repos.length > 0
            model: root.repos
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                width: ListView.view.width
                height: 30
                radius: 3
                color: hover.containsMouse ? Qt.alpha(zl.acento, 0.16) : "transparent"
                border.width: hover.containsMouse ? 1 : 0
                border.color: Qt.alpha(zl.acento, 0.6)

                Rectangle {
                    width: 2
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.modelData.ahead > 0 ? zl.acento : row.modelData.changes > 0 ? zl.aviso : zl.tenue
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 6
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            font.family: zl.mono
                            font.pixelSize: 11
                            color: zl.texto
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "󰘬 " + row.modelData.branch
                            elide: Text.ElideRight
                            font.family: zl.mono
                            font.pixelSize: 8
                            color: zl.tenue
                        }
                    }
                    Text {
                        visible: row.modelData.changes > 0
                        text: "±" + row.modelData.changes
                        font.family: zl.mono
                        font.pixelSize: 10
                        font.bold: true
                        color: zl.aviso
                    }
                    Text {
                        visible: row.modelData.ahead > 0
                        text: "↑" + row.modelData.ahead
                        font.family: zl.mono
                        font.pixelSize: 10
                        font.bold: true
                        color: zl.acento
                    }
                    Rectangle {
                        visible: row.modelData.remote && !row.modelData.upstream
                        implicitWidth: tag.implicitWidth + 8
                        implicitHeight: 14
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(zl.tenue, 0.6)
                        Text {
                            id: tag
                            anchors.centerIn: parent
                            text: "SIN UPSTREAM"
                            font.family: zl.mono
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            color: zl.tenue
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openRepo(row.modelData.path)
                }
            }
        }
    }
}
