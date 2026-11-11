#!/usr/bin/env bash
# Pantalla de arranque y desbloqueo (Plymouth + SDDM) con el logo ZERØ.
# Usa la herramienta oficial de Omarchy, que pide sudo y regenera la imagen de arranque.
# Para usar tu propio logo: ZEROLAYER_LOGO=/ruta/logo.png zerolayer install boot

MODULE_DESC="Pantalla de arranque Frost con logo ZERØ (pide sudo)"
MODULE_DEFAULT=0

module_check() {
  command -v omarchy-plymouth-set >/dev/null || { echo "falta omarchy-plymouth-set (¿es Omarchy?)"; return 1; }
}

module_apply() {
  local logo=${ZEROLAYER_LOGO:-$MODULE_DIR/zero-logo.png}
  [[ -f $logo ]] || { zl_err "No encuentro el logo: $logo"; return 1; }
  zl_info "Omarchy pedirá tu contraseña para instalar el logo y regenerar el arranque."
  zl_run omarchy-plymouth-set '#080b10' '#d5dfeb' "$logo"
  zl_dim "  Tras cada «omarchy update» puede volver al diseño original: zerolayer install boot"
}

module_revert() {
  zl_run omarchy-plymouth-reset
}
