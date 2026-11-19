#!/usr/bin/env bash
# ZerØLayer · parte del módulo boot que necesita root. Se ejecuta con sudo desde module.sh:
#   sudo install-root.sh install <usuario> [logo.png]
#   sudo install-root.sh remove
set -euo pipefail
[[ $EUID == 0 ]] || { echo "ejecútalo con sudo" >&2; exit 1; }
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
LIB=/usr/local/lib/zerolayer STATE=/var/lib/zerolayer-boot CONF=/etc/zerolayer/boot.conf
LIMINE=${ZL_LIMINE_CONF:-/boot/limine.conf} ESP=${ZL_ESP:-/boot}

case ${1:-} in
install)
  user=${2:?falta el usuario}; logo=${3:-$HERE/zero-logo.png}
  [[ $user =~ ^[a-z_][a-z0-9_-]*$ ]] && id "$user" >/dev/null || { echo "usuario no válido: $user" >&2; exit 1; }
  home=$(getent passwd "$user" | cut -d: -f6)
  [[ -f $logo && ! -L $logo ]] && [[ $(head -c 8 "$logo" | od -An -tx1 | tr -d ' \n') == 89504e470d0a1a0a ]] \
    && (( $(stat -c %s "$logo") <= 64*1024*1024 )) || { echo "el logo debe ser un PNG normal (≤ 64 MiB): $logo" >&2; exit 1; }
  install -d -m 0755 "$LIB" /etc/zerolayer "$STATE"
  install -m 0755 -T "$HERE/boot-sync.sh" "$LIB/boot-sync"
  install -m 0644 -T "$logo" "$LIB/zero-logo.png"
  printf 'ZL_USER=%s\n' "$user" >"$CONF"; chmod 0644 "$CONF"
  install -m 0644 "$HERE/zerolayer-boot.service" /etc/systemd/system/zerolayer-boot.service
  sed "s|@HOME@|$home|g" "$HERE/zerolayer-boot.path" >/etc/systemd/system/zerolayer-boot.path
  systemctl daemon-reload
  systemctl enable --now zerolayer-boot.path
  systemctl start --no-block zerolayer-boot.service
  echo "instalado; primera sincronización en curso (journalctl -u zerolayer-boot -f)"
  ;;
remove)
  systemctl disable --now zerolayer-boot.path 2>/dev/null || true
  systemctl stop zerolayer-boot.service 2>/dev/null || true
  rm -f /etc/systemd/system/zerolayer-boot.service /etc/systemd/system/zerolayer-boot.path
  systemctl daemon-reload
  # Limine: devuelve la cabecera original (colores, marca…) y conserva las entradas actuales.
  if [[ -f $STATE/limine.conf.original && -f $LIMINE ]]; then
    python3 -I - "$STATE/limine.conf.original" "$LIMINE" <<'PY'
import sys
orig, cur = (open(p, encoding="utf-8").read().split("\n") for p in sys.argv[1:3])
cut = lambda ls: next((n for n, l in enumerate(ls) if l.startswith("/")), len(ls))
open(sys.argv[2] + ".zl-new", "w", encoding="utf-8").write("\n".join(orig[:cut(orig)] + cur[cut(cur):]))
PY
    mv -f "$LIMINE.zl-new" "$LIMINE"
  fi
  rm -rf "$ESP/zerolayer" "$LIB" /etc/zerolayer/boot.conf "$STATE"
  rmdir /etc/zerolayer 2>/dev/null || true
  echo "desinstalado; Plymouth y SDDM vuelven con: omarchy-plymouth-reset"
  ;;
*) echo "uso: install-root.sh install <usuario> [logo.png] | remove" >&2; exit 2 ;;
esac
