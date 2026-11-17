"""ZerØLayer · paleta del tema activo en los ajustes de Serpantinum.

Uso:
  python3 -I serp-palette.py apply  <settings.json> <original.json> <serpantinum.json>   (JSON por stdin)
  python3 -I serp-palette.py revert <settings.json> <original.json>

«apply» lee por stdin {"nombre": "...", "colores": {fondo, superficie, borde, texto,
tenue, acento, acento2, ok, aviso, peligro[, naranja]} } y escribe los 22 colores de
Serpantinum en theme.colors de settings.json (que Serpantinum vigila y recarga en
caliente). Antes de la primera escritura guarda en <original.json> el bloque que
había (preset, matugen y colores); «revert» lo devuelve y borra esa copia.
Si serpantinum.json trae "themePalette": false, no toca nada.
"""

import json
import os
import sys
import tempfile

KEYS = ("activePreset", "matugen", "colors")


def mix(a, b, t):
    pa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    pb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{int(x + (y - x) * t + .5):02x}" for x, y in zip(pa, pb))


def palette(c):
    f, s, b, t, d, a = c["fondo"], c["superficie"], c["borde"], c["texto"], c["tenue"], c["acento"]
    peach = c.get("naranja") or mix(c["aviso"], c["peligro"], .4)
    return {
        "base": f, "mantle": mix(f, s, .5), "crust": mix(f, "#000000", .55),
        "text": t, "subtext0": d, "subtext1": mix(d, t, .6),
        "surface0": mix(f, a, .125), "surface1": mix(f, a, .27), "surface2": mix(f, a, .4),
        "overlay0": mix(f, d, .6), "overlay1": mix(f, d, .85), "overlay2": mix(d, t, .2),
        "blue": a, "sapphire": mix(a, t, .35), "peach": peach, "green": c["ok"],
        "red": c["peligro"], "mauve": a, "pink": mix(a, t, .6), "yellow": c["aviso"],
        "maroon": c["peligro"], "teal": c["acento2"],
    }


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save(path, data):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".zl_tmp_")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


def apply(settings, original, zlconf):
    try:
        if load(zlconf).get("themePalette") is False:
            return 0
    except (OSError, ValueError):
        pass
    if not os.path.isfile(settings):
        return 0
    data = load(settings)
    spec = json.load(sys.stdin)
    theme = data.setdefault("theme", {})
    if not os.path.exists(original):
        os.makedirs(os.path.dirname(original), exist_ok=True)
        with open(original, "w", encoding="utf-8") as fh:
            json.dump({k: theme.get(k, None) for k in KEYS}, fh)
    new = dict(theme)
    new["activePreset"] = spec.get("nombre") or "ZERØ"
    new["matugen"] = False
    new["colors"] = palette(spec["colores"])
    if new != theme:
        data["theme"] = new
        save(settings, data)
    return 0


def revert(settings, original):
    if not os.path.exists(original):
        return 0
    old = load(original)
    if os.path.isfile(settings):
        data = load(settings)
        theme = data.setdefault("theme", {})
        for k in KEYS:
            if old.get(k) is None:
                theme.pop(k, None)
            else:
                theme[k] = old[k]
        save(settings, data)
    os.remove(original)
    return 0


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "apply" and len(args) == 3:
        sys.exit(apply(*args))
    if cmd == "revert" and len(args) == 2:
        sys.exit(revert(*args))
    sys.exit(__doc__)
