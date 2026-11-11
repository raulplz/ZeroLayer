import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

// ZerØLayer (ZeroLayer) · chats destacados de asistentes de IA (Claude Code, Codex u otros).
// Se eligen con «zerolayer configure serpantinum»; se guardan en
// ~/.config/zerolayer/serpantinum.json → "chats": [{ agent, id, label, cwd, icon, command? }].
// «command» (opcional) permite otra IA: se ejecuta con bash y recibe el id como $1.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 200
    property real minHeight: 150
    property real maxWidth: 500
    property real maxHeight: 400
    property real minAspect: 0.8
    property real maxAspect: 3.0

    readonly property color ice: ThemeBackend.blue
    readonly property string mono: "JetBrainsMono Nerd Font"

    // Cómo reanudar cada agente: el id llega como $1 y la carpeta como $2.
    readonly property var resumeCommands: ({
        "claude": 'cd "$2" 2>/dev/null; exec claude --resume "$1"',
        "codex": 'cd "$2" 2>/dev/null; exec codex resume "$1"'
    })

    property var chats: []

    FileView {
        id: zlConfig
        path: Quickshell.env("HOME") + "/.config/zerolayer/serpantinum.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyConfig(typeof text === "function" ? text() : text)
    }

    function expandHome(p) {
        return String(p).replace(/^~(?=\/|$)/, Quickshell.env("HOME")).replace(/\/+$/, "");
    }

    function applyConfig(raw) {
        try {
            let c = JSON.parse(raw || "{}");
            let list = Array.isArray(c.chats) ? c.chats : [];
            root.chats = list.filter(x => x && x.id).slice(0, 6).map(x => ({
                agent: String(x.agent || "claude").toLowerCase(),
                id: String(x.id),
                label: String(x.label || x.id),
                cwd: root.expandHome(x.cwd || "~"),
                icon: String(x.icon || "󰚩"),
                command: x.command ? String(x.command) : ""
            }));
        } catch (e) {}
    }

    function openChat(chat) {
        let script = chat.command !== "" ? 'cd "$2" 2>/dev/null; ' + chat.command : root.resumeCommands[chat.agent];
        if (!script) return;
        Quickshell.execDetached([
            "xdg-terminal-exec", "--title=" + chat.agent.toUpperCase() + " · " + chat.label,
            "bash", "-lc", script, "_", chat.id, chat.cwd
        ]);
    }

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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Text {
                text: "> IA://CHATS"
                font.family: root.mono
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
                color: root.ice
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(root.ice, 0.3)
            }

            Text {
                visible: root.chats.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                text: "// sin chats destacados\nzerolayer configure serpantinum"
                font.family: root.mono
                font.pixelSize: 10
                lineHeight: 1.3
                color: Qt.alpha(root.ice, 0.55)
            }

            Repeater {
                model: root.chats

                Rectangle {
                    id: entry
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 26
                    radius: 3
                    color: hover.containsMouse ? Qt.alpha(root.ice, 0.18) : "transparent"
                    border.width: hover.containsMouse ? 1 : 0
                    border.color: Qt.alpha(root.ice, 0.6)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "[0" + (index + 1) + "]"
                            font.family: root.mono
                            font.pixelSize: 10
                            color: Qt.alpha(root.ice, 0.6)
                        }
                        Text {
                            text: modelData.icon
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: 14
                            color: root.ice
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.label.toUpperCase()
                            font.family: root.mono
                            font.pixelSize: 12
                            font.letterSpacing: 1
                            color: hover.containsMouse ? ThemeBackend.text : Qt.alpha(ThemeBackend.text, 0.85)
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            implicitWidth: tag.implicitWidth + 8
                            implicitHeight: 14
                            radius: 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha(root.ice, 0.4)
                            Text {
                                id: tag
                                anchors.centerIn: parent
                                text: modelData.agent.toUpperCase()
                                font.family: root.mono
                                font.pixelSize: 8
                                font.letterSpacing: 1
                                color: Qt.alpha(root.ice, 0.75)
                            }
                        }
                        Text {
                            text: hover.containsMouse ? "↵" : "›"
                            font.family: root.mono
                            font.pixelSize: 12
                            color: root.ice
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openChat(modelData)
                    }
                }
            }
        }
    }
}
