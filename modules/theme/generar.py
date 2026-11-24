"""Genera la familia de temas ZERØ de ZerØLayer: paletas, iconos de carpeta, fondos y vistas previas.

Uso (desde la raíz del repo, sin instalar nada global):
    uv run --with pillow modules/theme/generar.py               # todo
    uv run --with pillow modules/theme/generar.py zero-corp     # un tema
    uv run --with pillow modules/theme/generar.py --solo-datos  # solo colors.toml, zerolayer.toml e iconos

Salida, junto a este archivo:
    themes/<id>/       colors.toml, icons.theme, zerolayer.toml, preview.png (tema de Omarchy sin fondo)
    fondos/<id>/       <id>-1920x1200.png, <id>-1920x1080.png, <id>-2560x1440.png
    icons/Zero-<X>/    iconos de carpeta en los colores del tema (heredan de Yaru)
El módulo copia el fondo que mejor encaja con tu monitor a backgrounds/ al instalar.
Todo es original de ZerØLayer: el emblema Ø sale de docs/zero-logo (mismos trazos que el arranque).
"""
import math
import os
import random
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
TAMANOS = [(1920, 1200), (1920, 1080), (2560, 1440)]

# ───────────────────────── paletas ─────────────────────────
# Claves de Omarchy (colors.toml) + extras ZERØ (superficie, borde, tenue, acento2, ok, aviso, peligro).
TEMAS = {
    "zero-frost": dict(
        nombre="ZERØ Frost", kanji="零", yaru="Yaru-blue", icono="Zero-Frost",
        idea="Azul hielo sobre negro: el Frost de siempre, con anillo HUD y circuitos.",
        background="#080b10", dark_background="#06080c", darker_background="#030507", lighter_background="#111923",
        foreground="#d5dfeb", dark_foreground="#8292a6", light_foreground="#e4ecf6", bright_foreground="#f2f7ff",
        accent="#4da3ff", selection="#153354", muted="#536477",
        red="#ef7180", yellow="#e6bf79", orange="#dc9d70", green="#8fbea0", cyan="#75c4e8", blue="#4da3ff", magenta="#9faee8", brown="#967c69",
        bright_red="#ff8b96", bright_yellow="#f4d49b", bright_green="#a6d8b8", bright_cyan="#9cdcf5", bright_blue="#86c2ff", bright_magenta="#bac8ff",
        hyprland_active_border="#4da3ff", hyprland_inactive_border="#1c2a3a",
        superficie="#111923", borde="#1c2a3a", tenue="#8292a6", acento2="#75c4e8", ok="#8fbea0", aviso="#e6bf79", peligro="#ef7180",
    ),
    "zero-corp": dict(
        nombre="ZERØ Corp", kanji="零", yaru="Yaru-red", icono="Zero-Corp",
        idea="Cyberpunk corporativo: rojo y negro, kanji 零, katakana y franjas de seguridad.",
        background="#0a0405", dark_background="#070304", darker_background="#040202", lighter_background="#1a0a0d",
        foreground="#ece4e4", dark_foreground="#9a8083", light_foreground="#f4eded", bright_foreground="#fff6f6",
        accent="#e8182c", selection="#4a0d16", muted="#6a3a40",
        red="#ff4650", yellow="#e8b04a", orange="#ff7a45", green="#7fbf8a", cyan="#8fc2c4", blue="#7f9cc9", magenta="#d0607e", brown="#8a4a3a",
        bright_red="#ff6e78", bright_yellow="#f5c970", bright_green="#a0d8aa", bright_cyan="#b0dcdd", bright_blue="#a3bbe0", bright_magenta="#e888a2",
        hyprland_active_border="rgba(ff2a3cee) rgba(8a0c1cee) 45deg", hyprland_inactive_border="#3a1218",
        superficie="#1a0a0d", borde="#3a1218", tenue="#9a8083", acento2="#ff4650", ok="#7fbf8a", aviso="#e8b04a", peligro="#ff5c6c",
    ),
    "zero-neon": dict(
        nombre="ZERØ Neon", kanji="電", yaru="Yaru-magenta", icono="Zero-Neon",
        idea="Barrio de neón: magenta y cian, letreros verticales, lluvia y rejilla al horizonte.",
        background="#0a0614", dark_background="#07040f", darker_background="#04020a", lighter_background="#160e26",
        foreground="#e6e0f5", dark_foreground="#8e83a8", light_foreground="#f0ebfa", bright_foreground="#fbf8ff",
        accent="#ff2bd6", selection="#3a1250", muted="#5a4a78",
        red="#ff4d7a", yellow="#ffd23f", orange="#ff8a3d", green="#3dffb0", cyan="#22e5ff", blue="#6a7bff", magenta="#ff2bd6", brown="#a0527a",
        bright_red="#ff7a9c", bright_yellow="#ffe27a", bright_green="#7affca", bright_cyan="#7af0ff", bright_blue="#98a4ff", bright_magenta="#ff73e4",
        hyprland_active_border="rgba(ff2bd6ee) rgba(22e5ffee) 45deg", hyprland_inactive_border="#2a1a40",
        superficie="#160e26", borde="#2a1a40", tenue="#8e83a8", acento2="#22e5ff", ok="#3dffb0", aviso="#ffd23f", peligro="#ff4d7a",
    ),
    "zero-phosphor": dict(
        nombre="ZERØ Phosphor", kanji="端", yaru="Yaru-sage", icono="Zero-Phosphor",
        idea="Terminal de fósforo verde: volcado de memoria, líneas de barrido y brillo CRT.",
        background="#040805", dark_background="#030603", darker_background="#010301", lighter_background="#0b140d",
        foreground="#b8f5c4", dark_foreground="#5f8f69", light_foreground="#d0ffd9", bright_foreground="#e8ffec",
        accent="#39ff6a", selection="#0f3a1a", muted="#2f5a38",
        red="#ff6b5b", yellow="#d8f55a", orange="#f0b45a", green="#39ff6a", cyan="#5fffd0", blue="#6fc8ff", magenta="#c38bff", brown="#7a8a4a",
        bright_red="#ff9488", bright_yellow="#e6ff8a", bright_green="#7dffa0", bright_cyan="#9affe2", bright_blue="#9ad9ff", bright_magenta="#d8b0ff",
        hyprland_active_border="rgba(39ff6aee) rgba(0f7a2aee) 45deg", hyprland_inactive_border="#143a1e",
        superficie="#0b140d", borde="#143a1e", tenue="#5f8f69", acento2="#7dffc0", ok="#7dffa0", aviso="#e6f55a", peligro="#ff6b5b",
    ),
    "zero-amber": dict(
        nombre="ZERØ Amber", kanji="琥", yaru="Yaru-yellow", icono="Zero-Amber",
        idea="Laboratorio de señal en ámbar: retícula de osciloscopio, ondas y brillo de tubo.",
        background="#0c0803", dark_background="#080502", darker_background="#040301", lighter_background="#1a1208",
        foreground="#ffd9a0", dark_foreground="#a07a48", light_foreground="#ffe6bd", bright_foreground="#fff2dc",
        accent="#ffb000", selection="#4a3008", muted="#6a5030",
        red="#ff5a3c", yellow="#ffcf4a", orange="#ff8c1a", green="#b8d65a", cyan="#7fd0c0", blue="#7aa0d0", magenta="#d08aa0", brown="#8a5a2a",
        bright_red="#ff8268", bright_yellow="#ffe07a", bright_green="#d0ea80", bright_cyan="#a6e3d8", bright_blue="#a0bde3", bright_magenta="#e6aabc",
        hyprland_active_border="rgba(ffb000ee) rgba(ff6a00ee) 45deg", hyprland_inactive_border="#3a2a10",
        superficie="#1a1208", borde="#3a2a10", tenue="#a07a48", acento2="#ff7a1a", ok="#b8d65a", aviso="#ffcf4a", peligro="#ff5a3c",
    ),
    "zero-void": dict(
        nombre="ZERØ Void", kanji="虚", yaru="Yaru-purple", icono="Zero-Void",
        idea="Vacío ultravioleta: nebulosa, órbitas finas y un Ø enorme flotando.",
        background="#08060e", dark_background="#05040a", darker_background="#030206", lighter_background="#13101e",
        foreground="#e2dcf2", dark_foreground="#8a82a3", light_foreground="#ece8f8", bright_foreground="#f8f6ff",
        accent="#a879ff", selection="#2c1f4f", muted="#4f4670",
        red="#ff6e8a", yellow="#f2d07a", orange="#f0a070", green="#7fe0a8", cyan="#5de4c7", blue="#7f9cff", magenta="#c79bff", brown="#8a6a7a",
        bright_red="#ff96aa", bright_yellow="#f8e0a0", bright_green="#a6ecc4", bright_cyan="#8cf0da", bright_blue="#a6baff", bright_magenta="#dcbcff",
        hyprland_active_border="rgba(a879ffee) rgba(5de4c7ee) 45deg", hyprland_inactive_border="#221a38",
        superficie="#13101e", borde="#221a38", tenue="#8a82a3", acento2="#5de4c7", ok="#7fe0a8", aviso="#f2d07a", peligro="#ff6e8a",
    ),
    "zero-mono": dict(
        nombre="ZERØ Mono", kanji="無", yaru="Yaru", icono="Zero-Mono",
        idea="Negro puro con luz blanca: retícula, anillos finos y un Ø de tiza.",
        background="#050505", dark_background="#030303", darker_background="#010101", lighter_background="#101010",
        foreground="#d8d8d8", dark_foreground="#8a8a8a", light_foreground="#ececec", bright_foreground="#ffffff",
        accent="#f2f2f2", selection="#2a2a2a", muted="#5c5c5c",
        red="#e08a8a", yellow="#d9cfa0", orange="#d9b08a", green="#a3c9ab", cyan="#a6cfd6", blue="#a9b8d6", magenta="#c6b0d6", brown="#9a8a7a",
        bright_red="#f2a8a8", bright_yellow="#ece3b8", bright_green="#bfe0c6", bright_cyan="#c4e4ea", bright_blue="#c6d2ea", bright_magenta="#dccbea",
        hyprland_active_border="#f2f2f2", hyprland_inactive_border="#262626",
        superficie="#101010", borde="#262626", tenue="#8a8a8a", acento2="#bdbdbd", ok="#a3c9ab", aviso="#d9cfa0", peligro="#e08a8a",
    ),
}
CLAVES_OMARCHY = ["accent", "selection", "muted", "background", "dark_background", "darker_background", "lighter_background",
                  "foreground", "dark_foreground", "light_foreground", "bright_foreground",
                  "red", "yellow", "orange", "green", "cyan", "blue", "magenta", "brown",
                  "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta",
                  "hyprland_active_border", "hyprland_inactive_border"]
CLAVES_ZERO = ["superficie", "borde", "tenue", "acento2", "ok", "aviso", "peligro"]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mezcla(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hexa(c):
    return "#%02x%02x%02x" % c


# ───────────────────────── datos del tema ─────────────────────────
ICONO_SVG = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path fill="{tras}" d="M4 12a4 4 0 0 1 4-4h12l5 5h15a4 4 0 0 1 4 4v21a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4z"/>'
             '<path fill="{frente}" d="M4 19h40v19a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4z"/><path fill="{raya}" opacity=".7" d="M9 23h30v2H9z"/>{marca}</svg>')
ICONOS = {"folder": "", "folder-documents": "M16 29h16v2H16zm0 4h11v2H16z", "folder-download": "M23 27h2v6l3-3 1.4 1.4L24 37l-5.4-5.6L20 30l3 3z",
          "folder-pictures": "m15 36 6-7 4 5 3-3 5 5z", "folder-music": "M27 27v7.2a3 3 0 1 0 2 2.8V30h4v-3z",
          "folder-videos": "M20 28v9l8-4.5z", "user-home": "M24 27l-8 7h2.5v4h11v-4H32z", "user-desktop": "M16 28h16v8H16zm6 9h4v2h-4z"}


def escribir_datos(tid, t):
    dst = os.path.join(AQUI, "themes", tid)
    os.makedirs(dst, exist_ok=True)
    with open(os.path.join(dst, "colors.toml"), "w") as f:
        f.write(f"# {t['nombre']} · familia ZERØ de ZerØLayer (generado por modules/theme/generar.py)\n")
        f.write('mode = "dark"\n')
        for k in CLAVES_OMARCHY:
            f.write(f'{k} = "{t[k]}"\n')
    with open(os.path.join(dst, "icons.theme"), "w") as f:
        f.write(t["icono"])
    with open(os.path.join(dst, "zerolayer.toml"), "w") as f:
        f.write(f"# Metadatos ZERØ: los lee el hook de ZerØLayer para escribir ~/.config/zerolayer/theme.json\n")
        f.write(f'id = "{tid}"\nnombre = "{t["nombre"]}"\nglifo = "Ø"\nkanji = "{t["kanji"]}"\nidea = "{t["idea"]}"\n\n[colores]\n')
        for k in CLAVES_ZERO:
            f.write(f'{k} = "{t[k]}"\n')
        f.write('\n[fuentes]\nsans = "Inter Tight"\nmono = "JetBrainsMono Nerd Font"\n')
    # iconos de carpeta
    idir = os.path.join(AQUI, "icons", t["icono"])
    os.makedirs(os.path.join(idir, "scalable", "places"), exist_ok=True)
    with open(os.path.join(idir, "index.theme"), "w") as f:
        f.write(f"[Icon Theme]\nName={t['icono']}\nComment=Iconos de carpeta {t['nombre']} (ZerØLayer)\n"
                f"Inherits={t['yaru']},breeze-dark,hicolor\nDirectories=scalable/places\n\n"
                "[scalable/places]\nSize=48\nMinSize=16\nMaxSize=256\nType=Scalable\nContext=Places\n")
    ac = rgb(t["accent"])
    for nombre, d in ICONOS.items():
        marca = f'<path fill="{t["darker_background"]}" opacity=".55" d="{d}"/>' if d else ""
        svg = ICONO_SVG.format(tras=t["selection"], frente=t["accent"], raya=hexa(mezcla(ac, (255, 255, 255), .6)), marca=marca)
        with open(os.path.join(idir, "scalable", "places", nombre + ".svg"), "w") as f:
            f.write(svg)


# ───────────────────────── utilidades de dibujo ─────────────────────────
def buscar_fuente(rutas, patron):
    for r in rutas:
        r = os.path.expanduser(r)
        if os.path.exists(r):
            return r
    try:
        r = subprocess.run(["fc-match", "-f", "%{file}", patron], capture_output=True, text=True).stdout.strip()
        if r:
            return r
    except OSError:
        pass
    sys.exit(f"Falta la fuente «{patron}»")


F_LATIN = buscar_fuente(["~/.local/share/fonts/PocoPlan/InterTight-Black.ttf"], "Inter Tight:style=Black")
F_MONO = buscar_fuente(["/usr/share/fonts/noto/NotoSansMono-Bold.ttf"], "Noto Sans Mono:style=Bold")
F_MONO_R = buscar_fuente(["/usr/share/fonts/noto/NotoSansMono-Regular.ttf"], "Noto Sans Mono")
F_CJK = buscar_fuente(["/usr/share/fonts/noto-cjk/NotoSansCJK-Black.ttc"], "Noto Sans CJK JP:style=Black")


def fuente(path, size):
    size = max(6, int(size))
    return ImageFont.truetype(path, size, index=0) if path.endswith(".ttc") else ImageFont.truetype(path, size)


def capa(W, H):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def radial(W, H, borde, centro, power=1.8, cx=None, cy=None):
    small = Image.new("RGB", (W // 4, H // 4))
    px = small.load()
    cx = (W / 2 if cx is None else cx) / 4
    cy = (H / 2 if cy is None else cy) / 4
    R = math.hypot(small.width, small.height) / 2
    for y in range(small.height):
        for x in range(small.width):
            t = (1 - min(1, math.hypot(x - cx, y - cy) / R)) ** power
            px[x, y] = mezcla(borde, centro, t)
    return small.resize((W, H), Image.BICUBIC).convert("RGBA")


def brillo(base, ov, blur, passes=1):
    if blur > 0:
        g = ov.filter(ImageFilter.GaussianBlur(blur))
        for _ in range(passes):
            base = Image.alpha_composite(base, g)
    return Image.alpha_composite(base, ov)


def lineas_barrido(img, alpha, paso=3):
    ov, d = capa(*img.size)
    for y in range(0, img.size[1], paso):
        d.line([(0, y), (img.size[0], y)], fill=(0, 0, 0, alpha))
    return Image.alpha_composite(img, ov)


def vineta(img, fuerza, tinte=(0, 0, 0)):
    w, h = img.size
    m = Image.new("L", (w // 8, h // 8))
    px = m.load()
    for y in range(m.size[1]):
        for x in range(m.size[0]):
            dx = (x / m.size[0] - .5) * 2
            dy = (y / m.size[1] - .5) * 2
            px[x, y] = int(255 * min(1, max(0, (math.hypot(dx, dy) - .55) / .9)) * fuerza)
    capa_n = Image.new("RGBA", (w, h), tinte + (255,))
    capa_n.putalpha(m.resize((w, h), Image.BICUBIC))
    return Image.alpha_composite(img, capa_n)


def pistas(W, H, n, paso, semilla, evitar=None):
    """Pistas tipo PCB: tramos rectos y a 45º sobre una rejilla."""
    rnd = random.Random(semilla)
    res = []
    for _ in range(n):
        x = rnd.randrange(0, W // paso + 1) * paso
        y = rnd.randrange(0, H // paso + 1) * paso
        pts = [(x, y)]
        d = rnd.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
        for _ in range(rnd.randint(3, 6)):
            L = rnd.randint(2, 7) * paso
            x, y = x + d[0] * L, y + d[1] * L
            pts.append((x, y))
            if d[0] and d[1]:
                d = rnd.choice([(d[0], 0), (0, d[1])])
            else:
                d = rnd.choice([(d[0] or rnd.choice([-1, 1]), d[1] or rnd.choice([-1, 1])), (d[1], d[0])])
        if evitar and any(evitar[0] < px < evitar[2] and evitar[1] < py < evitar[3] for px, py in pts):
            continue
        res.append(pts)
    return res


def esquinas(d, caja, L, col, a, wd):
    x0, y0, x1, y1 = caja
    for (x, y, sx, sy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        d.line([(x, y + sy * L), (x, y), (x + sx * L, y)], fill=col + (a,), width=wd)


def franjas(d, caja, ancho, col, a):
    x0, y0, x1, y1 = caja
    h = y1 - y0
    for k in range(int(x0 - h), int(x1), ancho * 2):
        d.polygon([(k, y1), (k + ancho, y1), (k + ancho + h, y0), (k + h, y0)], fill=col + (a,))


def recorte(layer, caja):
    m = Image.new("L", layer.size, 0)
    ImageDraw.Draw(m).rectangle(caja, fill=255)
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), m)
    return out


def codigo_barras(d, x, y, w, h, semilla, col, a):
    rnd = random.Random(semilla)
    cx = x
    while cx < x + w:
        bw = rnd.choice([2, 2, 3, 5, 7])
        if rnd.random() < .62:
            d.rectangle([cx, y, cx + bw - 1, y + h], fill=col + (a,))
        cx += bw + rnd.choice([2, 3, 4])


# Zonas que tapan los widgets del escritorio (layout de ZerØLayer, coordenadas lógicas de 1536×960):
# columna izquierda, columna derecha y banda del espectro. Los fondos no dibujan detalles ahí.
def zonas(W, H, m=0):
    f = lambda x0, y0, x1, y1: (x0 / 1536 * W - m, y0 / 960 * H - m, x1 / 1536 * W + m, y1 / 960 * H + m)
    return [f(80, 100, 380, 710), f(1110, 100, 1425, 785), f(80, 800, 1456, 910)]


def toca_zona(pts, W, H, m=0):
    zs = zonas(W, H, m)
    for (ax, ay), (bx, by) in zip(pts, pts[1:] or pts):
        for k in range(25):
            x, y = ax + (bx - ax) * k / 24, ay + (by - ay) * k / 24
            if any(z[0] <= x <= z[2] and z[1] <= y <= z[3] for z in zs):
                return True
    return False


SK = math.tan(math.radians(14))
OCTO = [(424, 60), (470, 60), (492, 82), (492, 168), (470, 190), (424, 190), (402, 168), (402, 82)]


def o_barra(d, cx, cy, s, col, a, wd):
    """Ø de ZERØ (octógono inclinado + barra), los mismos trazos que zero-logo.svg."""
    ox, oy = 447, 125
    tf = lambda p: (cx + ((p[0] - ox) - (p[1] - oy) * SK) * s, cy + (p[1] - oy) * s)
    d.line([tf(p) for p in OCTO + OCTO[:2]], fill=col + (a,), width=wd, joint="curve")
    d.line([tf((388, 210)), tf((506, 40))], fill=col + (a,), width=wd)


MARCA = [[(30, 60), (120, 60), (30, 190), (120, 190)],
         [(244, 60), (176, 60), (154, 82), (154, 168), (176, 190), (244, 190)], [(154, 125), (221.5, 125)],
         [(278, 190), (278, 60), (346, 60), (368, 82), (368, 103), (346, 125), (278, 125)], [(318.5, 125), (368, 190)],
         OCTO + OCTO[:2], [(388, 210), (506, 40)]]


def logotipo(d, x, y, alto, col, a, wd):
    """Palabra ZERØ con los trazos del logo; (x, y) es la esquina superior izquierda de las letras."""
    s = alto / 130
    tf = lambda p: (x + (p[0] - 30 - (p[1] - 60) * SK + 130 * SK) * s, y + (p[1] - 60) * s)
    for trazo in MARCA:
        d.line([tf(p) for p in trazo], fill=col + (a,), width=wd, joint="curve")
    return (506 - 30 + 130 * SK) * s  # ancho aproximado


def falla(img, semilla, n, maxdesp, tinte):
    rnd = random.Random(semilla)
    w, h = img.size
    out = img.copy()
    for _ in range(n):
        y = rnd.randrange(0, h - 40)
        hh = rnd.randint(4, 26)
        sh = rnd.randint(-maxdesp, maxdesp)
        out.paste(img.crop((0, y, w, y + hh)), (sh, y))
        out.alpha_composite(Image.new("RGBA", (w, hh), tinte + (rnd.randint(10, 30),)), (0, y))
    return out


def texto_vertical(d, x, y0, texto, f, col, a, paso):
    for i, ch in enumerate(texto):
        d.text((x, y0 + i * paso), ch, font=f, fill=col + (a,), anchor="mm")


# ───────────────────────── fondos ─────────────────────────
def fondo_frost(W, H, t):
    s = min(W / 1920, H / 1080); S = lambda v: max(1, int(v * s)); CX, CY = W // 2, H // 2
    ICE, ICE2, LINEA = (120, 190, 240), (168, 220, 255), (70, 98, 126)
    img = radial(W, H, (5, 9, 15), (22, 50, 82), 1.5)
    ov, d = capa(W, H)
    for x in range(0, W, S(40)): d.line([(x, 0), (x, H)], fill=ICE + (5,))
    for y in range(0, H, S(40)): d.line([(0, y), (W, y)], fill=ICE + (5,))
    img = brillo(img, ov, S(3))
    halo, hd = capa(W, H); hd.ellipse([CX - S(340), CY - S(340), CX + S(340), CY + S(340)], fill=(40, 110, 200, 90))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(S(120))))
    # circuitos: pistas PCB con nodos, fuera del anillo central
    ov, d = capa(W, H)
    for k, pts in enumerate([p for p in pistas(W, H, 120, S(40), 7, (CX - S(500), CY - S(470), CX + S(500), CY + S(470)))
                             if not toca_zona(p, W, H, S(16))]):
        d.line(pts, fill=ICE + (46 if k % 3 else 80,), width=S(2) if k % 5 == 0 else 1, joint="curve")
        for (px_, py_) in (pts[0], pts[-1]):
            r = S(4)
            d.ellipse([px_ - r, py_ - r, px_ + r, py_ + r], outline=ICE2 + (120,), width=1)
            d.ellipse([px_ - 1, py_ - 1, px_ + 1, py_ + 1], fill=ICE2 + (190,))
    img = brillo(img, ov, S(2))
    # nieve y chispas de hielo
    ov, d = capa(W, H); rnd = random.Random(11)
    for _ in range(int(900 * W * H / (1920 * 1080))):
        x, y = rnd.randrange(W), rnd.randrange(H); a = int(rnd.random() ** 3 * 190) + 20
        c = rnd.choice([(255, 255, 255), ICE2, ICE])
        if rnd.random() < .05: d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=c + (min(255, a + 60),))
        else: d.point((x, y), fill=c + (a,))
    for _ in range(40):
        x, y = rnd.randrange(W), rnd.randrange(H); L = S(rnd.randint(7, 15))
        if toca_zona([(x - L, y - L), (x + L, y + L)], W, H, S(8)): continue
        d.line([(x - L, y), (x + L, y)], fill=ICE2 + (150,), width=1); d.line([(x, y - L), (x, y + L)], fill=ICE2 + (150,), width=1)
        d.line([(x - L // 2, y - L // 2), (x + L // 2, y + L // 2)], fill=ICE + (70,), width=1)
        d.line([(x - L // 2, y + L // 2), (x + L // 2, y - L // 2)], fill=ICE + (70,), width=1)
    img = brillo(img, ov, 1)
    ov, d = capa(W, H)
    for r, a, wd in [(S(400), 55, S(1)), (S(372), 150, S(2)), (S(300), 45, S(1))]:
        d.ellipse([CX - r, CY - r, CX + r, CY + r], outline=ICE + (a,), width=wd)
    for deg in range(0, 360, 3):
        L = S(16) if deg % 30 == 0 else S(7)
        a = math.radians(deg); r0 = S(370)
        d.line([(CX + math.cos(a) * r0, CY + math.sin(a) * r0), (CX + math.cos(a) * (r0 - L), CY + math.sin(a) * (r0 - L))],
               fill=ICE + (130 if deg % 30 == 0 else 80,), width=S(2) if deg % 30 == 0 else 1)
    R = S(425)
    for a0, a1 in ((200, 245), (20, 65)):
        d.arc([CX - R, CY - R, CX + R, CY + R], a0, a1, fill=ICE2 + (210,), width=S(5))
    for sg in (-1, 1):
        d.line([(CX + sg * S(404), CY), (CX + sg * S(424), CY)], fill=ICE + (170,), width=S(2))
        d.line([(CX, CY + sg * S(383)), (CX, CY + sg * S(400))], fill=ICE + (170,), width=S(2))
    img = brillo(img, ov, S(4))
    E, d = capa(W, H)
    o_barra(d, CX, CY, 1.5 * s, ICE2, 255, S(22))
    img = brillo(img, E, S(18), 2)
    ov, d = capa(W, H)
    fm = fuente(F_MONO, S(15)); fk = fuente(F_CJK, S(17))
    logotipo(d, S(70), H - S(148), S(26), ICE2, 200, S(4))
    d.text((S(70), H - S(106)), "ZERØLAYER // FROST", font=fm, fill=ICE + (150,))
    d.text((S(70), H - S(82)), "氷点下 · SUBZERO NODE", font=fk, fill=ICE + (90,))
    d.text((W - S(70), H - S(112)), "-273.15 °C  //  0x00-FR", font=fm, fill=ICE + (120,), anchor="ra")
    esquinas(d, (S(40), S(70), W - S(40), H - S(56)), S(60), ICE, 110, S(2))
    # regla superior con marcas
    fr = fuente(F_MONO_R, S(11))
    for i, x in enumerate(range(S(120), W - S(120), S(16))):
        L = S(12) if i % 5 == 0 else S(5)
        d.line([(x, S(70)), (x, S(70) + L)], fill=ICE + (90 if i % 5 == 0 else 50,), width=1)
        if i % 10 == 0: d.text((x, S(70) + S(18)), "%03d" % (i * 2), font=fr, fill=ICE + (90,), anchor="ma")
    # lecturas compactas en las esquinas del hueco central (entre las columnas de widgets)
    rr = random.Random(5); px0, py0 = CX - S(440), S(150)
    d.text((px0, py0), "CRYO://CORE", font=fr, fill=ICE2 + (150,))
    for i in range(9):
        hh = int(S(46) * (.25 + .75 * rr.random()))
        d.rectangle([px0 + i * S(11), py0 + S(66) - hh, px0 + i * S(11) + S(6), py0 + S(66)], fill=ICE + (70 + int(120 * hh / S(46)),))
    d.line([(px0, py0 + S(72)), (px0 + 9 * S(11), py0 + S(72))], fill=ICE + (110,), width=1)
    qx, qy = CX + S(250), S(150)
    d.text((qx, qy), "SYS://LATTICE", font=fr, fill=ICE2 + (150,))
    for i, (n, v) in enumerate([("FLUX", .82), ("COOL", .64), ("SYNC", .97)]):
        y = qy + S(22) + i * S(22)
        d.text((qx, y), n, font=fr, fill=ICE + (130,))
        d.rectangle([qx + S(44), y + S(3), qx + S(120), y + S(9)], outline=ICE + (90,), width=1)
        d.rectangle([qx + S(46), y + S(5), qx + S(46) + int(S(72) * v), y + S(7)], fill=ICE2 + (190,))
    d.text((S(70), S(104)), "SECTOR 00 · SUBZERO", font=fr, fill=ICE + (110,))
    d.text((W - S(70), S(104)), "LAT 90.0°S · LON 000.0°", font=fr, fill=ICE + (110,), anchor="ra")
    img = brillo(img, ov, S(3))
    return lineas_barrido(vineta(img, .55), 8)


def fondo_corp(W, H, t):
    s = min(W / 1920, H / 1080); S = lambda v: max(1, int(v * s)); CX, CY = W // 2, H // 2
    RED, HOT, WHITE = (232, 24, 44), (255, 70, 80), (240, 236, 236)
    img = radial(W, H, (6, 3, 4), (34, 3, 8))
    ov, d = capa(W, H)
    for x in range(0, W, S(40)): d.line([(x, 0), (x, H)], fill=RED + (6,))
    for y in range(0, H, S(40)): d.line([(0, y), (W, y)], fill=RED + (6,))
    area = W * H / (1920 * 1080)
    for p in pistas(W, H, int(70 * area), S(40), 7, (CX - S(520), CY - S(440), CX + S(520), CY + S(440))):
        d.line(p, fill=RED + (34,), width=S(2), joint="curve")
        for (x, y) in (p[0], p[-1]):
            r = S(5); d.rectangle([x - r, y - r, x + r, y + r], outline=RED + (84,), width=S(2))
    img = brillo(img, ov, S(6))
    ov, d = capa(W, H)
    d.text((S(70), CY), "零", font=fuente(F_CJK, S(760)), fill=RED + (30,), anchor="lm")
    fk = fuente(F_CJK, S(34))
    texto_vertical(d, W - S(92), S(150), "ゼロ・コーポレーション", fk, RED, 150, S(42))
    d.line([(W - S(132), S(130)), (W - S(132), S(150) + 11 * S(42))], fill=RED + (120,), width=S(2))
    img = falla(Image.alpha_composite(img, ov), 3, 7, S(26), RED)
    ov, d = capa(W, H)
    hz, hd = capa(W, H); franjas(hd, (0, 0, W, S(26)), S(22), RED, 200)
    ov = Image.alpha_composite(ov, recorte(hz, (0, 0, S(520), S(26))))
    ov = Image.alpha_composite(ov, recorte(hz.transpose(Image.FLIP_TOP_BOTTOM), (W - S(520), H - S(26), W, H)))
    d = ImageDraw.Draw(ov)
    d.line([(S(520), S(13)), (W - S(40), S(13))], fill=RED + (110,), width=S(2))
    d.line([(S(40), H - S(13)), (W - S(520), H - S(13))], fill=RED + (110,), width=S(2))
    esquinas(d, (S(40), S(56), W - S(40), H - S(56)), S(70), RED, 210, S(4))
    fm, fs, fl = fuente(F_MONO, S(20)), fuente(F_MONO, S(16)), fuente(F_LATIN, S(30))
    d.text((S(70), H - S(285)), "ZERØ CORPORATION", font=fl, fill=WHITE + (235,))
    d.text((S(70), H - S(247)), "SECURE NODE 00 // ZERØLAYER", font=fm, fill=RED + (220,))
    for i, x in enumerate(["SYS.STATUS ......... ONLINE", "NEURAL LINK ........ STABLE", "ICE PROTOCOL ....... ACTIVE"]):
        d.text((S(70), H - S(170) + i * S(26)), x, font=fs, fill=RED + (170,))
    codigo_barras(d, W - S(760), H - S(150), S(300), S(46), 77, WHITE, 190)
    d.text((W - S(760), H - S(96)), "35.6762N 139.6503E  //  0x2E07-ZR", font=fs, fill=RED + (170,))
    for k in range(18):
        d.rectangle([W - S(470) + k * S(17), S(78), W - S(470) + k * S(17) + S(10), S(88)], fill=RED + (230 if k < 13 else 60,))
    d.text((W - S(470), S(94)), "SYNC 72%", font=fs, fill=RED + (170,))
    img = brillo(img, ov, S(4))
    E, d = capa(W, H)
    for r, a, wd in [(S(390), 70, S(2)), (S(350), 190, S(4)), (S(300), 50, S(2))]:
        d.polygon([(CX, CY - r), (CX + r, CY), (CX, CY + r), (CX - r, CY)], outline=RED + (a,), width=wd)
    for sg in (-1, 1):
        d.line([(CX + sg * S(360), CY), (CX + sg * S(470), CY)], fill=RED + (200,), width=S(3))
        d.line([(CX, CY + sg * S(360)), (CX, CY + sg * S(430))], fill=RED + (160,), width=S(3))
        for k in range(1, 6):
            x = CX + sg * (S(480) + k * S(14)); d.line([(x, CY - S(8)), (x, CY + S(8))], fill=RED + (200 - k * 30,), width=S(3))
    o_barra(d, CX, CY, 1.55 * s, HOT, 255, S(22))
    halo, hd = capa(W, H); hd.ellipse([CX - S(320), CY - S(320), CX + S(320), CY + S(320)], fill=(200, 10, 30, 70))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(S(110))))
    img = brillo(img, E, S(18), 2)
    return lineas_barrido(vineta(img, .75), 26)


def fondo_neon(W, H, t):
    s = min(W / 1920, H / 1080); S = lambda v: max(1, int(v * s)); CX = W // 2
    MAG, CIA, ROSA = (255, 43, 214), (34, 229, 255), (255, 200, 245)
    Hy = int(H * .66)
    col = Image.new("RGB", (1, H)); px = col.load()
    paradas = [(0, (5, 3, 12)), (.45, (16, 5, 30)), (.64, (58, 10, 72)), (.66, (14, 5, 24)), (1, (4, 2, 9))]
    for y in range(H):
        f = y / H
        for (a, ca), (b, cb) in zip(paradas, paradas[1:]):
            if a <= f <= b:
                px[0, y] = mezcla(ca, cb, (f - a) / (b - a)); break
    img = col.resize((W, H)).convert("RGBA")
    g, d = capa(W, H); d.ellipse([CX - W * .55, Hy - S(240), CX + W * .55, Hy + S(120)], fill=MAG + (70,))
    img = Image.alpha_composite(img, g.filter(ImageFilter.GaussianBlur(S(150))))
    # suelo en rejilla hacia el horizonte
    ov, d = capa(W, H)
    for k in range(-40, 41):
        d.line([(CX + k * S(14), Hy), (CX + k * S(260), H + S(200))], fill=MAG + (70,), width=S(2))
    for i in range(1, 16):
        y = Hy + (H - Hy) * (i / 15) ** 2.2
        d.line([(0, y), (W, y)], fill=MAG + (40 + i * 7,), width=S(2))
    img = brillo(img, ov, S(5))
    # ciudad: dos capas de edificios con ventanas
    rnd = random.Random(21)
    for capa_n, (fondo_c, hmin, hmax, prob) in enumerate([((20, 9, 36), 120, 330, .10), ((9, 4, 17), 50, 210, .06)]):
        ov, d = capa(W, H); luces, dl = capa(W, H)
        x = -S(20)
        while x < W:
            bw = S(rnd.randint(40, 140)); bh = S(rnd.randint(hmin, hmax))
            if abs(x + bw / 2 - CX) < S(330) and capa_n == 1: bh = S(rnd.randint(30, 70))
            d.rectangle([x, Hy - bh, x + bw, Hy + S(2)], fill=fondo_c + (255,))
            if rnd.random() < .3:
                ax = x + bw // 2; d.line([(ax, Hy - bh), (ax, Hy - bh - S(40))], fill=fondo_c + (255,), width=S(3))
                dl.ellipse([ax - S(3), Hy - bh - S(44), ax + S(3), Hy - bh - S(38)], fill=(255, 60, 90, 230))
            for wy in range(Hy - bh + S(12), Hy - S(8), S(14)):
                for wx in range(x + S(8), x + bw - S(8), S(12)):
                    if rnd.random() < prob:
                        dl.rectangle([wx, wy, wx + S(5), wy + S(7)], fill=rnd.choice([CIA, MAG, ROSA]) + (rnd.randint(70, 170),))
            x += bw + S(rnd.randint(0, 14))
        img = brillo(Image.alpha_composite(img, ov), luces, S(3))
    ov, d = capa(W, H); d.line([(0, Hy), (W, Hy)], fill=CIA + (200,), width=S(2)); img = brillo(img, ov, S(8), 2)
    # letrero central: Ø en neón dentro de un hexágono
    CY = int(H * .33); R = S(235)
    hexa_pts = [(CX + R * math.cos(math.radians(60 * k + 30)), CY + R * math.sin(math.radians(60 * k + 30))) for k in range(7)]
    ov, d = capa(W, H)
    d.line(hexa_pts, fill=CIA + (230,), width=S(4), joint="curve")
    o_barra(d, CX + S(7), CY, 1.2 * s, CIA, 110, S(22))
    img = brillo(img, ov, S(14), 2)
    ov, d = capa(W, H); o_barra(d, CX, CY, 1.2 * s, MAG, 255, S(22)); img = brillo(img, ov, S(22), 2)
    ov, d = capa(W, H); o_barra(d, CX, CY, 1.2 * s, ROSA, 235, S(7)); img = Image.alpha_composite(img, ov)
    # letreros verticales
    ov, d = capa(W, H)
    x0, y0 = W - S(118), S(150)
    d.rounded_rectangle([x0, y0, x0 + S(96), y0 + S(470)], S(10), outline=MAG + (230,), width=S(4))
    texto_vertical(d, x0 + S(48), y0 + S(52), "ゼロレイヤー", fuente(F_CJK, S(52)), CIA, 245, S(74))
    x1, y1 = S(580), S(330)
    d.rounded_rectangle([x1, y1, x1 + S(80), y1 + S(250)], S(10), outline=CIA + (200,), width=S(3))
    texto_vertical(d, x1 + S(40), y1 + S(62), "電脳", fuente(F_CJK, S(60)), MAG, 245, S(124))
    img = brillo(img, ov, S(12), 2)
    # lluvia
    ov, d = capa(W, H); rnd = random.Random(5)
    for _ in range(int(900 * W * H / (1920 * 1080))):
        x = rnd.randrange(0, W); y = rnd.randrange(0, H); L = S(rnd.randint(25, 70))
        d.line([(x, y), (x - L * .18, y + L)], fill=(190, 200, 255, rnd.randint(14, 38)), width=1)
    img = Image.alpha_composite(img, ov)
    ov, d = capa(W, H); fm = fuente(F_MONO, S(15))
    d.text((S(70), H - S(110)), "ZERØ // NEON DISTRICT 07", font=fm, fill=CIA + (190,))
    d.text((S(70), H - S(86)), "電脳街 · RAIN 87% · GRID ONLINE", font=fuente(F_CJK, S(15)), fill=MAG + (170,))
    img = brillo(img, ov, S(3))
    return lineas_barrido(vineta(img, .5), 10)


BOOT = ["[  OK  ] Started ZERØ phosphor terminal.", "[  OK  ] Mounted /zero/layer.", "[  OK  ] Reached target Neural Link.",
        "[  OK  ] Started Ice protocol daemon.", "[ WAIT ] Syncing subzero cache ......", "[  OK  ] Listening on /run/zero.sock.",
        "[  OK  ] Loaded kernel module zerø.ko.", "[  OK  ] Finished Phosphor calibration.", "[  OK  ] Created slice node-07.",
        "[ INFO ] scanline sync 59.94 Hz", "[  OK  ] Started Glyph renderer Ø.", "[  OK  ] Reached target Terminal."]


def fondo_phosphor(W, H, t):
    s = min(W / 1920, H / 1080); S = lambda v: max(1, int(v * s)); CX, CY = W // 2, H // 2
    VERDE, CLARO, OSC = (57, 255, 106), (190, 255, 205), (30, 120, 52)
    img = radial(W, H, (2, 6, 3), (8, 30, 14), 1.6)
    ov, d = capa(W, H); rnd = random.Random(9)
    fm = fuente(F_MONO_R, S(15)); lh = S(21)
    def volcado(i):
        addr = 0x7F3A0000 + i * 16
        return f"{addr:08X}  " + " ".join(f"{rnd.randrange(256):02X}" for _ in range(12)) + "  " + "".join(rnd.choice("ZERØ.:/#-01") for _ in range(12))
    for i, y in enumerate(range(S(80), H - S(40), lh)):
        izq = BOOT[(i * 5) % len(BOOT)] if (i // 4) % 2 == 0 else volcado(i)
        der = volcado(i + 900) if (i // 4) % 2 == 0 else BOOT[(i * 7) % len(BOOT)]
        d.text((S(40), y), izq, font=fm, fill=VERDE + (rnd.choice([20, 24, 30, 46]),))
        d.text((W - S(40), y), der, font=fm, fill=VERDE + (rnd.choice([20, 24, 30, 46]),), anchor="ra")
    img = brillo(img, ov, S(2))
    # ventana de terminal
    ww, wh = S(760), S(520); x0, y0 = CX - ww // 2, CY - wh // 2
    sombra, sd = capa(W, H)
    sd.rectangle([W - S(200), S(120), W, S(470)], fill=(2, 7, 3, 235))
    sd.rectangle([S(30), H - S(90), S(420), H - S(40)], fill=(2, 7, 3, 235))
    img = Image.alpha_composite(img, sombra.filter(ImageFilter.GaussianBlur(S(24))))
    ov, d = capa(W, H)
    d.rounded_rectangle([x0, y0, x0 + ww, y0 + wh], S(14), fill=(2, 9, 4, 238))
    img = Image.alpha_composite(img, ov)
    ov, d = capa(W, H)
    d.rounded_rectangle([x0, y0, x0 + ww, y0 + wh], S(14), outline=VERDE + (200,), width=S(2))
    d.line([(x0, y0 + S(40)), (x0 + ww, y0 + S(40))], fill=VERDE + (120,), width=S(2))
    for k in range(3):
        d.rectangle([x0 + S(18) + k * S(22), y0 + S(14), x0 + S(30) + k * S(22), y0 + S(26)], outline=VERDE + (200,), width=S(2))
    d.text((CX, y0 + S(20)), "zero@layer: ~ — tty0", font=fuente(F_MONO, S(16)), fill=VERDE + (210,), anchor="mm")
    o_barra(d, CX, y0 + S(205), 1.05 * s, CLARO, 255, S(18))
    fb = fuente(F_MONO, S(19))
    lineas = [("> ZERØLAYER // PHOSPHOR", 230), ("> enlace neuronal ........ OK", 170), ("> ice protocol ........... OK", 170)]
    for i, (txt, a) in enumerate(lineas):
        d.text((x0 + S(46), y0 + S(345) + i * S(30)), txt, font=fb, fill=VERDE + (a,))
    d.text((x0 + S(46), y0 + S(345) + 3 * S(30)), "zero@layer:~$", font=fb, fill=CLARO + (240,))
    cx = x0 + S(46) + d.textlength("zero@layer:~$ ", font=fb)
    d.rectangle([cx, y0 + S(349) + 3 * S(30), cx + S(11), y0 + S(369) + 3 * S(30)], fill=CLARO + (240,))
    texto_vertical(d, W - S(62), S(210), "端末", fuente(F_CJK, S(120)), VERDE, 70, S(150))
    d.text((S(60), H - S(70)), "PHOSPHOR P1 · 525 LINES · NODE 07", font=fuente(F_MONO, S(14)), fill=VERDE + (110,))
    img = brillo(img, ov, S(10), 2)
    banda, bd = capa(W, H); bd.rectangle([0, int(H * .7), W, int(H * .7) + S(80)], fill=VERDE + (12,))
    img = Image.alpha_composite(img, banda.filter(ImageFilter.GaussianBlur(S(30))))
    return lineas_barrido(vineta(img, .8), 45)


def fondo_amber(W, H, t):
    s = min(W / 1920, H / 1080); S = lambda v: max(1, int(v * s)); CX, CY = W // 2, H // 2
    AMB, CLARO, NAR = (255, 176, 0), (255, 214, 120), (255, 122, 26)
    img = radial(W, H, (8, 5, 2), (36, 22, 6), 1.7)
    ov, d = capa(W, H)
    m = S(110); x0, y0, x1, y1 = m, m, W - m, H - m
    nx, ny = 10, 8; dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    for i in range(nx + 1):
        x = x0 + i * dx
        for y in range(int(y0), int(y1), S(8)): d.point((x, y), fill=AMB + (70,))
    for j in range(ny + 1):
        y = y0 + j * dy
        for x in range(int(x0), int(x1), S(8)): d.point((x, y), fill=AMB + (70,))
    for i in range(nx * 5 + 1):
        x = x0 + i * dx / 5; d.line([(x, CY - S(6)), (x, CY + S(6))], fill=AMB + (90,), width=1)
    for j in range(ny * 5 + 1):
        y = y0 + j * dy / 5; d.line([(CX - S(6), y), (CX + S(6), y)], fill=AMB + (90,), width=1)
    d.rectangle([x0, y0, x1, y1], outline=AMB + (90,), width=S(2))
    img = brillo(img, ov, S(2))
    # ondas
    for color, amp, f, fase, a, wd in [(NAR, S(150), 3.1, 1.2, 120, S(3)), (AMB, S(210), 2.0, 0, 235, S(4))]:
        ov, d = capa(W, H); pts = []
        for x in range(int(x0), int(x1) + 1, S(3)):
            u = (x - x0) / (x1 - x0)
            env = .35 + .65 * abs(math.sin(math.pi * u))
            y = CY + amp * env * (math.sin(2 * math.pi * f * u + fase) * .8 + .2 * math.sin(2 * math.pi * f * 4.3 * u))
            pts.append((x, y))
        d.line(pts, fill=color + (a,), width=wd, joint="curve")
        img = brillo(img, ov, S(9), 2)
    # emblema
    cajaE = S(250)
    ov, d = capa(W, H)
    d.rectangle([CX - cajaE, CY - cajaE, CX + cajaE, CY + cajaE], fill=(10, 6, 2, 215))
    img = Image.alpha_composite(img, ov)
    E, d = capa(W, H)
    esquinas(d, (CX - cajaE, CY - cajaE, CX + cajaE, CY + cajaE), S(54), AMB, 230, S(4))
    d.rectangle([CX - cajaE + S(16), CY - cajaE + S(16), CX + cajaE - S(16), CY + cajaE - S(16)], outline=AMB + (60,), width=S(1))
    o_barra(d, CX, CY - S(18), 1.25 * s, CLARO, 255, S(20))
    d.text((CX, CY + cajaE - S(48)), "Ø-SIGNAL // LOCKED", font=fuente(F_MONO, S(17)), fill=AMB + (220,), anchor="mm")
    img = brillo(img, E, S(16), 2)
    ov, d = capa(W, H)
    fl, fm, fs = fuente(F_LATIN, S(30)), fuente(F_MONO, S(18)), fuente(F_MONO, S(15))
    d.text((x0 + S(30), y1 - S(185)), "ZERØ SIGNAL LAB", font=fl, fill=CLARO + (235,))
    d.text((x0 + S(30), y1 - S(145)), "琥珀 // AMBER-04", font=fuente(F_CJK, S(18)), fill=AMB + (200,))
    for i, txt in enumerate(["CH1  2.00 V/div", "CH2  500 mV/div", "T    10.0 ms/div", "TRIG ^ 0.42 V"]):
        d.text((CX + S(380), y0 + S(30) + i * S(26)), txt, font=fm, fill=AMB + (200 if i != 3 else 240,), anchor="ra")
    d.text((x0 + S(30), y1 - S(40)), "f = 87.30 MHz   Vpp = 4.20 V   ZERØLAYER", font=fs, fill=AMB + (160,))
    d.text((W - S(540), y1 - S(10)), "琥珀", font=fuente(F_CJK, S(260)), fill=AMB + (20,), anchor="rd")
    img = brillo(img, ov, S(3))
    img = lineas_barrido(vineta(img, .7, (6, 3, 0)), 30)
    # esquinas redondeadas de tubo
    mask = Image.new("L", (W, H), 0); ImageDraw.Draw(mask).rounded_rectangle([S(14), S(14), W - S(14), H - S(14)], S(60), fill=255)
    marco = Image.new("RGBA", (W, H), (2, 1, 0, 255)); marco.putalpha(Image.eval(mask.filter(ImageFilter.GaussianBlur(S(10))), lambda v: 255 - v))
    return Image.alpha_composite(img, marco)


def fondo_void(W, H, t):
    s = min(W / 1920, H / 1080); S = lambda v: max(1, int(v * s))
    CX, CY = int(W * .6), int(H * .48)
    VIO, TEAL, LILA = (168, 121, 255), (93, 228, 199), (220, 200, 255)
    img = radial(W, H, (4, 3, 8), (24, 13, 44), 2.0, CX, CY)
    neb, d = capa(W, H)
    for (x, y, rx, ry, c, a) in [(.6, .45, .34, .26, VIO, 95), (.78, .64, .2, .15, TEAL, 45), (.42, .28, .2, .13, (255, 90, 200), 34), (.22, .78, .26, .16, VIO, 40)]:
        d.ellipse([W * (x - rx), H * (y - ry), W * (x + rx), H * (y + ry)], fill=c + (a,))
    img = Image.alpha_composite(img, neb.filter(ImageFilter.GaussianBlur(S(170))))
    ov, d = capa(W, H); rnd = random.Random(42)
    for _ in range(int(1600 * W * H / (1920 * 1080))):
        x, y = rnd.randrange(W), rnd.randrange(H); a = int(rnd.random() ** 3 * 200) + 25
        c = rnd.choice([(255, 255, 255), LILA, (200, 240, 255)])
        if rnd.random() < .04: d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=c + (min(255, a + 60),))
        else: d.point((x, y), fill=c + (a,))
    for _ in range(7):
        x, y = rnd.randrange(W), rnd.randrange(H); L = S(rnd.randint(8, 16))
        d.line([(x - L, y), (x + L, y)], fill=LILA + (150,), width=1); d.line([(x, y - L), (x, y + L)], fill=LILA + (150,), width=1)
    img = brillo(img, ov, 1)
    ov, d = capa(W, H)
    for (rx, ry, rot, a, w) in [(S(560), S(170), -16, 90, S(2)), (S(720), S(230), -16, 50, S(1)), (S(420), S(120), -16, 70, S(1))]:
        cr, sr = math.cos(math.radians(rot)), math.sin(math.radians(rot)); pts = []
        for k in range(0, 361, 2):
            u = math.radians(k); x, y = rx * math.cos(u), ry * math.sin(u)
            pts.append((CX + x * cr - y * sr, CY + x * sr + y * cr))
        d.line(pts, fill=LILA + (a,), width=w, joint="curve")
    for (rx, ry, k, c) in [(S(560), S(170), 205, TEAL), (S(720), S(230), 330, VIO)]:
        u = math.radians(k); cr, sr = math.cos(math.radians(-16)), math.sin(math.radians(-16))
        x, y = rx * math.cos(u), ry * math.sin(u); px_, py_ = CX + x * cr - y * sr, CY + x * sr + y * cr
        d.ellipse([px_ - S(7), py_ - S(7), px_ + S(7), py_ + S(7)], fill=c + (240,))
    img = brillo(img, ov, S(4))
    halo, hd = capa(W, H); hd.ellipse([CX - S(300), CY - S(260), CX + S(300), CY + S(260)], fill=VIO + (85,))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(S(120))))
    E, d = capa(W, H); o_barra(d, CX, CY, 2.7 * s, VIO, 255, S(16)); img = brillo(img, E, S(34), 3)
    E, d = capa(W, H); o_barra(d, CX, CY, 2.7 * s, LILA, 255, S(5)); img = brillo(img, E, S(6))
    ov, d = capa(W, H)
    texto_vertical(d, S(610), int(H * .2), "虚空", fuente(F_CJK, S(150)), VIO, 60, S(190))
    logotipo(d, S(110), H - S(170), S(30), LILA, 210, S(4))
    d.text((S(110), H - S(124)), "VOID // 虚空 · ULTRAVIOLET", font=fuente(F_CJK, S(16)), fill=VIO + (190,))
    d.text((W - S(80), H - S(80)), "RA 00h 00m 00s · DEC 0° 0′", font=fuente(F_MONO, S(14)), fill=LILA + (110,), anchor="ra")
    img = brillo(img, ov, S(3))
    return vineta(img, .6)


def fondo_mono(W, H, t):
    s = min(W / 1920, H / 1080); S = lambda v: max(1, int(v * s)); CX, CY = W // 2, H // 2
    B, G = (245, 245, 245), (150, 150, 150)
    img = radial(W, H, (0, 0, 0), (20, 20, 20), 2.2)
    ov, d = capa(W, H)
    for x in range(0, W, S(48)):
        for y in range(0, H, S(48)):
            d.point((x, y), fill=B + (60,))
            if (x // S(48) + y // S(48)) % 8 == 0:
                d.line([(x - 3, y), (x + 3, y)], fill=B + (90,)); d.line([(x, y - 3), (x, y + 3)], fill=B + (90,))
    img = brillo(img, ov, 0)
    halo, hd = capa(W, H); hd.ellipse([CX - S(300), CY - S(300), CX + S(300), CY + S(300)], fill=(255, 255, 255, 34))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(S(140))))
    ov, d = capa(W, H)
    for r, a, wd in [(S(385), 40, 1), (S(355), 70, S(1)), (S(290), 40, 1), (S(225), 55, 1)]:
        d.ellipse([CX - r, CY - r, CX + r, CY + r], outline=B + (a,), width=wd)
    for deg in range(0, 360, 2):
        a = math.radians(deg); r0 = S(355); L = S(18) if deg % 30 == 0 else (S(9) if deg % 10 == 0 else S(4))
        d.line([(CX + math.cos(a) * r0, CY + math.sin(a) * r0), (CX + math.cos(a) * (r0 + L), CY + math.sin(a) * (r0 + L))],
               fill=B + (150 if deg % 30 == 0 else 70,), width=1)
    R = S(385)
    for a0, a1 in ((-100, -40), (80, 140), (170, 182)):
        d.arc([CX - R, CY - R, CX + R, CY + R], a0, a1, fill=B + (230,), width=S(5))
    d.line([(CX, CY - S(420)), (CX, CY - S(480))], fill=B + (140,), width=1)
    img = brillo(img, ov, S(2))
    E, d = capa(W, H)
    o_barra(d, CX, CY, 1.9 * s, B, 255, S(5))
    img = brillo(img, E, S(26), 2)
    E, d = capa(W, H)
    o_barra(d, CX, CY, 1.9 * s, B, 255, S(4))
    img = Image.alpha_composite(img, E)
    ov, d = capa(W, H); fm = fuente(F_MONO, S(15)); fr = fuente(F_MONO_R, S(12)); fk = fuente(F_CJK, S(17))
    logotipo(d, S(70), H - S(148), S(26), B, 230, S(4))
    d.text((S(70), H - S(106)), "ZERØLAYER // MONO", font=fm, fill=B + (170,))
    d.text((S(70), H - S(82)), "無 · BLACK / WHITE", font=fk, fill=B + (110,))
    d.text((W - S(70), H - S(112)), "#000000  //  #F2F2F2", font=fm, fill=B + (140,), anchor="ra")
    esquinas(d, (S(40), S(70), W - S(40), H - S(56)), S(60), B, 140, S(2))
    d.text((S(70), S(98)), "REF 0000-ZERO", font=fr, fill=B + (130,))
    d.text((W - S(70), S(98)), "N 00°00′00″  E 000°00′00″", font=fr, fill=B + (130,), anchor="ra")
    rr = random.Random(21); px0, py0 = CX - S(440), S(150)
    d.text((px0, py0), "MONO://LEVEL", font=fr, fill=B + (150,))
    for i in range(12):
        x = px0 + i * S(9); hh = int(S(46) * (.15 + .85 * rr.random()))
        d.rectangle([x, py0 + S(66) - hh, x + S(4), py0 + S(66)], fill=B + (60 + int(110 * hh / S(46)),))
    codigo_barras(d, CX + S(250), S(150), S(110), S(26), 9, B, 120)
    d.text((CX + S(250), S(184)), "00 / 00 / 00", font=fr, fill=B + (130,))
    img = brillo(img, ov, S(2))
    # grano
    rnd = random.Random(8); gr, d = capa(W, H)
    for _ in range(int(2400 * W * H / (1920 * 1080))):
        d.point((rnd.randrange(W), rnd.randrange(H)), fill=(255, 255, 255, rnd.randint(8, 40)))
    img = Image.alpha_composite(img, gr)
    return vineta(img, .7)


FONDOS = {"zero-frost": fondo_frost, "zero-corp": fondo_corp, "zero-neon": fondo_neon,
          "zero-phosphor": fondo_phosphor, "zero-amber": fondo_amber, "zero-void": fondo_void, "zero-mono": fondo_mono}


def vista_previa(tid, t, fondo):
    """preview.png para el selector de Omarchy: fondo + ventana de terminal con la paleta."""
    W, H = 1280, 720
    img = fondo.resize((W, H), Image.LANCZOS).convert("RGBA")
    ov, d = capa(W, H)
    x0, y0, x1, y1 = 44, 430, 470, 676
    d.rounded_rectangle([x0, y0, x1, y1], 14, fill=rgb(t["background"]) + (236,))
    img = Image.alpha_composite(img, ov)
    ov, d = capa(W, H)
    d.rounded_rectangle([x0, y0, x1, y1], 14, outline=rgb(t["accent"]) + (255,), width=3)
    fm = fuente(F_MONO, 16); fl = fuente(F_LATIN, 28)
    d.text((x0 + 24, y0 + 20), t["nombre"], font=fl, fill=rgb(t["foreground"]) + (255,))
    d.text((x0 + 24, y0 + 64), "$ zerolayer theme " + tid.removeprefix("zero-"), font=fm, fill=rgb(t["foreground"]) + (230,))
    d.text((x0 + 24, y0 + 90), "> " + tid + " aplicado", font=fm, fill=rgb(t["green"]) + (255,))
    for i, k in enumerate(["red", "yellow", "green", "cyan", "blue", "magenta", "accent", "foreground"]):
        d.rounded_rectangle([x0 + 24 + i * 48, y0 + 136, x0 + 64 + i * 48, y0 + 176], 6, fill=rgb(t[k]) + (255,))
    d.text((x0 + 24, y0 + 198), f"acento {t['accent']}   fondo {t['background']}", font=fuente(F_MONO_R, 14), fill=rgb(t["dark_foreground"]) + (255,))
    img = Image.alpha_composite(img, ov)
    img.convert("RGB").save(os.path.join(AQUI, "themes", tid, "preview.png"), optimize=True)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    solo_datos = "--solo-datos" in sys.argv
    ids = args or list(TEMAS)
    for tid in ids:
        t = TEMAS[tid]
        escribir_datos(tid, t)
        if solo_datos:
            continue
        os.makedirs(os.path.join(AQUI, "fondos", tid), exist_ok=True)
        for (W, H) in TAMANOS:
            im = FONDOS[tid](W, H, t).convert("RGB")
            im.save(os.path.join(AQUI, "fondos", tid, f"{tid}-{W}x{H}.png"), optimize=True)
            if (W, H) == (1920, 1080):
                vista_previa(tid, t, im)
        print("ok", tid, flush=True)


if __name__ == "__main__":
    main()
