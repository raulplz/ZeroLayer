#!/usr/bin/env bash
# Aspecto de Hyprland: esquinas suaves, cristal, márgenes y transiciones cortas.
# No reescribe tus archivos: añade hypr/zerolayer.lua y una línea que lo carga.

MODULE_DESC="Hyprland Frost: esquinas de 14 px, desenfoque, márgenes y animaciones"
MODULE_DEFAULT=1

HYPR_DIR="$HOME/.config/hypr"
HYPR_MAIN="$HYPR_DIR/hyprland.lua"
HYPR_FROST="$HYPR_DIR/zerolayer.lua"
HYPR_LEGACY="$HYPR_DIR/frostlayer.lua"   # nombre anterior (FrostLayer)

module_check() {
  [[ -f $HYPR_MAIN ]] || { echo "no encuentro $HYPR_MAIN (hace falta Omarchy 4 con configuración Lua)"; return 1; }
}

module_apply() {
  zl_backup hyprland "$HYPR_MAIN"
  zl_run rm -f "$HYPR_LEGACY"
  zl_run cp "$MODULE_DIR/zerolayer.lua" "$HYPR_FROST"
  zl_block_set "$HYPR_MAIN" hyprland "--" 'require("hypr.zerolayer")'

  if [[ $ZL_DRY_RUN != 1 ]] && command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload >/dev/null 2>&1 || true
    local errors
    errors=$(hyprctl configerrors 2>/dev/null | grep -v -x -e '' -e 'no errors' || true)
    if grep -qi zerolayer <<<"$errors"; then
      zl_err "Hyprland rechaza la configuración de ZerØLayer; la retiro:"
      printf '%s\n' "$errors" >&2
      module_revert
      return 1
    fi
  fi
}

module_revert() {
  zl_block_remove "$HYPR_MAIN" hyprland "--"
  zl_run rm -f "$HYPR_FROST" "$HYPR_LEGACY"
  if [[ $ZL_DRY_RUN != 1 && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
}
