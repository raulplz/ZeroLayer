#!/usr/bin/env bash
# zerolayer theme            menú de temas ZERØ (gum en terminal; menú de imágenes de Omarchy si no hay terminal)
# zerolayer theme <id>       aplica un tema: zero-corp, corp, frost… (tema + fondo + theme.json)
# zerolayer theme list       lista los temas ZERØ instalados
# zerolayer theme status     tema activo, si es ZERØ y el theme.json que leen las apps
# zerolayer theme update     regenera los temas ZERØ instalados (paleta e iconos) y reaplica el activo
# zerolayer theme --menu     fuerza el menú de imágenes de Omarchy (útil para un atajo de teclado)

set -euo pipefail

ZL_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
# shellcheck source=../../lib/common.sh
source "$ZL_ROOT/lib/common.sh"

SRC="$ZL_ROOT/modules/theme/themes"
USER_THEMES="$HOME/.config/omarchy/themes"
HOOK="$HOME/.config/omarchy/hooks/theme-set.d/zerolayer-theme.hook"
MENU_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zerolayer/theme-menu"

instalados() {
  local d id
  for d in "$SRC"/*/; do
    id=$(basename "$d")
    [[ -d $USER_THEMES/$id ]] && echo "$id"
  done
  return 0
}
campo() { sed -n "s/^$2 = \"\(.*\)\"/\1/p" "$USER_THEMES/$1/zerolayer.toml" 2>/dev/null | head -1; }
actual() { cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true; }

normalizar() {
  local x=${1,,}
  x=${x// /-}
  x=${x//ø/o}
  [[ $x == zero-* ]] || x=zero-$x
  echo "$x"
}

aplicar() {
  local id
  id=$(normalizar "$1")
  if [[ ! -d $USER_THEMES/$id ]]; then
    if [[ -d $SRC/$id ]]; then
      zl_err "«$id» no está instalado. Instálalo con: zerolayer install theme"
    else
      zl_err "No existe el tema «$1». Temas: $(ls "$SRC" | tr '\n' ' ')"
    fi
    return 1
  fi
  if [[ $ZL_DRY_RUN == 1 ]]; then zl_dim "  (prueba) omarchy-theme-set $id"; return 0; fi
  omarchy-theme-set "$id" >/dev/null
  # Sin el hook (p. ej. instalación a medias) theme.json se escribe igualmente.
  [[ -f $HOOK ]] || bash "$ZL_ROOT/modules/theme/theme-sync.sh" "$id"
  zl_ok "$(campo "$id" nombre) aplicado"
}

listar() {
  local id cur mark
  cur=$(actual)
  mapfile -t temas < <(instalados)
  ((${#temas[@]})) || { zl_warn "No hay temas ZERØ instalados: zerolayer install theme"; return 1; }
  for id in "${temas[@]}"; do
    [[ $id == "$cur" ]] && mark="${ZL_C_OK}●${ZL_C_RESET}" || mark=" "
    printf ' %s %-14s %-15s %s%s%s\n' "$mark" "$id" "$(campo "$id" nombre)" "$ZL_C_DIM" "$(campo "$id" idea)" "$ZL_C_RESET"
  done
}

# Tema activo, si es ZERØ y dónde está el theme.json (con su fecha).
estado() {
  local cur json=${ZEROLAYER_THEME_JSON:-$HOME/.config/zerolayer/theme.json} zero="no" fecha
  cur=$(actual)
  [[ -n $cur ]] || { zl_warn "No encuentro el tema activo de Omarchy"; return 1; }
  [[ -f $USER_THEMES/$cur/zerolayer.toml ]] && zero="sí ($(campo "$cur" nombre))"
  printf '  %-12s %s\n' "tema" "$cur"
  printf '  %-12s %s\n' "ZERØ" "$zero"
  if [[ -f $json ]]; then
    fecha=$(date -d "@$(stat -c %Y "$json")" '+%Y-%m-%d %H:%M:%S')
    printf '  %-12s %s %s(%s)%s\n' "theme.json" "$json" "$ZL_C_DIM" "$fecha" "$ZL_C_RESET"
  else
    printf '  %-12s %s\n' "theme.json" "no existe (se escribe al cambiar de tema)"
  fi
  if [[ -f $HOOK ]]; then
    printf '  %-12s %s\n' "hook" "instalado"
  else
    printf '  %-12s %s\n' "hook" "no instalado (zerolayer install theme)"
  fi
}

# Regenera los datos de los temas (colors.toml, zerolayer.toml, iconos) con generar.py,
# copia a los temas instalados lo que cambió (sin tocar sus fondos) y reaplica el activo.
actualizar() {
  mapfile -t temas < <(instalados)
  ((${#temas[@]})) || { zl_warn "No hay temas ZERØ instalados: zerolayer install theme"; return 1; }
  local gen="$ZL_ROOT/modules/theme/generar.py" id d f
  if [[ $ZL_DRY_RUN == 1 ]]; then
    zl_dim "  (prueba) generar.py --solo-datos ${temas[*]}; copiar a $USER_THEMES; reaplicar el activo"
    return 0
  fi
  if command -v uv >/dev/null; then
    zl_info "Regenerando ${temas[*]}"
    uv run --quiet --with pillow "$gen" --solo-datos "${temas[@]}" >/dev/null || { zl_err "generar.py ha fallado"; return 1; }
  else
    zl_warn "Sin «uv» no puedo regenerar; uso los datos que trae el repositorio"
  fi
  for id in "${temas[@]}"; do
    for f in colors.toml zerolayer.toml icons.theme preview.png; do
      [[ -f $SRC/$id/$f ]] && cp "$SRC/$id/$f" "$USER_THEMES/$id/$f"
    done
  done
  for d in "$ZL_ROOT"/modules/theme/icons/*/; do
    id=$(basename "$d")
    [[ -e $HOME/.local/share/icons/$id/.zerolayer ]] || continue
    cp -r "$d/." "$HOME/.local/share/icons/$id/"
  done
  local cur
  cur=$(actual)
  if [[ $cur == zero-* && -d $USER_THEMES/$cur ]]; then
    omarchy-theme-set "$cur" >/dev/null
    [[ -f $HOOK ]] || bash "$ZL_ROOT/modules/theme/theme-sync.sh" "$cur"
    zl_ok "Temas actualizados; $(campo "$cur" nombre) reaplicado"
  else
    zl_ok "Temas actualizados (el activo, «${cur:-ninguno}», no es ZERØ y no se toca)"
  fi
}

menu_imagenes() {
  local id elegido
  rm -rf "$MENU_DIR"; mkdir -p "$MENU_DIR"
  for id in $(instalados); do ln -s "$USER_THEMES/$id/preview.png" "$MENU_DIR/$id.png"; done
  local sel=() cur
  cur=$(actual)
  [[ -e $MENU_DIR/$cur.png ]] && sel=(--selected "$MENU_DIR/$cur.png")
  elegido=$(omarchy-menu-images --print-name --show-labels "${sel[@]}" "$MENU_DIR") || return 0
  [[ -n $elegido ]] && aplicar "$elegido"
}

menu() {
  mapfile -t temas < <(instalados)
  ((${#temas[@]})) || { zl_warn "No hay temas ZERØ instalados: zerolayer install theme"; return 1; }
  if [[ -t 0 && -t 1 ]] && command -v gum >/dev/null; then
    local labels=() id cur sel="" elegido
    cur=$(actual)
    for id in "${temas[@]}"; do
      labels+=("$id · $(campo "$id" nombre)")
      [[ $id == "$cur" ]] && sel="$id · $(campo "$id" nombre)"
    done
    elegido=$(gum choose --header "Tema ZERØ (Enter para aplicar)" ${sel:+--selected "$sel"} "${labels[@]}") || return 0
    aplicar "${elegido%% · *}"
  elif command -v omarchy-menu-images >/dev/null; then
    menu_imagenes
  else
    listar
  fi
}

case ${1:-} in
  "") menu ;;
  list | ls) listar ;;
  status) estado ;;
  update) actualizar ;;
  --menu) menu_imagenes ;;
  -h | --help) sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *) aplicar "$1" ;;
esac
