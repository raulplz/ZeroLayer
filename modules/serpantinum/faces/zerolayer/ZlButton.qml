import QtQuick

// ZerØLayer (ZeroLayer) · botón rectangular de los widgets ZerØ.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Rectangle {
    id: btn
    required property var theme
    property string text: ""
    property string glyph: ""
    property bool primary: false
    property bool active: true
    property int fontSize: 10
    signal clicked()

    implicitHeight: 26
    implicitWidth: label.implicitWidth + 20
    radius: 3
    opacity: active ? 1 : 0.4
    color: primary
        ? (mouse.containsMouse && active ? Qt.alpha(theme.acento, 0.45) : Qt.alpha(theme.acento, 0.28))
        : (mouse.containsMouse && active ? Qt.alpha(theme.acento, 0.18) : "transparent")
    border.width: 1
    border.color: Qt.alpha(theme.acento, primary || mouse.containsMouse ? 0.8 : 0.4)

    Text {
        id: label
        anchors.centerIn: parent
        text: (btn.glyph !== "" ? btn.glyph + "  " : "") + btn.text
        font.family: btn.theme.mono
        font.pixelSize: btn.fontSize
        font.bold: btn.primary
        font.letterSpacing: 1.5
        color: btn.primary ? btn.theme.texto : btn.theme.acento
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.active
        cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: btn.clicked()
    }
}
