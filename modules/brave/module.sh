#!/usr/bin/env bash
# Brave más limpio y ligero. Solo toca ajustes que Brave no protege con firma.
# Brave tiene que estar cerrado: si no, sobrescribe los cambios al salir.

MODULE_DESC="Brave limpio: pestañas verticales, nueva pestaña Frost y ahorro de memoria"
MODULE_DEFAULT=0

BRAVE_DIR="${ZEROLAYER_BRAVE_DIR:-$HOME/.config/BraveSoftware/Brave-Browser}"
BRAVE_FILES=("$BRAVE_DIR/Default/Preferences" "$BRAVE_DIR/Local State")

module_check() {
  [[ -f ${BRAVE_FILES[0]} ]] || { echo "no hay perfil de Brave (ábrelo una vez primero)"; return 1; }
  command -v python3 >/dev/null || { echo "falta python3"; return 1; }
  if pgrep -x brave >/dev/null; then
    echo "Brave está abierto: ciérralo (Ctrl+Shift+Q) y vuelve a intentarlo"
    return 1
  fi
}

module_apply() {
  local file
  for file in "${BRAVE_FILES[@]}"; do zl_backup brave "$file"; done
  zl_run python3 -I "$MODULE_DIR/brave.py" "$BRAVE_DIR"
}

module_revert() {
  if pgrep -x brave >/dev/null; then
    zl_err "Cierra Brave antes de deshacer sus cambios"
    return 1
  fi
  local file
  for file in "${BRAVE_FILES[@]}"; do
    zl_restore brave "$file" || zl_warn "No hay copia de $file"
  done
}
