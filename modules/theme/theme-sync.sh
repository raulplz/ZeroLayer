#!/usr/bin/env bash
# ZerØLayer · sincroniza la paleta del tema activo de Omarchy con lo demás.
#   theme-sync.sh [tema]     escribe ~/.config/zerolayer/theme.json (atómico) y, si el
#                            módulo gtk está instalado, recolorea su bloque de gtk.css y,
#                            si hay ajustes de Serpantinum, su paleta (theme.colors)
#   theme-sync.sh --gtk-css  imprime el CSS GTK de la paleta activa
# Lo llama el hook theme-set de Omarchy (también al elegir tema desde su menú) y
# `zerolayer theme`. Esquema de theme.json: docs/theme-json.md

set -uo pipefail

ZL_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
# shellcheck source=../../lib/common.sh
source "$ZL_ROOT/lib/common.sh"

THEME_DIR=${ZEROLAYER_THEME_DIR:-$HOME/.local/state/omarchy/current/theme}
OUT=${ZEROLAYER_THEME_JSON:-$HOME/.config/zerolayer/theme.json}
BG_LINK=$HOME/.local/state/omarchy/current/background
GTK_TPL=$ZL_ROOT/modules/gtk/zerolayer.css.tpl
SERP_SETTINGS=${ZEROLAYER_SERPANTINUM_SETTINGS:-$HOME/.config/serpantinum/settings.json}
SERP_ORIGINAL=$ZL_STATE/data/theme.serp_original
ZL_SERP_CONFIG=$HOME/.config/zerolayer/serpantinum.json
GTK_FILES=("$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css")

# Lee «clave = "valor"» de un TOML sencillo. Sección vacía = nivel superior.
toml_get() {
  local file=$1 section=$2 key=$3
  [[ -f $file ]] || return 0
  awk -v sec="$section" -v key="$key" '
    /^[[:space:]]*\[/ { cur=$0; gsub(/[][[:space:]]/, "", cur); next }
    cur==sec {
      line=$0; sub(/^[[:space:]]*/, "", line)
      if (index(line, key) == 1) {
        rest=substr(line, length(key) + 1)
        if (rest ~ /^[[:space:]]*=/) {
          sub(/^[[:space:]]*=[[:space:]]*"/, "", rest); sub(/".*$/, "", rest); print rest; exit
        }
      }
    }' "$file"
}

es_hex() { [[ $1 =~ ^#[0-9a-fA-F]{6}$ ]]; }

# Mezcla dos colores hex: mezcla <a> <b> <0..1>
mezcla() {
  awk -v a="${1#\#}" -v b="${2#\#}" -v t="$3" 'function h(s,i){return index("0123456789abcdef",tolower(substr(s,i,1)))-1}
    function v(s,i){return h(s,i)*16+h(s,i+1)}
    BEGIN{printf "#%02x%02x%02x", v(a,1)+(v(b,1)-v(a,1))*t+.5, v(a,3)+(v(b,3)-v(a,3))*t+.5, v(a,5)+(v(b,5)-v(a,5))*t+.5}'
}

declare -A COL
cargar_paleta() {
  local colors=$THEME_DIR/colors.toml meta=$THEME_DIR/zerolayer.toml k v
  local -A base
  for k in background foreground accent lighter_background dark_background dark_foreground muted selection \
    hyprland_inactive_border cyan green yellow red blue orange; do
    v=$(toml_get "$colors" "" "$k")
    es_hex "$v" && base[$k]=${v,,}
  done
  local fondo=${base[background]:-#080b10} texto=${base[foreground]:-#d5dfeb}
  COL[fondo]=$fondo
  COL[texto]=$texto
  COL[acento]=${base[accent]:-${base[blue]:-#4da3ff}}
  COL[superficie]=${base[lighter_background]:-$(mezcla "$fondo" "$texto" .06)}
  COL[borde]=${base[hyprland_inactive_border]:-${base[selection]:-$(mezcla "$fondo" "$texto" .15)}}
  COL[tenue]=${base[dark_foreground]:-${base[muted]:-$(mezcla "$texto" "$fondo" .4)}}
  COL[acento2]=${base[cyan]:-${COL[acento]}}
  COL[ok]=${base[green]:-#8fbea0}
  COL[aviso]=${base[yellow]:-#e6bf79}
  COL[peligro]=${base[red]:-#ef7180}
  [[ -n ${base[orange]:-} ]] && COL[naranja]=${base[orange]}
  COL[lateral]=$(mezcla "$fondo" "${COL[superficie]}" .5)
  # Un tema ZERØ trae sus propios valores en zerolayer.toml [colores].
  for k in fondo superficie borde texto tenue acento acento2 ok aviso peligro; do
    v=$(toml_get "$meta" colores "$k")
    es_hex "$v" && COL[$k]=${v,,}
  done
}

gtk_css() {
  local css k
  css=$(<"$GTK_TPL")
  for k in "${!COL[@]}"; do css=${css//\{\{$k\}\}/${COL[$k]}}; done
  printf '%s\n' "$css"
}

json_str() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

escribir_json() {
  local nombre=$1 meta=$THEME_DIR/zerolayer.toml
  local id nombre_v modo glifo kanji sans mono zero=false fondo_p
  id=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo "$nombre")
  id=${id:-$nombre}
  modo=$(toml_get "$THEME_DIR/colors.toml" "" mode); [[ $modo == light ]] || modo=dark
  if [[ -f $meta ]]; then
    zero=true
    nombre_v=$(toml_get "$meta" "" nombre); glifo=$(toml_get "$meta" "" glifo); kanji=$(toml_get "$meta" "" kanji)
    sans=$(toml_get "$meta" fuentes sans); mono=$(toml_get "$meta" fuentes mono)
  fi
  nombre_v=${nombre_v:-$(sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g' <<<"$id")}
  glifo=${glifo:-Ø}; kanji=${kanji:-零}; sans=${sans:-sans-serif}
  mono=${mono:-$(omarchy-font-current 2>/dev/null || echo monospace)}
  fondo_p=$(readlink -f "$BG_LINK" 2>/dev/null || true)

  local cols="" k
  for k in fondo superficie borde texto tenue acento acento2 ok aviso peligro; do
    cols+="${cols:+,}\"$k\":\"${COL[$k]}\""
  done
  local json
  json=$(printf '{"version":1,"id":%s,"nombre":%s,"modo":"%s","zerolayer":%s,\n "colores":{%s},\n "fondo_pantalla":%s,"glifo":%s,"kanji":%s,\n "fuentes":{"sans":%s,"mono":%s},\n "actualizado":"%s"}\n' \
    "$(json_str "$id")" "$(json_str "$nombre_v")" "$modo" "$zero" "$cols" "$(json_str "$fondo_p")" \
    "$(json_str "$glifo")" "$(json_str "$kanji")" "$(json_str "$sans")" "$(json_str "$mono")" "$(date -Iseconds)")

  mkdir -p "$(dirname "$OUT")"
  local tmp
  tmp=$(mktemp "$(dirname "$OUT")/.theme.json.XXXXXX") || return 1
  printf '%s' "$json" >"$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$OUT"
}

recolorear_gtk() {
  zl_is_installed gtk || return 0
  local css file
  css=$(gtk_css)
  for file in "${GTK_FILES[@]}"; do
    zl_block_present "$file" gtk "/*" && zl_block_set "$file" gtk "/*" "$css"
  done
  return 0
}

# Paleta de Serpantinum (theme.colors de su settings.json, que vigila y recarga en caliente).
# Antes del primer cambio guarda la paleta original; «zerolayer uninstall theme» la devuelve.
# Se desactiva con "themePalette": false en ~/.config/zerolayer/serpantinum.json.
sincronizar_serpantinum() {
  [[ -f $SERP_SETTINGS ]] || return 0
  local nombre cols="" k
  nombre=$(sed -n 's/.*"nombre":"\([^"]*\)".*/\1/p' "$OUT" 2>/dev/null | head -1)
  for k in "${!COL[@]}"; do cols+="${cols:+,}\"$k\":\"${COL[$k]}\""; done
  printf '{"nombre":%s,"colores":{%s}}' "$(json_str "${nombre:-ZERØ}")" "$cols" |
    python3 -I "$ZL_ROOT/modules/theme/serp-palette.py" apply "$SERP_SETTINGS" "$SERP_ORIGINAL" "$ZL_SERP_CONFIG" ||
    zl_warn "No pude actualizar la paleta de Serpantinum"
  return 0
}

cargar_paleta
case ${1:-} in
  --gtk-css) gtk_css ;;
  *)
    escribir_json "${1:-}"
    recolorear_gtk
    sincronizar_serpantinum
    ;;
esac
