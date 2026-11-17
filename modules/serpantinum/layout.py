"""Catálogo de widgets, perfiles y disposición del escritorio ZerØLayer.

Uso:
  python3 -I layout.py build <ancho> <alto> <layout.json> <config.json>
      escribe la disposición del monitor según «widgets» de la configuración
      (conserva los widgets añadidos a mano desde el editor de Serpantinum)
  python3 -I layout.py profiles            perfiles, una línea cada uno (para elegir)
  python3 -I layout.py catalog             widgets, una línea cada uno (para elegir)
  python3 -I layout.py ids <perfil>        widgets de un perfil
  python3 -I layout.py current <config>    perfil y widgets elegidos (dos líneas)
  python3 -I layout.py save <config> <perfil> [widget...]
  python3 -I layout.py get <config> <clave>          valor de una opción (texto)
  python3 -I layout.py set <config> <clave> <json>   cambia una opción (p. ej. reposDirs)

Columnas: izquierda (x = 80, 300 px) y derecha (315 px, a 426 px del borde);
si una se llena, sigue en otra columna hacia dentro. El espectro va abajo.
Coordenadas lógicas (píxeles / escala), igual que Serpantinum.
"""

import json
import sys
from pathlib import Path

# id: (nombre, descripción, [(tipo, variante, dx, dy, ancho, alto)], alto en columna, columna)
# Los «anillos» son cuatro widgets que van juntos en una rejilla 2×2.
CATALOG = {
    "github": ("GitHub", "contribuciones de tu usuario", [("github", "default", 0, 0, 300, 180)], 180, "left"),
    "notas": ("Notas", "notas .md que escribes en el propio widget", [("notes", "frost", 0, 0, 300, 250)], 250, "left"),
    "chats": ("Chats IA", "chats destacados de Claude Code o Codex", [("aichats", "default", 0, 0, 315, 190)], 190, "right"),
    "tiempo": ("Tiempo", "tiempo actual (Open-Meteo, sin clave)", [("weather", "compact", 0, 0, 300, 140)], 140, "left"),
    "reloj": ("Reloj", "hora y fecha", [("time", "digital", 0, 0, 300, 120)], 120, "left"),
    "musica": ("Música", "reproductor (cualquier app MPRIS)", [("music", "full", 0, 0, 315, 130)], 130, "right"),
    "sistema": ("Sistema", "anillos de CPU, RAM, temperatura y disco", [
        ("cpu", "circle", 0, 0, 150, 130), ("ram", "circle", 165, 0, 150, 130),
        ("temp", "circle", 0, 145, 150, 130), ("disk", "circle", 165, 145, 150, 130)], 275, "right"),
    "espectro": ("Espectro", "barras de audio estilo LED abajo", [], 0, "bottom"),
    "zerostudy": ("ZeroStudy", "repaso del día, racha, dominio y próximo plazo", [("zerostudy", "default", 0, 0, 315, 180)], 180, "right"),
    "agenda": ("Agenda", "calendario del mes y plazos de una tabla .md", [("zlagenda", "default", 0, 0, 300, 270)], 270, "left"),
    "pomodoro": ("Pomodoro", "bloques de foco y descanso con aviso", [("zlpomodoro", "default", 0, 0, 315, 170)], 170, "right"),
    "repos": ("Repos git", "repos con cambios o commits sin subir", [("zlrepos", "default", 0, 0, 300, 230)], 230, "left"),
    "docker": ("Docker", "contenedores (solo lectura)", [("zldocker", "default", 0, 0, 300, 170)], 170, "left"),
    "zeroagents": ("ZeroAgents", "abre el monitor de agentes; sesiones Claude activas", [("zeroagents", "default", 0, 0, 315, 80)], 80, "right"),
    "juegos": ("Juegos", "últimos juegos de Steam/Heroic, GPU y mando", [("zlgames", "default", 0, 0, 300, 320)], 320, "left"),
}

PROFILES = {
    "clasico": ("Clásico ZerØ", "GitHub, notas, tiempo, sistema, chats IA y espectro",
                ["github", "notas", "tiempo", "sistema", "chats", "espectro"]),
    "estudiante-dev": ("Estudiante + dev", "el clásico más ZeroStudy",
                       ["github", "notas", "tiempo", "sistema", "chats", "zerostudy", "espectro"]),
    "estudiante": ("Estudiante", "ZeroStudy, agenda, pomodoro, notas y chats IA",
                   ["zerostudy", "agenda", "pomodoro", "notas", "chats", "espectro"]),
    "dev": ("Dev", "GitHub, repos, Docker, sistema, ZeroAgents y chats IA",
            ["github", "repos", "docker", "sistema", "zeroagents", "chats", "espectro"]),
    "gamer": ("Gamer", "juegos recientes, GPU y mando, música y sistema",
              ["reloj", "juegos", "musica", "sistema", "tiempo", "espectro"]),
    "basico": ("Básico", "reloj, tiempo, agenda, música y notas",
               ["reloj", "tiempo", "agenda", "musica", "notas", "espectro"]),
}
DEFAULT_PROFILE = "clasico"  # lo que ponía la versión 0.2.0

GAP, TOP, LEFT, RIGHT_OFFSET = 20, 100, 80, 426


def widget(wid, wtype, variant, x, y, w, h, opacity=0.9):
    return {
        "type": wtype, "wType": wtype, "wVariant": variant,
        "wX": round(x), "wY": round(y), "wWidth": round(w), "wHeight": round(h),
        "wOpacity": opacity, "wRotation": 0, "wImagePath": "", "imagePath": "",
        "wId": "zl-" + wid, "stretchWidth": False, "stretchHeight": False,
    }


def sub_id(cid, wtype, parts):
    # Ids estables (los de 0.2.0: zl-github, zl-notes, zl-cpu…) para que el
    # editor de Serpantinum no los trate como nuevos.
    legacy = {"github": "github", "notas": "notes", "tiempo": "weather", "chats": "chats"}
    if cid == "sistema":
        return wtype
    return legacy.get(cid, cid) if parts == 1 else cid + "-" + wtype


def build(width, height, ids):
    ids = [i for i in ids if i in CATALOG]
    bottom = "espectro" in ids
    limit = height - (170 if bottom else 60)
    right = width - RIGHT_OFFSET
    # Columnas de cada lado, de fuera hacia dentro.
    columns = {"left": [[LEFT, TOP]], "right": [[right, TOP]]}
    out = []
    for cid in ids:
        _, _, parts, h, side = CATALOG[cid]
        if side == "bottom":
            continue
        other = "right" if side == "left" else "left"
        col = columns[side][-1]
        if col[1] + h > limit and col[1] > TOP:
            # Primero el otro lado; si tampoco cabe, otra columna hacia dentro.
            alt = columns[other][-1]
            if alt[1] + h <= limit:
                col = alt
            else:
                step = 320 if side == "left" else -335
                col = [col[0] + step, TOP]
                columns[side].append(col)
        for wtype, variant, dx, dy, w, wh in parts:
            out.append(widget(sub_id(cid, wtype, len(parts)), wtype, variant, col[0] + dx, col[1] + dy, w, wh))
        col[1] += h + GAP
    if bottom:
        out.append(widget("spectrum", "visualizer", "hacker", LEFT, height - 160, width - 2 * LEFT, 110, 0.75))
    return out


def read_json(path, default):
    try:
        return json.loads(Path(path).expanduser().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def chosen(cfg):
    w = cfg.get("widgets") if isinstance(cfg.get("widgets"), dict) else {}
    profile = w.get("profile") if w.get("profile") in PROFILES else DEFAULT_PROFILE
    ids = w.get("list")
    if not isinstance(ids, list) or not ids:
        ids = PROFILES[profile][2]
    return profile, [i for i in ids if i in CATALOG]


def cmd_build(width, height, layout_path, config_path):
    _, ids = chosen(read_json(config_path, {}))
    old = read_json(layout_path, [])
    # Lo que el usuario añadió desde el editor de Serpantinum (ids sin «zl-») se queda.
    keep = [w for w in old if isinstance(w, dict) and not str(w.get("wId", "")).startswith("zl-")]
    out = Path(layout_path).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(build(width, height, ids) + keep, indent=2) + "\n", encoding="utf-8")


def cmd_save(config_path, profile, ids):
    path = Path(config_path).expanduser()
    cfg = read_json(path, {})
    if profile not in PROFILES:
        raise SystemExit(f"perfil desconocido: {profile}")
    ids = [i for i in ids if i in CATALOG] or PROFILES[profile][2]
    # Orden del catálogo del perfil primero y después el resto, para una disposición estable.
    order = PROFILES[profile][2] + [k for k in CATALOG if k not in PROFILES[profile][2]]
    ids = sorted(set(ids), key=order.index)
    cfg["widgets"] = {"profile": profile, "list": ids}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def cmd_set(config_path, key, raw):
    path = Path(config_path).expanduser()
    cfg = read_json(path, {})
    try:
        value = json.loads(raw)
    except ValueError:
        value = raw
    if value in ("", None, []):
        cfg.pop(key, None)
    else:
        cfg[key] = value
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "build" and len(argv) == 6:
        cmd_build(float(argv[2]), float(argv[3]), argv[4], argv[5])
    elif cmd == "profiles":
        for pid, (name, desc, _) in PROFILES.items():
            print(f"{pid} · {name} — {desc.replace(', ', ' · ')}")
    elif cmd == "catalog":
        for cid, (name, desc, *_rest) in CATALOG.items():
            print(f"{cid} · {name} — {desc.replace(', ', ' · ')}")
    elif cmd == "ids" and len(argv) == 3 and argv[2] in PROFILES:
        print("\n".join(PROFILES[argv[2]][2]))
    elif cmd == "current" and len(argv) == 3:
        profile, ids = chosen(read_json(argv[2], {}))
        print(profile)
        print(" ".join(ids))
    elif cmd == "get" and len(argv) == 4:
        v = read_json(argv[2], {}).get(argv[3], "")
        print(" ".join(v) if isinstance(v, list) else v)
    elif cmd == "set" and len(argv) == 5:
        cmd_set(argv[2], argv[3], argv[4])
    elif cmd == "save" and len(argv) >= 4:
        cmd_save(argv[2], argv[3], argv[4:])
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
