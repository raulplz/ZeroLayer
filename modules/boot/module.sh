#!/usr/bin/env bash
# Arranque ZerØ que sigue al tema activo: menú de Limine, contraseña de disco (Plymouth)
# y de sesión (SDDM). Un servicio de systemd vigila el tema y se vuelve a aplicar solo
# si una actualización de Omarchy restaura su pantalla. Pide sudo una vez, al instalar.
# Logo propio: ZEROLAYER_LOGO=/ruta/logo.png zerolayer install boot

MODULE_DESC="Arranque ZERØ que sigue al tema: Limine, contraseña de disco y de sesión (pide sudo)"
MODULE_DEFAULT=0

module_check() {
  command -v limine-mkinitcpio >/dev/null || command -v mkinitcpio >/dev/null || { echo "falta mkinitcpio"; return 1; }
  command -v magick >/dev/null || { echo "falta ImageMagick (magick)"; return 1; }
  command -v systemctl >/dev/null || { echo "falta systemd"; return 1; }
  [[ -f $HOME/.config/zerolayer/theme.json ]] || { echo "instala antes el módulo theme (escribe theme.json)"; return 1; }
}

module_apply() {
  local logo=${ZEROLAYER_LOGO:-$MODULE_DIR/zero-logo.png}
  [[ -f $logo ]] || { zl_err "No encuentro el logo: $logo"; return 1; }
  zl_info "Pido sudo una vez para instalar el servicio de sincronización del arranque."
  zl_run sudo bash "$MODULE_DIR/install-root.sh" install "$USER" "$(realpath "$logo")" || return 1
  zl_dim "  Se aplica ahora y tras cada cambio de tema. Estado: journalctl -u zerolayer-boot"
  zl_dim "  Regenerar la imagen de arranque tarda ~1 min la primera vez y al cambiar de tema."
}

module_revert() {
  zl_run sudo bash "$MODULE_DIR/install-root.sh" remove || return 1
  zl_run omarchy-plymouth-reset
}
