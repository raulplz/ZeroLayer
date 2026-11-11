#!/usr/bin/env bash
# Funciones compartidas por la CLI y los módulos de ZerØLayer.

ZL_STATE="${ZEROLAYER_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/zerolayer}"
# Estado de la versión anterior (FrostLayer): se reutiliza una sola vez.
_zl_old_state="${XDG_STATE_HOME:-$HOME/.local/state}/frostlayer"
if [[ -z ${ZEROLAYER_STATE:-} && -d $_zl_old_state && ! -e $ZL_STATE ]]; then
  mv "$_zl_old_state" "$ZL_STATE" 2>/dev/null || true
fi
ZL_DRY_RUN="${ZEROLAYER_DRY_RUN:-0}"

if [[ -t 1 ]]; then
  ZL_C_ICE=$'\e[38;2;156;220;245m' ZL_C_BLUE=$'\e[38;2;77;163;255m' ZL_C_DIM=$'\e[38;2;130;146;166m'
  ZL_C_OK=$'\e[38;2;143;190;160m' ZL_C_WARN=$'\e[38;2;230;191;121m' ZL_C_ERR=$'\e[38;2;239;113;128m'
  ZL_C_RESET=$'\e[0m'
else
  ZL_C_ICE='' ZL_C_BLUE='' ZL_C_DIM='' ZL_C_OK='' ZL_C_WARN='' ZL_C_ERR='' ZL_C_RESET=''
fi

zl_info() { printf '%sØ%s %s\n' "$ZL_C_BLUE" "$ZL_C_RESET" "$*"; }
zl_ok()   { printf '%s✓%s %s\n' "$ZL_C_OK" "$ZL_C_RESET" "$*"; }
zl_warn() { printf '%s!%s %s\n' "$ZL_C_WARN" "$ZL_C_RESET" "$*" >&2; }
zl_err()  { printf '%s✗%s %s\n' "$ZL_C_ERR" "$ZL_C_RESET" "$*" >&2; }
zl_dim()  { printf '%s%s%s\n' "$ZL_C_DIM" "$*" "$ZL_C_RESET"; }

# Ejecuta un comando, o solo lo muestra en modo de prueba.
zl_run() {
  if [[ $ZL_DRY_RUN == 1 ]]; then
    zl_dim "  (prueba) $*"
  else
    "$@"
  fi
}

# Copia un archivo antes de modificarlo, una sola vez por módulo.
# Las copias quedan en $ZL_STATE/backups/<módulo>/<ruta relativa a $HOME>.
zl_backup() {
  local module=$1 path=$2
  local rel=${path#"$HOME"/}
  local dest="$ZL_STATE/backups/$module/$rel"
  [[ -e $path && ! -e $dest ]] || return 0
  [[ $ZL_DRY_RUN == 1 ]] && { zl_dim "  (prueba) copia de $path"; return 0; }
  mkdir -p "$(dirname "$dest")"
  cp -a "$path" "$dest"
}

# Devuelve el archivo a su estado anterior si hay copia.
zl_restore() {
  local module=$1 path=$2
  local rel=${path#"$HOME"/}
  local src="$ZL_STATE/backups/$module/$rel"
  [[ -e $src ]] || return 1
  zl_run cp -a "$src" "$path"
}

# Bloques marcados dentro de archivos que no son nuestros:
#   <comentario> >>> ZeroLayer:<módulo>
#   ...
#   <comentario> <<< ZeroLayer:<módulo>
# zl_block_set reemplaza el bloque si existe o lo añade al final.
# En CSS la marca se cierra («/* … */»); si no, el bloque entero quedaría comentado.
_zl_close() { [[ $1 == "/*" ]] && printf ' */'; }

zl_block_set() {
  local file=$1 module=$2 comment=$3 content=$4 close
  close=$(_zl_close "$comment")
  local start="$comment >>> ZeroLayer:$module$close" end="$comment <<< ZeroLayer:$module$close"
  [[ $ZL_DRY_RUN == 1 ]] && { zl_dim "  (prueba) bloque $module en $file"; return 0; }
  mkdir -p "$(dirname "$file")"
  touch "$file"
  zl_block_remove "$file" "$module" "$comment"
  [[ -s $file && $(tail -c1 "$file") != "" ]] && printf '\n' >>"$file"
  printf '%s\n%s\n%s\n' "$start" "$content" "$end" >>"$file"
}

zl_block_remove() {
  local file=$1 module=$2 comment=$3
  [[ -f $file ]] || return 0
  [[ $ZL_DRY_RUN == 1 ]] && { zl_dim "  (prueba) quitar bloque $module de $file"; return 0; }
  local close
  close=$(_zl_close "$comment")
  local start="$comment >>> ZeroLayer:$module$close" end="$comment <<< ZeroLayer:$module$close"
  # También retira los bloques con el nombre anterior (FrostLayer).
  local old_start="$comment >>> FrostLayer:$module" old_end="$comment <<< FrostLayer:$module"
  awk -v s="$start" -v e="$end" -v os="$old_start" -v oe="$old_end" \
    '$0==s||$0==os{skip=1; next} $0==e||$0==oe{skip=0; next} !skip' "$file" >"$file.zerolayer.tmp"
  mv "$file.zerolayer.tmp" "$file"
}

zl_block_present() {
  local file=$1 module=$2 comment=$3
  [[ -f $file ]] && grep -qxF "$comment >>> ZeroLayer:$module$(_zl_close "$comment")" "$file"
}

# Estado de cada módulo instalado: $ZL_STATE/installed/<módulo>
zl_mark_installed() {
  [[ $ZL_DRY_RUN == 1 ]] && return 0
  mkdir -p "$ZL_STATE/installed"
  date '+%Y-%m-%d %H:%M' >"$ZL_STATE/installed/$1"
}
zl_unmark_installed() { [[ $ZL_DRY_RUN == 1 ]] || rm -f "$ZL_STATE/installed/$1"; }
zl_is_installed() { [[ -f $ZL_STATE/installed/$1 ]]; }

# Datos pequeños que un módulo necesita para deshacer (p. ej. el tema anterior).
zl_state_set() { [[ $ZL_DRY_RUN == 1 ]] || { mkdir -p "$ZL_STATE/data"; printf '%s\n' "$3" >"$ZL_STATE/data/$1.$2"; }; }
zl_state_get() { cat "$ZL_STATE/data/$1.$2" 2>/dev/null; }
