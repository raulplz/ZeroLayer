import QtQuick
import Quickshell
import Quickshell.Io

// ZerØLayer (ZeroLayer) · lee ~/.config/zerolayer/serpantinum.json en caliente.
// «data» es el objeto JSON (vacío si falta); «ready» pasa a true tras la primera lectura.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Item {
    id: cfg
    visible: false
    width: 0
    height: 0

    property var data: ({})
    property bool ready: false
    signal changed()

    readonly property string home: Quickshell.env("HOME")

    function expandHome(p) {
        return String(p).replace(/^~(?=\/|$)/, cfg.home).replace(/\/+$/, "");
    }

    function set(raw) {
        let j = {};
        try { j = JSON.parse(raw || "{}") || {}; } catch (e) { j = {}; }
        cfg.data = j;
        cfg.ready = true;
        cfg.changed();
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (cfg.home + "/.config")) + "/zerolayer/serpantinum.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: cfg.set(typeof text === "function" ? text() : text)
        onLoadFailed: cfg.set("{}")
    }
}
