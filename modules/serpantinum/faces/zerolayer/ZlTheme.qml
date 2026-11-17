import QtQuick
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · paleta y fuentes compartidas por los widgets ZerØ.
// Lee ~/.config/zerolayer/theme.json en caliente:
//   { "colores": { fondo, superficie, borde, texto, tenue, acento, acento2, ok, aviso, peligro },
//     "fuentes": { sans, mono } }
// Si falta el archivo (o una clave), usa la paleta Frost.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: theme
    visible: false
    width: 0
    height: 0

    readonly property var frost: ({
        fondo: "#080b10", superficie: "#111923", borde: "#1c2a3a", texto: "#d5dfeb", tenue: "#8292a6",
        acento: "#4da3ff", acento2: "#75c4e8", ok: "#8fbea0", aviso: "#e6bf79", peligro: "#ef7180"
    })
    readonly property string frostMono: "JetBrainsMono Nerd Font"
    readonly property string frostSans: "Inter Tight"

    property color fondo: frost.fondo
    property color superficie: frost.superficie
    property color borde: frost.borde
    property color texto: frost.texto
    property color tenue: frost.tenue
    property color acento: frost.acento
    property color acento2: frost.acento2
    property color ok: frost.ok
    property color aviso: frost.aviso
    property color peligro: frost.peligro
    property string mono: frostMono
    property string sans: frostSans
    property bool present: false

    function pick(obj, key, fallback) {
        let v = obj ? obj[key] : undefined;
        return (typeof v === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(v)) ? v : fallback;
    }

    function apply(raw) {
        let c = {}, f = {};
        try {
            let j = JSON.parse(raw || "{}");
            c = j.colores || {};
            f = j.fuentes || {};
            theme.present = true;
        } catch (e) {
            theme.present = false;
        }
        for (let k in theme.frost) theme[k] = theme.pick(c, k, theme.frost[k]);
        theme.mono = (typeof f.mono === "string" && f.mono !== "") ? f.mono : theme.frostMono;
        theme.sans = (typeof f.sans === "string" && f.sans !== "") ? f.sans : theme.frostSans;
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/zerolayer/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.apply(typeof text === "function" ? text() : text)
        onLoadFailed: theme.apply("")
    }

    // El archivo puede aparecer después (o reescribirse con un renombrado):
    // se vuelve a leer de vez en cuando.
    Timer {
        interval: theme.present ? 60000 : 15000
        running: true
        repeat: true
        onTriggered: file.reload()
    }
}
