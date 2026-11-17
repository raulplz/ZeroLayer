#!/usr/bin/env bash
# Colores del tema activo en aplicaciones GTK3 y GTK4 (Nautilus, ajustes, diálogos…).
# El CSS sale de zerolayer.css.tpl con la paleta del tema de Omarchy; con el módulo
# theme instalado se recolorea solo cada vez que cambias de tema.

MODULE_DESC="Colores del tema activo en aplicaciones GTK3/GTK4"
MODULE_DEFAULT=1

GTK_FILES=("$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css")

module_check() { return 0; }

module_apply() {
  local css file
  css=$(bash "$ZL_ROOT/modules/theme/theme-sync.sh" --gtk-css) || return 1
  for file in "${GTK_FILES[@]}"; do
    zl_backup gtk "$file"
    zl_block_set "$file" gtk "/*" "$css"
  done
  zl_dim "  Las apps GTK abiertas cogen los colores al reiniciarlas."
}

module_revert() {
  local file
  for file in "${GTK_FILES[@]}"; do
    zl_block_remove "$file" gtk "/*"
  done
}
