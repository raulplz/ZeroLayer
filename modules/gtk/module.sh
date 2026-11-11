#!/usr/bin/env bash
# Colores Frost para aplicaciones GTK3 y GTK4 (Nautilus, ajustes, diálogos…).

MODULE_DESC="Colores Frost en aplicaciones GTK3/GTK4"
MODULE_DEFAULT=1

GTK_FILES=("$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css")

module_check() { return 0; }

module_apply() {
  local css file
  css=$(<"$MODULE_DIR/frost.css")
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
