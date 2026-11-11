"""Chats de IA para el widget «Chats IA» de ZerØLayer.

Uso:
  python3 -I chats.py list                      candidatos en JSON (Claude Code y Codex)
  python3 -I chats.py labels <candidatos.json>  una línea por candidato, para elegir
  python3 -I chats.py chosen <candidatos.json> <config.json>  líneas ya destacadas
  python3 -I chats.py save <config.json> <candidatos.json> <github> [índice...]

Solo lee metadatos de las sesiones (título, carpeta, fecha e id), nunca el
contenido de las conversaciones. Escribe únicamente el archivo de configuración.
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()
MAX_PER_AGENT = 25
MAX_CHOSEN = 6
ICONS = {"claude": "󰚩", "codex": "󰘦"}


def short(path):
    if not path:
        return ""
    p = str(path)
    return "~" + p[len(str(HOME)):] if p.startswith(str(HOME)) else p


def claude_sessions():
    """Sesiones de Claude Code con título (/rename o automático)."""
    base = Path(os.environ.get("CLAUDE_CONFIG_DIR", HOME / ".claude")) / "projects"
    out = []
    for f in base.glob("*/*.jsonl"):
        title = ai_title = cwd = None
        try:
            with f.open(encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    head = line[:40]
                    if '"custom-title"' in head or '"ai-title"' in head:
                        try:
                            d = json.loads(line)
                        except ValueError:
                            continue
                        if d.get("type") == "custom-title":
                            title = d.get("customTitle") or title
                        else:
                            ai_title = d.get("aiTitle") or ai_title
                    elif cwd is None and '"cwd":"' in line:
                        m = re.search(r'"cwd":"((?:[^"\\]|\\.)*)"', line)
                        if m:
                            cwd = json.loads('"' + m.group(1) + '"')
        except OSError:
            continue
        label = title or ai_title
        if not label or not cwd or cwd.startswith(("/tmp/", "/var/tmp/")):
            continue
        out.append({
            "agent": "claude",
            "id": f.stem,
            "label": label,
            "named": bool(title),
            "cwd": cwd,
            "updated": f.stat().st_mtime,
        })
    # Al continuar o compactar, Claude crea otra sesión con el mismo título:
    # de cada (título, carpeta) se queda la más reciente.
    out.sort(key=lambda c: c["updated"], reverse=True)
    seen, unique = set(), []
    for c in out:
        key = (c["label"], c["cwd"])
        if key not in seen:
            seen.add(key)
            unique.append(c)
    unique.sort(key=lambda c: (c["named"], c["updated"]), reverse=True)
    return unique[:MAX_PER_AGENT]


def codex_sessions():
    """Hilos de Codex con nombre (session_index.jsonl) y su carpeta."""
    base = Path(os.environ.get("CODEX_HOME", HOME / ".codex"))
    index = base / "session_index.jsonl"
    if not index.is_file():
        return []
    threads = {}
    for line in index.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("id") and d.get("thread_name"):
            threads[d["id"]] = d  # la última entrada de cada hilo manda
    recent = sorted(threads.values(), key=lambda d: d.get("updated_at", ""), reverse=True)[:MAX_PER_AGENT]
    out = []
    for d in recent:
        cwd = None
        for f in (base / "sessions").glob(f"*/*/*/rollout-*-{d['id']}.jsonl"):
            try:
                with f.open(encoding="utf-8", errors="replace") as fh:
                    meta = json.loads(fh.readline())
                cwd = (meta.get("payload") or {}).get("cwd")
            except (OSError, ValueError):
                pass
            break
        try:
            updated = datetime.fromisoformat(d.get("updated_at", "").replace("Z", "+00:00")).timestamp()
        except ValueError:
            updated = 0
        out.append({
            "agent": "codex",
            "id": d["id"],
            "label": d["thread_name"],
            "named": True,
            "cwd": cwd or str(HOME),
            "updated": updated,
        })
    return out


def cmd_list():
    print(json.dumps(claude_sessions() + codex_sessions(), ensure_ascii=False))


def cmd_labels(path):
    for i, c in enumerate(json.loads(Path(path).read_text(encoding="utf-8"))):
        when = datetime.fromtimestamp(c["updated"], timezone.utc).astimezone().strftime("%d/%m")
        label = re.sub(r"[\s,]+", " ", c["label"])[:48]  # sin comas: gum las usa de separador
        where = short(c["cwd"])
        where = where if len(where) <= 32 else "…" + where[-31:]
        print(f"{i:>2} │ {c['agent']:<6} │ {label} │ {where} │ {when}")


def cmd_chosen(cands_path, config_path):
    try:
        cfg = json.loads(Path(config_path).expanduser().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    ids = {(c.get("agent"), c.get("id")) for c in cfg.get("chats", []) if isinstance(c, dict)}
    cands = json.loads(Path(cands_path).read_text(encoding="utf-8"))
    print("\n".join(str(i) for i, c in enumerate(cands) if (c["agent"], c["id"]) in ids))


def cmd_save(config_path, cands_path, github, indices):
    cfg_file = Path(config_path).expanduser()
    try:
        cfg = json.loads(cfg_file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        cfg = {}
    cands = json.loads(Path(cands_path).read_text(encoding="utf-8")) if cands_path != "-" else []
    chats = []
    for raw in indices[:MAX_CHOSEN]:
        c = cands[int(raw)]
        chats.append({
            "agent": c["agent"],
            "id": c["id"],
            "label": re.sub(r"\s+", " ", c["label"])[:40],
            "cwd": short(c["cwd"]),
            "icon": ICONS.get(c["agent"], "󰚩"),
        })
    cfg.setdefault("notesDir", "~/Notas")
    if github:
        cfg["githubUser"] = github
    if indices or cands_path != "-":
        cfg["chats"] = chats
    cfg.pop("claudeSessions", None)  # formato anterior
    cfg.pop("claudeWorkdir", None)
    cfg_file.parent.mkdir(parents=True, exist_ok=True)
    cfg_file.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv):
    if len(argv) >= 2 and argv[1] == "list":
        cmd_list()
    elif len(argv) == 3 and argv[1] == "labels":
        cmd_labels(argv[2])
    elif len(argv) == 4 and argv[1] == "chosen":
        cmd_chosen(argv[2], argv[3])
    elif len(argv) >= 5 and argv[1] == "save":
        cmd_save(argv[2], argv[3], argv[4], argv[5:])
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
