#!/usr/bin/env bash
# Pantalla de bloqueo de ZerØLayer: un plugin de servicio del shell de Omarchy
# (zerolayer.lock) derivado de omarchy.lock (MIT). Muestra la hora grande y bajo ella
# «DISPOSITIVO / DISTRO» (DMI y os-release) con el segundo acento del tema ZERØ activo.
# La autenticación (PAM y huella) es la del plugin original; al activarlo se desactivan
# omarchy.lock y cualquier otro plugin de bloqueo activo (se recuerdan para deshacer).

MODULE_DESC="Pantalla de bloqueo Frost (hora, dispositivo / distro, color del tema)"
MODULE_DEFAULT=0

LOCK_ID="zerolayer.lock"
PLUGINS_DIR="${ZEROLAYER_PLUGINS_DIR:-$HOME/.config/omarchy/plugins}"
LOCK_DST="$PLUGINS_DIR/$LOCK_ID"

# Plugins de bloqueo activos distintos del nuestro (omarchy.lock, copias «<usuario>.lock»…).
otros_bloqueos() {
  omarchy-plugin-list 2>/dev/null | awk -v me="$LOCK_ID" '$2 == "enabled" && $1 ~ /(^|\.)lock$/ && $1 != me { print $1 }'
}

module_check() {
  command -v omarchy-plugin-enable >/dev/null && command -v omarchy-shell >/dev/null ||
    { echo "hace falta Omarchy con el shell de plugins (omarchy-plugin-enable)"; return 1; }
  command -v jq >/dev/null || { echo "falta jq"; return 1; }
  omarchy-plugin-validate "$MODULE_DIR" >/dev/null 2>&1 ||
    { echo "el plugin no pasa omarchy-plugin-validate (¿versión de Omarchy distinta?)"; return 1; }
}

module_apply() {
  local previos; previos=$(otros_bloqueos | tr '\n' ' ')
  zl_state_set lock desactivados "$previos"
  if [[ -d $LOCK_DST ]]; then
    zl_run cp -a "$LOCK_DST" "$LOCK_DST.bak-$(date +%F-%H%M%S)"
  fi
  zl_run mkdir -p "$LOCK_DST"
  zl_run install -m 0644 "$MODULE_DIR/manifest.json" "$MODULE_DIR/Service.qml" "$MODULE_DIR/LockView.qml" "$LOCK_DST/"
  [[ $ZL_DRY_RUN == 1 ]] && return 0
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  local id
  for id in $previos; do omarchy-plugin-disable "$id" >/dev/null || zl_warn "No se pudo desactivar $id"; done
  omarchy-plugin-enable "$LOCK_ID" >/dev/null || { zl_err "No se pudo activar $LOCK_ID"; return 1; }
  zl_ok "Bloqueo activo: $LOCK_ID (desactivados: ${previos:-ninguno})"
  zl_dim "  Si el shell no recoge el cambio: omarchy-restart-shell"
}

module_revert() {
  local id previos; previos=$(zl_state_get lock desactivados)
  if [[ $ZL_DRY_RUN != 1 ]]; then
    omarchy-plugin-disable "$LOCK_ID" >/dev/null 2>&1 || true
    for id in ${previos:-omarchy.lock}; do omarchy-plugin-enable "$id" >/dev/null || zl_warn "No se pudo reactivar $id"; done
  fi
  zl_run rm -rf "$LOCK_DST"
}
