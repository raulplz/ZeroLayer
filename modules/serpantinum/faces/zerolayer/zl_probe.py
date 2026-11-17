"""Datos de solo lectura para los widgets ZerØ de ZerØLayer/ZeroLayer (salida JSON).

Uso: python3 -I zl_probe.py games | repos <carpeta>... | docker [contexto] | agents

- games: juegos recientes de Steam y Heroic (si están), temperatura y uso de la
  GPU y batería de mandos (/sys/class/power_supply con scope=Device).
- repos: repos git con cambios o commits sin subir (git status, sin bloqueos).
- docker: «docker [--context X] ps -a»; nunca arranca ni para nada.
- agents: si existen zeroagents-gui/zeroagents y cuántos «claude» hay en marcha.

Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
"""

import glob
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
TOOLS = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common|SteamVR|Steam Audio)", re.I)


def out(data):
    print(json.dumps(data, ensure_ascii=False))


# ---------- juegos ----------
def vdf_values(text, key):
    return re.findall(r'^\s*"%s"\s+"([^"]*)"' % re.escape(key), text, re.M | re.I)


def steam_games():
    roots = [HOME / ".local/share/Steam", HOME / ".steam/steam",
             HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam"]
    roots = [r for r in roots if (r / "steamapps").is_dir()]
    if not roots:
        return None
    libs = set()
    for r in roots:
        libs.add(r.resolve())
        vdf = r / "steamapps/libraryfolders.vdf"
        try:
            for p in vdf_values(vdf.read_text(encoding="utf-8", errors="replace"), "path"):
                libs.add(Path(p))
        except OSError:
            pass
    games, seen = [], set()
    for lib in libs:
        for acf in glob.glob(str(lib / "steamapps/appmanifest_*.acf")):
            try:
                t = Path(acf).read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            appid = (vdf_values(t, "appid") or [""])[0]
            name = (vdf_values(t, "name") or [""])[0]
            if not appid or not name or appid in seen or TOOLS.match(name):
                continue
            seen.add(appid)
            last = int((vdf_values(t, "LastPlayed") or ["0"])[0] or 0)
            games.append({"store": "steam", "id": appid, "name": name, "last": last,
                          "launch": ["steam", "steam://rungameid/" + appid]})
    return games


def heroic_games():
    dirs = [HOME / ".config/heroic", HOME / ".var/app/com.heroicgameslauncher.hgl/config/heroic"]
    dirs = [d for d in dirs if d.is_dir()]
    if not dirs:
        return None
    games = []
    for d in dirs:
        try:
            cfg = json.loads((d / "store/config.json").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        recent = ((cfg.get("games") or {}).get("recent")) or []
        for i, g in enumerate(recent):
            if not isinstance(g, dict) or not g.get("appName"):
                continue
            runner = g.get("runner") or "legendary"
            url = "heroic://launch?appName=%s&runner=%s" % (g["appName"], runner)
            # Más reciente primero; Heroic no guarda la fecha en esta lista.
            games.append({"store": "heroic", "id": g["appName"], "name": g.get("title") or g["appName"],
                          "last": -i, "launch": ["xdg-open", url]})
    return games


def gpu():
    info = {"temp": None, "busy": None}
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]*/device")):
        temps = glob.glob(card + "/hwmon/hwmon*/temp1_input")
        if temps and info["temp"] is None:
            try:
                info["temp"] = round(int(Path(temps[0]).read_text()) / 1000)
            except (OSError, ValueError):
                pass
        if info["busy"] is None and os.path.exists(card + "/gpu_busy_percent"):
            try:
                info["busy"] = int(Path(card + "/gpu_busy_percent").read_text())
            except (OSError, ValueError):
                pass
    if info["temp"] is None and shutil.which("nvidia-smi"):
        try:
            r = subprocess.run(["nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu",
                                "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=3)
            t, b = [x.strip() for x in r.stdout.splitlines()[0].split(",")]
            info = {"temp": int(t), "busy": int(b)}
        except (OSError, ValueError, IndexError, subprocess.SubprocessError):
            pass
    return info


def pads():
    found = []
    for ps in glob.glob("/sys/class/power_supply/*"):
        p = Path(ps)
        try:
            if (p / "scope").read_text().strip() != "Device":
                continue
        except OSError:
            continue
        name = p.name.lower()
        if not re.search(r"controller|gamepad|joy|pad|xpad|sony|ps-|dualsense|dualshock|nintendo|8bitdo|xbox|steam", name):
            continue
        cap, level = None, ""
        try:
            cap = int((p / "capacity").read_text())
        except (OSError, ValueError):
            try:
                level = (p / "capacity_level").read_text().strip()
            except OSError:
                pass
        try:
            status = (p / "status").read_text().strip()
        except OSError:
            status = ""
        found.append({"name": p.name, "capacity": cap, "level": level, "charging": status == "Charging"})
    return found


def cmd_games():
    steam, heroic = steam_games(), heroic_games()
    games = (steam or []) + (heroic or [])
    games.sort(key=lambda g: g["last"], reverse=True)
    out({
        "steam": steam is not None or bool(shutil.which("steam")),
        "heroic": heroic is not None or bool(shutil.which("heroic")),
        "games": games[:8],
        "gpu": gpu(),
        "pads": pads(),
    })


# ---------- repos ----------
def git(repo, *args):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", LC_ALL="C")
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, timeout=8, env=env)
    return r.returncode, r.stdout


def cmd_repos(dirs):
    if not shutil.which("git"):
        out({"git": False, "repos": [], "total": 0})
        return
    repos = set()
    for d in dirs:
        base = Path(os.path.expanduser(d))
        if not base.is_dir():
            continue
        for depth in ("", "*/", "*/*/"):
            for g in glob.glob(str(base) + "/" + depth + ".git"):
                repos.add(Path(g).parent)
    rows = []
    for repo in sorted(repos)[:80]:
        try:
            code, st = git(repo, "status", "--porcelain=v1", "-b")
        except (OSError, subprocess.SubprocessError):
            continue
        if code != 0:
            continue
        lines = st.splitlines()
        head = lines[0][3:] if lines and lines[0].startswith("## ") else ""
        changes = len([x for x in lines[1:] if x.strip()])
        m = re.search(r"ahead (\d+)", head)
        ahead = int(m.group(1)) if m else 0
        upstream = "..." in head
        detached = head.startswith("HEAD (no branch)")
        branch = "detached" if detached else re.sub(r"^No commits yet on ", "", head.split("...")[0]).split(" ")[0]
        remote = False
        if not upstream and not detached:
            try:
                remote = bool(git(repo, "remote")[1].strip())
            except (OSError, subprocess.SubprocessError):
                pass
        pending = changes > 0 or ahead > 0 or (remote and not upstream)
        rows.append({"path": str(repo), "name": repo.name, "branch": branch, "changes": changes,
                     "ahead": ahead, "upstream": upstream, "remote": remote or upstream, "pending": pending})
    rows.sort(key=lambda r: (not r["pending"], -(r["ahead"] * 100 + r["changes"]), r["name"].lower()))
    out({"git": True, "total": len(rows), "repos": [r for r in rows if r["pending"]]})


# ---------- docker ----------
def cmd_docker(context):
    if not shutil.which("docker"):
        out({"docker": False, "running": False, "containers": []})
        return
    cmd = ["docker"] + (["--context", context] if context else []) + [
        "ps", "-a", "--format", "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=6)
    except subprocess.TimeoutExpired:
        out({"docker": True, "running": False, "error": "sin respuesta", "containers": []})
        return
    if r.returncode != 0:
        err = (r.stderr.strip().splitlines() or ["error"])[-1]
        out({"docker": True, "running": False, "error": err[:120], "containers": []})
        return
    rows = []
    for line in r.stdout.splitlines():
        p = line.split("\t")
        if len(p) >= 4:
            rows.append({"name": p[0], "image": p[1], "state": p[2], "status": p[3]})
    rows.sort(key=lambda c: (c["state"] != "running", c["name"]))
    out({"docker": True, "running": True, "containers": rows})


# ---------- agentes ----------
def cmd_agents():
    count = 0
    for comm in glob.glob("/proc/[0-9]*/comm"):
        try:
            if Path(comm).read_text().strip() == "claude":
                count += 1
        except OSError:
            pass
    out({"gui": bool(shutil.which("zeroagents-gui")), "cli": bool(shutil.which("zeroagents")), "claude": count})


def main(argv):
    if len(argv) >= 2 and argv[1] == "games":
        cmd_games()
    elif len(argv) >= 2 and argv[1] == "repos":
        cmd_repos(argv[2:])
    elif len(argv) >= 2 and argv[1] == "docker":
        cmd_docker(argv[2] if len(argv) > 2 else "")
    elif len(argv) >= 2 and argv[1] == "agents":
        cmd_agents()
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
