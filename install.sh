#!/usr/bin/env bash
# Instalador de ZerØLayer:
#   curl -fsSL https://raw.githubusercontent.com/raulplz/ZeroLayer/main/install.sh | bash
# Sin preguntas (módulos por defecto):
#   curl -fsSL https://raw.githubusercontent.com/raulplz/ZeroLayer/main/install.sh | bash -s -- --yes

set -euo pipefail

REPO=${ZEROLAYER_REPO:-https://github.com/raulplz/ZeroLayer.git}
DIR=${ZEROLAYER_DIR:-$HOME/.local/share/zerolayer}

say() { printf '\e[38;2;77;163;255mØ\e[0m %s\n' "$*"; }
die() { printf '\e[38;2;239;113;128m✗\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "No lo ejecutes como root: ZerØLayer pide sudo solo cuando lo necesita."
command -v git >/dev/null || die "Falta git."
if ! command -v omarchy >/dev/null && [[ ${ZEROLAYER_FORCE:-0} != 1 ]]; then
  die "ZerØLayer está hecho para Omarchy (https://omarchy.org). Para probar igualmente: ZEROLAYER_FORCE=1"
fi

# Antes se llamaba FrostLayer: mueve la instalación vieja y deja el comando antiguo como alias.
OLD_DIR=$HOME/.local/share/frostlayer
if [[ ! -e $DIR && -d $OLD_DIR/.git && -z ${ZEROLAYER_DIR:-} ]]; then
  say "Migrando FrostLayer a ZerØLayer"
  mv "$OLD_DIR" "$DIR"
  git -C "$DIR" remote set-url origin "$REPO"
fi
OLD_STATE=${XDG_STATE_HOME:-$HOME/.local/state}/frostlayer
NEW_STATE=${XDG_STATE_HOME:-$HOME/.local/state}/zerolayer
[[ -d $OLD_STATE && ! -e $NEW_STATE ]] && mv "$OLD_STATE" "$NEW_STATE"

if [[ -d $DIR/.git ]]; then
  say "Actualizando ZerØLayer en $DIR"
  git -C "$DIR" pull --ff-only --quiet
else
  say "Descargando ZerØLayer en $DIR"
  git clone --depth 1 --quiet "$REPO" "$DIR"
fi

mkdir -p "$HOME/.local/bin"
ln -sf "$DIR/bin/zerolayer" "$HOME/.local/bin/zerolayer"
[[ -L $HOME/.local/bin/frostlayer ]] && ln -sf "$DIR/bin/zerolayer" "$HOME/.local/bin/frostlayer"

# Con «curl | bash» la entrada es el propio script: el menú lee del terminal.
if [[ -r /dev/tty ]] && { : </dev/tty; } 2>/dev/null; then
  exec "$DIR/bin/zerolayer" install "$@" </dev/tty
else
  exec "$DIR/bin/zerolayer" install --yes "$@"
fi
