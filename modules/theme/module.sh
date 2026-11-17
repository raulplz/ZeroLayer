#!/usr/bin/env bash
# Familia de temas ZERØ para Omarchy: zero-frost, zero-corp, zero-neon, zero-phosphor,
# zero-amber y zero-void. Cada uno es un tema completo de Omarchy (colores, fondo a la
# resolución de tu monitor, iconos de carpeta y vista previa), así que salen también en
# el selector nativo. Un hook theme-set mantiene ~/.config/zerolayer/theme.json y GTK
# al día con el tema que elijas, sea o no ZERØ (también la paleta de Serpantinum si lo
# tienes: theme.colors de su settings.json, que se devuelve al desinstalar).
# Los fondos y la paleta se generan con generar.py (uv run --with pillow).

MODULE_DESC="Temas ZERØ para Omarchy (Frost, Corp, Neon, Phosphor, Amber, Void) con fondos e iconos"
MODULE_DEFAULT=1

THEMES_SRC="$MODULE_DIR/themes"
FONDOS_SRC="$MODULE_DIR/fondos"
ICONS_SRC="$MODULE_DIR/icons"
USER_THEMES="$HOME/.config/omarchy/themes"
ICONS_DIR="$HOME/.local/share/icons"
HOOK_DST="$HOME/.config/omarchy/hooks/theme-set.d/zerolayer-theme.hook"
OMARCHY_CUR="$HOME/.local/state/omarchy/current"
THEME_JSON="$HOME/.config/zerolayer/theme.json"
SERP_SETTINGS="${ZEROLAYER_SERPANTINUM_SETTINGS:-$HOME/.config/serpantinum/settings.json}"
# Versiones anteriores instalaban un único tema «frost» con iconos «Frost».
LEGACY_THEME="$USER_THEMES/frost"
LEGACY_ICONS="$ICONS_DIR/Frost"

# Marca de «esto lo instalamos nosotros» (.frostlayer: versiones anteriores).
ours() { [[ -e $1/.zerolayer || -e $1/.frostlayer ]]; }
tema_actual() { cat "$OMARCHY_CUR/theme.name" 2>/dev/null || true; }
ids() { local d; for d in "$THEMES_SRC"/*/; do basename "$d"; done; }
iconos() { local d; for d in "$ICONS_SRC"/*/; do basename "$d"; done; }
es_zero() { [[ $1 == zero-* || $1 == frost ]]; }

# Resolución del monitor más grande (ancho alto), o 2560 1440 si no hay Hyprland.
monitor() {
  local r
  r=$(hyprctl monitors -j 2>/dev/null | jq -r 'max_by(.width * .height) | "\(.width) \(.height)"' 2>/dev/null)
  [[ $r =~ ^[0-9]+\ [0-9]+$ ]] && echo "$r" || echo "2560 1440"
}

# Fondo de un tema que mejor encaja: misma proporción y lo bastante grande.
elegir_fondo() {
  local id=$1 mw mh f
  read -r mw mh < <(monitor)
  for f in "$FONDOS_SRC/$id"/*.png; do
    [[ $f =~ -([0-9]+)x([0-9]+)\.png$ ]] && echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} $f"
  done | awk -v mw="$mw" -v mh="$mh" '
    { r=$1/$2-mw/mh; if (r<0) r=-r; s=r*10000 + ($1>=mw ? ($1-mw)/100 : 1000+(mw-$1)/100)
      if (best=="" || s<best) { best=s; f=$3 } }
    END { print f }'
}

module_check() {
  command -v omarchy-theme-set >/dev/null || { echo "falta omarchy-theme-set (¿es Omarchy?)"; return 1; }
  local id
  for id in $(ids); do
    if [[ -e $USER_THEMES/$id ]] && ! ours "$USER_THEMES/$id"; then
      echo "ya existe un tema «$id» que no es de ZerØLayer: $USER_THEMES/$id"; return 1
    fi
  done
  for id in $(iconos); do
    if [[ -e $ICONS_DIR/$id ]] && ! ours "$ICONS_DIR/$id"; then
      echo "ya existen unos iconos «$id» que no son de ZerØLayer: $ICONS_DIR/$id"; return 1
    fi
  done
}

instalar_hook() {
  if [[ $ZL_DRY_RUN == 1 ]]; then zl_dim "  (prueba) hook theme-set en $HOOK_DST"; return 0; fi
  mkdir -p "$(dirname "$HOOK_DST")"
  cat >"$HOOK_DST" <<EOF
#!/bin/bash
# ZeroLayer:theme · lo instala «zerolayer install theme» y lo quita «zerolayer uninstall theme».
# Tras cada cambio de tema de Omarchy (\$1 = tema) escribe ~/.config/zerolayer/theme.json
# y recolorea GTK si el módulo gtk está instalado.
sync="$MODULE_DIR/theme-sync.sh"
[[ -f \$sync ]] && bash "\$sync" "\$1"
EOF
  chmod 755 "$HOOK_DST"
}

module_apply() {
  local actual id dst destino fondo
  actual=$(tema_actual)
  if [[ -n $actual ]] && ! es_zero "$actual"; then
    zl_state_set theme previous "$actual"
    zl_state_set theme previous_bg "$(readlink -f "$OMARCHY_CUR/background" 2>/dev/null)"
  fi

  zl_run mkdir -p "$USER_THEMES" "$ICONS_DIR"
  for id in $(ids); do
    dst=$USER_THEMES/$id
    fondo=$(elegir_fondo "$id")
    zl_run rm -rf "$dst"
    zl_run cp -r "$THEMES_SRC/$id" "$dst"
    zl_run mkdir -p "$dst/backgrounds"
    [[ -n $fondo ]] && zl_run cp "$fondo" "$dst/backgrounds/$id.png"
    zl_run touch "$dst/.zerolayer"
  done
  zl_dim "  Fondos a $(monitor | tr ' ' x): $(basename "$(elegir_fondo zero-frost)" | sed 's/zero-frost-//; s/\.png$//')"
  for id in $(iconos); do
    zl_run rm -rf "$ICONS_DIR/$id"
    zl_run cp -r "$ICONS_SRC/$id" "$ICONS_DIR/$id"
    zl_run touch "$ICONS_DIR/$id/.zerolayer"
  done

  # Migración desde el tema único «frost»: solo se borra si es nuestro.
  ours "$LEGACY_THEME" && zl_run rm -rf "$LEGACY_THEME"
  ours "$LEGACY_ICONS" && zl_run rm -rf "$LEGACY_ICONS"

  # Los iconos heredan de Yaru (un color por tema) y Breeze para lo que no son carpetas.
  local missing=()
  [[ -d /usr/share/icons/Yaru-blue ]] || missing+=(yaru-icon-theme)
  [[ -d /usr/share/icons/breeze-dark ]] || missing+=(breeze-icons)
  if ((${#missing[@]})); then
    zl_info "Instalando iconos base: ${missing[*]}"
    zl_run omarchy-pkg-add "${missing[@]}" || zl_warn "No se pudieron instalar ${missing[*]}; los iconos usarán hicolor"
  fi

  instalar_hook

  # Tema a aplicar: ZEROLAYER_THEME, el ZERØ que ya tengas puesto o zero-frost.
  destino=${ZEROLAYER_THEME:-}
  if [[ -n $destino ]]; then
    destino=${destino,,}; [[ $destino == zero-* ]] || destino=zero-$destino
  elif [[ $actual == zero-* ]]; then
    destino=$actual
  else
    destino=zero-frost
  fi
  [[ -d $THEMES_SRC/$destino ]] || { zl_warn "No existe el tema «$destino»; uso zero-frost"; destino=zero-frost; }
  zl_run omarchy-theme-set "$destino"
  zl_dim "  Cambia de tema con «zerolayer theme» o desde el menú de Omarchy (Estilo → Tema)."
}

module_revert() {
  local previous prev_bg actual id
  previous=$(zl_state_get theme previous)
  prev_bg=$(zl_state_get theme previous_bg)
  actual=$(tema_actual)

  # Solo cambia de tema si sigues en uno nuestro. Con el hook aún puesto, GTK y
  # theme.json se ajustan al tema anterior antes de retirarlos.
  if es_zero "$actual"; then
    if [[ -n $previous ]]; then
      zl_run omarchy-theme-set "$previous" || zl_warn "No se pudo volver al tema «$previous»; elígelo en el menú de Omarchy"
      if [[ -f $prev_bg && $prev_bg != "$USER_THEMES"/zero-* ]]; then
        zl_run omarchy-theme-bg-set "$prev_bg" >/dev/null || true
      fi
    else
      zl_warn "No sé qué tema tenías antes; elige otro en el menú de Omarchy (Super+Alt+Espacio → Estilo → Tema)"
    fi
  fi

  # Paleta original de Serpantinum (el hook ya la había ajustado al tema anterior).
  zl_run python3 -I "$MODULE_DIR/serp-palette.py" revert "$SERP_SETTINGS" "$ZL_STATE/data/theme.serp_original" ||
    zl_warn "No pude devolver la paleta de Serpantinum; está en $ZL_STATE/data/theme.serp_original"

  [[ -f $HOOK_DST ]] && grep -q 'ZeroLayer:theme' "$HOOK_DST" && zl_run rm -f "$HOOK_DST"
  for id in $(ids); do ours "$USER_THEMES/$id" && zl_run rm -rf "$USER_THEMES/$id"; done
  for id in $(iconos); do ours "$ICONS_DIR/$id" && zl_run rm -rf "$ICONS_DIR/$id"; done
  ours "$LEGACY_THEME" && zl_run rm -rf "$LEGACY_THEME"
  ours "$LEGACY_ICONS" && zl_run rm -rf "$LEGACY_ICONS"
  zl_run rm -f "$THEME_JSON" "$ZL_STATE/data/theme.previous" "$ZL_STATE/data/theme.previous_bg"
  return 0
}
