#!/usr/bin/env bash
# ZerØLayer · sincroniza el arranque con el tema activo. Corre como root, por systemd.
#   boot-sync [--force] [--dry-run]
#
# Lee ~/.config/zerolayer/theme.json del usuario de /etc/zerolayer/boot.conf y aplica:
#   · Limine: paleta, marca, fondo con detalles del sistema (cabecera de limine.conf)
#   · Plymouth y SDDM (contraseña de disco y de sesión): colores y logo del tema
# El JSON lo escribe un usuario sin privilegios, así que de él solo se aceptan colores
# #RRGGBB, un id [a-z0-9-] y un nombre saneado; nada se usa como ruta ni como comando.
# Los activos de Omarchy salen de /usr/share/omarchy (propiedad de root).

set -euo pipefail
umask 022
PATH=${ZL_BOOT_PATH:-/usr/local/bin:/usr/bin:/bin}

CONF=${ZL_BOOT_CONF:-/etc/zerolayer/boot.conf}
LIB=${ZL_BOOT_LIB:-/usr/local/lib/zerolayer}
STATE=${ZL_BOOT_STATE:-/var/lib/zerolayer-boot}
LIMINE=${ZL_LIMINE_CONF:-/boot/limine.conf}
ESP=${ZL_ESP:-/boot}
OMA=${ZL_OMARCHY_DIR:-/usr/share/omarchy}
PLY=${ZL_PLYMOUTH_DIR:-/usr/share/plymouth/themes/omarchy}
SDDM=${ZL_SDDM_DIR:-/usr/share/sddm/themes/omarchy}
FONT=${ZL_BOOT_FONT:-/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf}
FORCE=0 DRY=0
for a in "$@"; do
  case $a in --force) FORCE=1 ;; --dry-run) DRY=1 ;; *) echo "opción desconocida: $a" >&2; exit 2 ;; esac
done

log() { printf 'zerolayer-boot: %s\n' "$*"; }
die() { printf 'zerolayer-boot: %s\n' "$*" >&2; exit 1; }
run() { if ((DRY)); then log "(prueba) $*"; else "$@"; fi; }

[[ -r $CONF ]] || die "falta $CONF"
ZL_USER=$(sed -n 's/^ZL_USER=\([a-z_][a-z0-9_-]*\)$/\1/p' "$CONF" | head -1)
[[ -n $ZL_USER ]] || die "ZL_USER no válido en $CONF"
HOME_DIR=$(getent passwd "$ZL_USER" | cut -d: -f6)
JSON=${ZL_THEME_JSON:-$HOME_DIR/.config/zerolayer/theme.json}
[[ -f $JSON ]] || die "no hay $JSON (cambia de tema una vez o ejecuta «zerolayer theme»)"

# ---------- tema validado ----------
declare -A C
eval "$(python3 -I - "$JSON" <<'PY'
import json, re, sys, unicodedata
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    col = d["colores"]
    out = {}
    for k in ("fondo", "superficie", "borde", "texto", "tenue", "acento", "acento2", "ok", "aviso", "peligro"):
        v = str(col[k]).lower()
        if not re.fullmatch(r"#[0-9a-f]{6}", v):
            raise ValueError(k)
        out[k] = v[1:]
    tid = str(d.get("id", ""))
    if not re.fullmatch(r"[a-z0-9-]{1,40}", tid):
        raise ValueError("id")
    nombre = unicodedata.normalize("NFKD", str(d.get("nombre", tid)).replace("Ø", "O").replace("ø", "o"))
    nombre = re.sub(r"[^A-Za-z0-9 ·.+-]", "", nombre.encode("ascii", "ignore").decode()).strip().upper()[:24] or tid.upper()
    out["id"], out["nombre"] = tid, nombre
    for k, v in out.items():
        print(f"C[{k}]='{v}'")
except Exception as e:
    print(f"echo 'theme.json no válido: {e}' >&2; exit 1")
PY
)"
[[ -n ${C[id]:-} ]] || die "theme.json no válido"

mezcla() { # mezcla aabbcc ddeeff t  →  rrggbb
  awk -v a="$1" -v b="$2" -v t="$3" 'function h(s,i){return index("0123456789abcdef",tolower(substr(s,i,1)))-1}
    function v(s,i){return h(s,i)*16+h(s,i+1)}
    BEGIN{printf "%02x%02x%02x", v(a,1)+(v(b,1)-v(a,1))*t+.5, v(a,3)+(v(b,3)-v(a,3))*t+.5, v(a,5)+(v(b,5)-v(a,5))*t+.5}'
}

KVER=$(ls -1 /usr/lib/modules 2>/dev/null | sort -V | tail -1 || true)
OVER=$(pacman -Q omarchy 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//' || true)
HOST=$(hostname 2>/dev/null | tr 'a-z' 'A-Z' | tr -cd 'A-Z0-9-' | cut -c1-16)

SRC_LOGO=$LIB/zero-logo.png
[[ -f $SRC_LOGO ]] || die "falta $SRC_LOGO"
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT

# magick sin metadatos (fechas): el mismo tema da siempre los mismos bytes.
mg() { local out=${!#}; magick "${@:1:$#-1}" -strip +set date:create +set date:modify +set date:timestamp "$out"; }

# ---------- activos ----------
# Logo: la forma del logo ZERØ en el color de acento del tema.
mg "$SRC_LOGO" -alpha extract -background "#${C[acento]}" -alpha shape "$STAGE/logo.png"

# Fondo del menú de Limine: rejilla, esquinas y datos del sistema, 1920x1200.
GRID=$(mezcla "${C[fondo]}" "${C[borde]}" .75)
mg -size 80x80 "xc:#${C[fondo]}" -fill none -stroke "#$GRID" -strokewidth 1 \
  -draw "line 0,0 79,0" -draw "line 0,0 0,79" "$STAGE/tile.png"
mg -size 1920x1200 tile:"$STAGE/tile.png" "$STAGE/grid.png"
mg "$STAGE/logo.png" -resize 1100x -channel A -evaluate multiply .10 +channel "$STAGE/logo-faint.png"
BR=100 SW=4
LEGIBLE=$(mezcla "${C[tenue]}" "${C[texto]}" .45)
# Tu fondo de escritorio (fondo_pantalla del tema) como fondo del menú. Se lee con los
# permisos del usuario, no con los de root, y solo se acepta si es un PNG o JPEG normal.
WALLPATH=$(python3 -I -c 'import json,sys
try:
    p = json.load(open(sys.argv[1], encoding="utf-8")).get("fondo_pantalla", "")
    print(p if isinstance(p, str) and p.startswith("/") and "\n" not in p else "")
except Exception:
    pass' "$JSON")
BASE="$STAGE/grid.png"
AS_USER=(); ((EUID == 0)) && AS_USER=(runuser -u "$ZL_USER" --)
if [[ -n $WALLPATH ]] && "${AS_USER[@]}" head -c 40000000 -- "$WALLPATH" >"$STAGE/user-bg.raw" 2>/dev/null \
   && [[ $(head -c 4 "$STAGE/user-bg.raw" | od -An -tx1 | tr -d ' \n') =~ ^(89504e47|ffd8ff) ]]; then
  # Oscurecido con el color de fondo del tema para que el menú se lea bien.
  FMT=png; [[ $(head -c 2 "$STAGE/user-bg.raw" | od -An -tx1 | tr -d ' \n') == ffd8 ]] && FMT=jpeg
  mg "$FMT:$STAGE/user-bg.raw" -resize 1920x1200^ -gravity center -extent 1920x1200 \
    \( -size 1920x1200 "xc:#${C[fondo]}" -alpha set -channel A -evaluate set 45% +channel \) -composite "$STAGE/user-bg.png" \
    && BASE="$STAGE/user-bg.png" && : >"$STAGE/usa-fondo"
fi
if [[ -f $STAGE/usa-fondo ]]; then FAINT=(); else FAINT=("$STAGE/logo-faint.png" -gravity center -composite); fi
mg "$BASE" "${FAINT[@]}" \
  -fill none -stroke "#${C[acento]}" -strokewidth $SW \
  -draw "polyline 40,$((40+BR)) 40,40 $((40+BR)),40" \
  -draw "polyline $((1920-40-BR)),40 $((1920-40)),40 $((1920-40)),$((40+BR))" \
  -draw "polyline 40,$((1200-40-BR)) 40,$((1200-40)) $((40+BR)),$((1200-40))" \
  -draw "polyline $((1920-40-BR)),$((1200-40)) $((1920-40)),$((1200-40)) $((1920-40)),$((1200-40-BR))" \
  -stroke none -font "$FONT" -pointsize 26 \
  -fill "#${C[acento]}" -gravity southwest -annotate +80+78 "ZEROLAYER // ${C[nombre]}" \
  -fill "#$LEGIBLE" -gravity southeast -annotate +80+78 "OMARCHY ${OVER:-?}  ·  LINUX ${KVER:-?}  ·  ${HOST:-PC}" \
  "$STAGE/wallpaper.png"

# Plymouth y SDDM a partir de los activos originales de Omarchy.
for a in bullet entry lock progress_bar; do
  mg "$OMA/default/plymouth/$a.png" -channel RGB +level-colors "#${C[texto]}","#${C[texto]}" "$STAGE/$a.png"
done
for a in entry lock; do
  mg "$STAGE/$a.png" -channel RGB +level-colors "#${C[peligro]}","#${C[peligro]}" "$STAGE/$a-failed.png"
done
rgb() { awk -v n="$((16#$1))" 'BEGIN{printf "%.3f", n/255}'; }
sed -e "s/^Window.SetBackgroundTopColor.*/Window.SetBackgroundTopColor($(rgb "${C[fondo]:0:2}"), $(rgb "${C[fondo]:2:2}"), $(rgb "${C[fondo]:4:2}"));/" \
    -e "s/^Window.SetBackgroundBottomColor.*/Window.SetBackgroundBottomColor($(rgb "${C[fondo]:0:2}"), $(rgb "${C[fondo]:2:2}"), $(rgb "${C[fondo]:4:2}"));/" \
    "$OMA/default/plymouth/omarchy.script" >"$STAGE/omarchy.script"
sed -e "s/#1a1b26/#__BG__/g" -e "s/#ffffff/#__TX__/g" -e "s/#__BG__/#${C[fondo]}/g" -e "s/#__TX__/#${C[texto]}/g" \
    "$OMA/default/sddm/omarchy/Main.qml" >"$STAGE/Main.qml"

# Publica un archivo solo si cambió: 0 = cambiado, 1 = ya estaba igual. Un fallo aborta todo.
publicar() {
  local src=$1 dst=$2 own=()
  ((EUID == 0)) && own=(-o 0 -g 0)
  if [[ -f $dst ]] && cmp -s "$src" "$dst"; then return 1; fi
  if ((DRY)); then log "(prueba) publicar $dst"; return 0; fi
  install "${own[@]}" -m 0644 -T "$src" "$dst.zl-new" || die "no pude escribir $dst"
  mv -f "$dst.zl-new" "$dst" || die "no pude reemplazar $dst"
  return 0
}

# ---------- ¿hace falta? ----------
huella=$(cat "$STAGE"/{wallpaper,logo,bullet,entry,lock,progress_bar,omarchy.script,Main.qml}* 2>/dev/null | sha256sum | cut -c1-16)
aplicado=$STATE/aplicado
vivo=$( { sha256sum "$PLY/logo.png" "$SDDM/Main.qml" 2>/dev/null || true; } | cut -c1-16 | tr -d '\n')
if ((!FORCE)) && [[ -f $aplicado ]] && [[ $(cat "$aplicado") == "${huella%%-*}:${C[id]}:$vivo" ]]; then
  log "ya aplicado (${C[id]})"; exit 0
fi

# ---------- Limine ----------
if [[ -f $LIMINE ]]; then
  [[ -f $STATE/limine.conf.original ]] || run install -D -m 0600 "$LIMINE" "$STATE/limine.conf.original" || die "no pude guardar la copia de limine.conf"
  run install -d -m 0755 "$ESP/zerolayer" || die "no pude crear $ESP/zerolayer"
  publicar "$STAGE/wallpaper.png" "$ESP/zerolayer/wallpaper.png" || true
  BRIGHT_ROJO=$(mezcla "${C[peligro]}" "${C[texto]}" .25)
  python3 -I - "$LIMINE" "$STAGE/limine.new" <<PY
import re, sys
src, dst = sys.argv[1:3]
bg, tx, ac, ac2 = "${C[fondo]}", "${C[texto]}", "${C[acento]}", "${C[acento2]}"
vals = {
  "interface_branding": "ZERO // ${C[nombre]}",
  "interface_branding_color": ac,
  "interface_help_color": "${C[tenue]}",
  "interface_help_color_bright": ac2,
  "wallpaper": "boot():/zerolayer/wallpaper.png",
  "wallpaper_style": "stretched",
  "term_background": "60" + bg,
  "backdrop": bg,
  "term_margin": "56",
  "term_margin_gradient": "12",
  "term_foreground": tx,
  "term_foreground_bright": "$(mezcla "${C[texto]}" ffffff .5)",
  "term_background_bright": "${C[superficie]}",
  "term_palette": ";".join(["${C[superficie]}", "${C[peligro]}", "${C[ok]}", "${C[aviso]}", ac, "$(mezcla "${C[acento]}" "${C[peligro]}" .5)", ac2, tx]),
  "term_palette_bright": ";".join(["${C[tenue]}", "$BRIGHT_ROJO", "$(mezcla "${C[ok]}" ffffff .25)", "$(mezcla "${C[aviso]}" ffffff .25)", "$(mezcla "${C[acento]}" ffffff .25)", "$(mezcla "${C[acento]}" "${C[peligro]}" .7)", "$(mezcla "${C[acento2]}" ffffff .25)", "$(mezcla "${C[texto]}" ffffff .5)"]),
}
for k, v in vals.items():
    if not re.fullmatch(r"[A-Za-z0-9 /_:;.,+()-]+", v.replace("//", "/")):
        sys.exit("valor no seguro para " + k)
lines = open(src, encoding="utf-8").read().split("\n")
i = next((n for n, l in enumerate(lines) if l.startswith("/")), len(lines))
head, rest = lines[:i], lines[i:]
done = set()
for n, l in enumerate(head):
    m = re.match(r"^([a-z_]+):", l)
    if m and m.group(1) in vals:
        head[n] = f"{m.group(1)}: {vals[m.group(1)]}"
        done.add(m.group(1))
extra = [f"{k}: {v}" for k, v in vals.items() if k not in done]
while head and head[-1] == "":
    head.pop()
open(dst, "w", encoding="utf-8").write("\n".join(head + extra + [""] + rest))
PY
  if ((DRY)); then
    log "(prueba) cabecera de Limine nueva:"; sed -n '1,/^\//p' "$STAGE/limine.new" | head -40
  elif ! cmp -s "$STAGE/limine.new" "$LIMINE"; then
    # Debe conservar todas las entradas y arranque; si no, no se toca.
    [[ $(grep -c '^ *//' "$STAGE/limine.new") == $(grep -c '^ *//' "$LIMINE") ]] || die "la nueva limine.conf perdería entradas; no la aplico"
    install -m 0755 -T "$STAGE/limine.new" "$LIMINE.zl-new" && mv -f "$LIMINE.zl-new" "$LIMINE"
    log "Limine actualizado"
  fi
fi

# ---------- Plymouth y SDDM ----------
cambio=0
if [[ -d $PLY ]]; then
  publicar "$STAGE/logo.png" "$PLY/logo.png" && cambio=1
  for a in bullet.png entry.png lock.png progress_bar.png omarchy.script; do publicar "$STAGE/$a" "$PLY/$a" && cambio=1; done
fi
if [[ -d $SDDM ]]; then
  publicar "$STAGE/logo.png" "$SDDM/logo.png" || true
  for a in bullet.png entry.png lock.png Main.qml; do publicar "$STAGE/$a" "$SDDM/$a" || true; done
  for a in entry lock; do publicar "$STAGE/$a-failed.png" "$SDDM/$a-failed.png" || true; done
  run rm -f "$SDDM/logo.svg" || true
fi
if ((cambio)); then
  log "Plymouth cambiado: regenerando la imagen de arranque (~1 min)"
  run plymouth-set-default-theme omarchy
  if command -v limine-mkinitcpio >/dev/null; then run limine-mkinitcpio; else run mkinitcpio -P; fi
fi

if ((!DRY)); then
  install -d -m 0755 "$STATE"
  vivo=$( { sha256sum "$PLY/logo.png" "$SDDM/Main.qml" 2>/dev/null || true; } | cut -c1-16 | tr -d '\n')
  printf '%s' "${huella%%-*}:${C[id]}:$vivo" >"$aplicado"
  log "aplicado ${C[id]}"
fi
