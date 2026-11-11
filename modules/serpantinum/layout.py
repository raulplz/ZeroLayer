"""Genera la disposición de widgets ZerØLayer para un monitor.

Uso: python3 -I layout.py <ancho lógico> <alto lógico> <layout.json>

Columna izquierda: GitHub, notas y tiempo (300 px). Derecha: CPU, RAM,
temperatura, disco y chats de IA. Abajo: espectro de audio.
Coordenadas lógicas (píxeles / escala), igual que Serpantinum.
"""

import json
import sys
from pathlib import Path


def widget(wid, wtype, variant, x, y, w, h, opacity=0.9):
    return {
        "type": wtype,
        "wType": wtype,
        "wVariant": variant,
        "wX": round(x),
        "wY": round(y),
        "wWidth": round(w),
        "wHeight": round(h),
        "wOpacity": opacity,
        "wRotation": 0,
        "wImagePath": "",
        "imagePath": "",
        "wId": "zl-" + wid,
        "stretchWidth": False,
        "stretchHeight": False,
    }


def build(width, height):
    left, top = 80, 100
    right = width - 426  # columna de anillos (2 × 150 + hueco) y Claude
    return [
        widget("github", "github", "default", left, top, 300, 180),
        widget("notes", "notes", "frost", left, top + 200, 300, 250),
        widget("weather", "weather", "compact", left, top + 465, 300, 140),
        widget("cpu", "cpu", "circle", right, top, 150, 130),
        widget("ram", "ram", "circle", right + 165, top, 150, 130),
        widget("temp", "temp", "circle", right, top + 145, 150, 130),
        widget("disk", "disk", "circle", right + 165, top + 145, 150, 130),
        widget("chats", "aichats", "default", right, top + 295, 315, 190),
        widget("spectrum", "visualizer", "hacker", left, height - 160, width - 2 * left, 110, 0.75),
    ]


def main():
    if len(sys.argv) != 4:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    width, height = float(sys.argv[1]), float(sys.argv[2])
    out = Path(sys.argv[3]).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(build(width, height), indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
