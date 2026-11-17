"""Cambios mínimos de ZerØLayer en el código de Serpantinum.

Uso: python3 -I patch.py check|apply|revert <carpeta src/quickshell>

Cada cambio es un par (original -> nuevo) y el texto nuevo lleva la marca
«ZeroLayer». «apply» no escribe nada si algún original no aparece (otra versión
de Serpantinum); «revert» devuelve solo nuestras líneas a su forma original,
así que respeta lo demás aunque Serpantinum se haya actualizado entretanto.

Este archivo modifica código de Serpantinum (AGPL-3.0): ver LICENSE.md.
"""

import sys
from pathlib import Path

MARK = "ZeroLayer"

REG_NOTES_DEFAULT = (
    '                "default": { file: "faces/notes/NotesFace.qml", icon: "1", label: typeof I18n !== "undefined" '
    '? I18n.t("widgets.variants.default", "Default") : "Default" }'
)
REG_CONTINUOUS = (
    '                "continuous": { file: "faces/visualizer/VisualizerFaceContinuous.qml", icon: "2", '
    'label: I18n.t("widgets.variants.continuous") }'
)
REG_FROST = (
    '                "frost": { file: "faces/notes/NotesFaceFrost.qml", icon: "2", label: "Frost (.md)" } // ZeroLayer\n'
)

# Tipos de widget nuevos: (tipo, nombre, icono Nerd Font, ancho, alto, cara).
NEW_TYPES = [
    ("aichats", "Chats IA", "0xF06A9", 315, 190, "faces/aichats/AiChatsFace.qml"),
    ("zerostudy", "ZeroStudy", "0xF0474", 315, 180, "faces/zerolayer/ZeroStudyFace.qml"),
    ("zlagenda", "Agenda", "0xF00ED", 300, 270, "faces/zerolayer/AgendaFace.qml"),
    ("zlpomodoro", "Pomodoro", "0xF13AB", 315, 170, "faces/zerolayer/PomodoroFace.qml"),
    ("zlrepos", "Repos git", "0xF02A2", 300, 230, "faces/zerolayer/ReposFace.qml"),
    ("zldocker", "Docker", "0xF0868", 300, 170, "faces/zerolayer/DockerFace.qml"),
    ("zeroagents", "ZeroAgents", "0xF0849", 315, 80, "faces/zerolayer/ZeroAgentsFace.qml"),
    ("zlgames", "Juegos", "0xF02B4", 300, 320, "faces/zerolayer/GamesFace.qml"),
]


def reg_type(tid, name, icon, w, h, face):
    label = "Chats" if tid == "aichats" else "ZerØ"
    return (
        f'        "{tid}": {{\n'
        f'            name: "{name}",\n'
        f"            icon: String.fromCodePoint({icon}),\n"
        f"            defaultWidth: {w},\n"
        f"            defaultHeight: {h},\n"
        '            defaultVariant: "default",\n'
        "            variants: {\n"
        f'                "default": {{ file: "{face}", icon: "1", label: "{label}" }}\n'
        "            }\n"
        "        }"
    )


REG_TYPES = ",\n".join(reg_type(*t) for t in NEW_TYPES) + "\n"
REG_TYPES_020 = reg_type(*NEW_TYPES[0]) + "\n"  # módulo 0.2.0: solo «Chats IA»

# Cada cambio: (archivo, original, nuevo[, [versiones anteriores de «nuevo»]]).
EDITS = [
    # Widgets visibles solo en el escritorio (workspace) vacío.
    (
        "widgets/Widget.qml",
        'import Quickshell.Wayland\nimport "../"\n\nPanelWindow {\n    id: root\n    color: "transparent"\n',
        'import Quickshell.Wayland\nimport Quickshell.Hyprland // ZeroLayer\nimport "../"\n\n'
        'PanelWindow {\n    id: root\n    color: "transparent"\n'
        "    // ZeroLayer: los widgets solo se ven en un escritorio sin ventanas\n"
        "    readonly property var zlWorkspace: Hyprland.focusedWorkspace\n"
        "    readonly property bool zlDesktopEmpty: zlWorkspace !== null && zlWorkspace.toplevels.values.length === 0\n"
        "    visible: isRedacting || zlDesktopEmpty\n",
    ),
    (
        "widgets/WidgetLoader.qml",
        "            visible: !loaderRoot.isRedacting && !(model.isRemoving || false)\n",
        "            visible: !loaderRoot.isRedacting && zlDesktopEmpty && !(model.isRemoving || false) // ZeroLayer\n",
    ),
    # Registro de las caras nuevas.
    (
        "widgets/WidgetRegistry.qml",
        REG_CONTINUOUS + "\n",
        REG_CONTINUOUS + ",\n"
        '                "hacker": { file: "faces/visualizer/VisualizerFaceHacker.qml", icon: "3", label: "Hacker" } // ZeroLayer\n',
    ),
    (
        "widgets/WidgetRegistry.qml",
        REG_NOTES_DEFAULT + "\n            }\n        }\n    })\n",
        REG_NOTES_DEFAULT + ",\n" + REG_FROST + "            }\n        },\n"
        "        // >>> ZeroLayer\n" + REG_TYPES + "        // <<< ZeroLayer\n    })\n",
        [
            REG_NOTES_DEFAULT + ",\n" + REG_FROST + "            }\n        },\n"
            "        // >>> ZeroLayer\n" + REG_TYPES_020 + "        // <<< ZeroLayer\n    })\n"
        ],
    ),
    # GitHub compacto: cabe en 300 px y enseña siempre las semanas recientes.
    (
        "widgets/faces/github/GithubFace.qml",
        "    property real minWidth: Scaler.s(520)\n",
        "    property real minWidth: Scaler.s(280) // ZeroLayer\n"
        "    readonly property bool compact: width < Scaler.s(480) // ZeroLayer: oculta año y día seleccionado\n",
    ),
    (
        "widgets/faces/github/GithubFace.qml",
        "                NumberSelector {\n                    id: yearSelector\n",
        "                NumberSelector {\n                    id: yearSelector\n"
        "                    visible: !root.compact // ZeroLayer\n",
    ),
    (
        "widgets/faces/github/GithubFace.qml",
        "                ClickButton {\n                    Layout.preferredWidth: Scaler.s(142)\n",
        "                ClickButton {\n                    visible: !root.compact // ZeroLayer\n"
        "                    Layout.preferredWidth: Scaler.s(142)\n",
    ),
    (
        "widgets/faces/github/GithubFace.qml",
        "                    flickableDirection: Flickable.HorizontalFlick\n                    clip: true\n",
        "                    flickableDirection: Flickable.HorizontalFlick\n                    clip: true\n"
        "                    onContentWidthChanged: Qt.callLater(root.scrollToLatest) // ZeroLayer\n"
        "                    onWidthChanged: Qt.callLater(root.scrollToLatest) // ZeroLayer\n",
    ),
]


def plan(root: Path, mode: str):
    """Devuelve {archivo: texto nuevo} y la lista de problemas."""
    texts, problems, notes = {}, [], []
    for rel, old, new, *legacy in EDITS:
        legacy = legacy[0] if legacy else []
        path = root / rel
        if rel not in texts:
            if not path.is_file():
                problems.append(f"falta {rel}")
                texts[rel] = None
                continue
            texts[rel] = path.read_text(encoding="utf-8")
        text = texts[rel]
        if text is None:
            continue
        if mode in ("apply", "check"):
            prev = next((x for x in legacy if x in text), None)
            if new in text:
                notes.append(f"ya estaba: {rel}")
            elif prev is not None:
                texts[rel] = text.replace(prev, new)  # cambio de una versión anterior del módulo
            elif text.count(old) == 1:
                texts[rel] = text.replace(old, new)
            else:
                problems.append(f"no reconozco {rel} (¿otra versión de Serpantinum?)")
        else:  # revert
            for cur in [new] + legacy:
                if cur in text:
                    texts[rel] = text.replace(cur, old)
                    break
    return texts, problems, notes


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("check", "apply", "revert"):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    mode, root = sys.argv[1], Path(sys.argv[2]).expanduser()
    texts, problems, _ = plan(root, mode)
    if problems and mode != "revert":
        for p in problems:
            print(p, file=sys.stderr)
        return 1
    if mode == "check":
        return 0
    for rel, text in texts.items():
        if text is None:
            continue
        path = root / rel
        if path.read_text(encoding="utf-8") != text:
            path.write_text(text, encoding="utf-8")
    left = [rel for rel, text in texts.items() if text and mode == "revert" and MARK in text]
    for rel in sorted(set(left)):
        print(f"aviso: quedan marcas {MARK} en {rel}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
