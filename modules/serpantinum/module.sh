#!/usr/bin/env bash
# Escritorio ZerØ para Serpantinum (https://github.com/ilyamiro/serpantinum).
# Añade widgets propios (notas .md, chats de IA, espectro hacker, ZeroStudy,
# agenda, pomodoro, repos git, Docker, ZeroAgents y juegos), compacta el de
# GitHub, muestra los widgets solo en escritorios vacíos y coloca en el monitor
# activo la disposición del perfil elegido (zerolayer configure widgets).
# Serpantinum es AGPL-3.0: esta carpeta también (ver LICENSE.md).
# Tras actualizar Serpantinum hay que volver a aplicarlo: zerolayer install serpantinum

MODULE_DESC="Escritorio Serpantinum: widgets ZerØ por perfiles (estudiante, dev, gamer, básico; requiere Serpantinum)"
MODULE_DEFAULT=0

SERP_DIR="${ZEROLAYER_SERPANTINUM_DIR:-$HOME/.local/share/serpantinum}"
SERP_QS="$SERP_DIR/src/quickshell"
SERP_STATE="${ZEROLAYER_SERPANTINUM_STATE:-$HOME/.local/state/serpantinum}"
ZL_SERP_CONFIG="$HOME/.config/zerolayer/serpantinum.json"
FACES=(notes/NotesFaceFrost.qml aichats/AiChatsFace.qml visualizer/VisualizerFaceHacker.qml)
FACES_DIR=zerolayer   # widgets ZerØ y piezas comunes (tema, marco, botón…), carpeta entera
GITHUB_USER_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/github/user.txt"
CORE=(widgets/Widget.qml widgets/WidgetLoader.qml widgets/WidgetRegistry.qml widgets/faces/github/GithubFace.qml)

module_check() {
  [[ -f $SERP_QS/widgets/WidgetRegistry.qml ]] || { echo "no encuentro Serpantinum en $SERP_DIR (instálalo antes o usa ZEROLAYER_SERPANTINUM_DIR)"; return 1; }
  command -v python3 >/dev/null || { echo "falta python3"; return 1; }
  command -v hyprctl >/dev/null || { echo "falta hyprctl (hace falta Hyprland)"; return 1; }
  local why
  why=$(python3 -I "$MODULE_DIR/patch.py" check "$SERP_QS" 2>&1) || { echo "${why//$'\n'/; }"; return 1; }
}

# Monitor con el foco: nombre y tamaño lógico (píxeles / escala, girado si hace falta).
focused_monitor() {
  hyprctl monitors -j | python3 -I -c '
import json, sys
mons = json.load(sys.stdin)
m = next((m for m in mons if m.get("focused")), mons[0])
w, h = m["width"] / m["scale"], m["height"] / m["scale"]
if m.get("transform", 0) % 2:
    w, h = h, w
print(m["name"], round(w), round(h))'
}

zl_interactive() {
  [[ ${ZL_ASSUME_YES:-0} != 1 && -t 0 && -t 1 ]] && command -v gum >/dev/null
}

cfg_get() {
  python3 -I -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))
except Exception: pass' "$ZL_SERP_CONFIG" "$1" 2>/dev/null
}

# Asistente: usuario de GitHub y chats de IA que destacar (Claude Code, Codex).
module_configure() {
  if [[ $ZL_DRY_RUN == 1 ]]; then
    zl_dim "  (prueba) preguntaría usuario de GitHub y chats destacados"
    return 0
  fi
  mkdir -p "$(dirname "$ZL_SERP_CONFIG")"
  [[ -f $ZL_SERP_CONFIG ]] || cp "$MODULE_DIR/serpantinum.example.json" "$ZL_SERP_CONFIG"

  local user
  user=$(cfg_get githubUser)
  [[ -z $user ]] && command -v gh >/dev/null && user=$(gh api user --jq .login 2>/dev/null || true)
  [[ -z $user ]] && user=$(git config --global github.user 2>/dev/null || true)
  if zl_interactive; then
    user=$(gum input --header "Usuario de GitHub para el widget de contribuciones (vacío: ninguno)" \
      --placeholder "usuario" --value "$user") || return 1
  fi
  user=${user//[^A-Za-z0-9-]/}

  local cands chosen=()
  cands=$(mktemp)
  python3 -I "$MODULE_DIR/chats.py" list >"$cands"
  if zl_interactive && [[ $(python3 -I "$MODULE_DIR/chats.py" labels "$cands" | wc -l) -gt 0 ]]; then
    local labels=() preselected=() idx line
    mapfile -t labels < <(python3 -I "$MODULE_DIR/chats.py" labels "$cands")
    while read -r idx; do
      [[ -n $idx ]] && preselected+=("${labels[$idx]}")
    done < <(python3 -I "$MODULE_DIR/chats.py" chosen "$cands" "$ZL_SERP_CONFIG")
    local picked
    picked=$(IFS=,; gum choose --no-limit --limit 6 --height 16 \
      --header "Chats que destacar en el escritorio (máx. 6; espacio para marcar, Enter para seguir)" \
      --selected "${preselected[*]}" "${labels[@]}") || { rm -f "$cands"; return 1; }
    while read -r line; do
      [[ -n $line ]] && chosen+=("$(sed 's/^ *\([0-9]*\) .*/\1/' <<<"$line")")
    done <<<"$picked"
    python3 -I "$MODULE_DIR/chats.py" save "$ZL_SERP_CONFIG" "$cands" "$user" "${chosen[@]}"
  else
    # Sin terminal: se conservan los chats que hubiera.
    python3 -I "$MODULE_DIR/chats.py" save "$ZL_SERP_CONFIG" - "$user"
    zl_interactive || zl_dim "  Para elegir chats destacados: zerolayer configure serpantinum"
  fi
  rm -f "$cands"

  if [[ -n $user ]]; then
    mkdir -p "$(dirname "$GITHUB_USER_FILE")"
    printf '%s' "$user" >"$GITHUB_USER_FILE"
  fi
  local count
  count=$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("chats", [])))' "$ZL_SERP_CONFIG" 2>/dev/null || echo 0)
  zl_ok "  GitHub: ${user:-ninguno} · chats destacados: $count · $ZL_SERP_CONFIG"
  [[ ${_ZL_IN_APPLY:-0} == 1 ]] || serp_reload
}

serp_reload() {
  [[ $ZL_DRY_RUN == 1 || ${ZEROLAYER_NO_RELOAD:-0} == 1 ]] && return 0
  if command -v serpantinum >/dev/null && pgrep -f 'quickshell|qs ' >/dev/null; then
    serpantinum reload >/dev/null 2>&1 || zl_warn "Recarga Serpantinum a mano: serpantinum reload"
  fi
}

module_apply() {
  local rel face
  for rel in "${CORE[@]}"; do zl_backup serpantinum "$SERP_QS/$rel"; done
  zl_run python3 -I "$MODULE_DIR/patch.py" apply "$SERP_QS" || return 1

  for face in "${FACES[@]}"; do
    zl_run mkdir -p "$SERP_QS/widgets/faces/$(dirname "$face")"
    zl_run cp "$MODULE_DIR/faces/$face" "$SERP_QS/widgets/faces/$face"
  done
  zl_run mkdir -p "$SERP_QS/widgets/faces/$FACES_DIR"
  zl_run cp "$MODULE_DIR/faces/$FACES_DIR/"* "$SERP_QS/widgets/faces/$FACES_DIR/"

  # Primera vez: asistentes (GitHub y chats; perfil de widgets).
  # Después: zerolayer configure serpantinum · zerolayer configure widgets
  if [[ ! -f $ZL_SERP_CONFIG ]]; then
    _ZL_IN_APPLY=1 module_configure || zl_warn "Configuración pendiente: zerolayer configure serpantinum"
    _ZL_IN_APPLY=1 module_configure_widgets || zl_warn "Perfil pendiente: zerolayer configure widgets"
  fi

  serp_layout || return 1
  serp_reload
}

# Escribe la disposición del perfil elegido en el monitor con el foco.
serp_layout() {
  local name width height layout
  read -r name width height < <(focused_monitor) || { zl_err "No pude leer el monitor activo"; return 1; }
  layout="$SERP_STATE/widgets/$name/layout.json"
  if [[ -f $layout ]]; then
    # Si la creamos nosotros en una instalación anterior, no es «la original».
    [[ $(zl_state_get serpantinum layout-created) == "$layout" ]] || zl_backup serpantinum "$layout"
  elif [[ $ZL_DRY_RUN != 1 ]]; then
    zl_state_set serpantinum layout-created "$layout"
  fi
  zl_state_set serpantinum layout "$layout"
  zl_run python3 -I "$MODULE_DIR/layout.py" build "$width" "$height" "$layout" "$ZL_SERP_CONFIG"
  zl_dim "  Disposición para $name (${width}×${height}); los widgets se ven en un escritorio vacío"
  SERP_MONITOR=$name
}

# Selector de widgets: perfil (dev, estudiante, gamer, básico…) y ajuste widget a widget.
#   zerolayer configure widgets            asistente
#   zerolayer configure widgets <perfil>   aplica un perfil sin preguntas
module_configure_widgets() {
  local L="$MODULE_DIR/layout.py" profile="${1:-}" current cur_ids
  if [[ $ZL_DRY_RUN == 1 ]]; then
    zl_dim "  (prueba) preguntaría perfil y widgets y recolocaría el escritorio"
    return 0
  fi
  mkdir -p "$(dirname "$ZL_SERP_CONFIG")"
  [[ -f $ZL_SERP_CONFIG ]] || cp "$MODULE_DIR/serpantinum.example.json" "$ZL_SERP_CONFIG"
  { read -r current; read -r cur_ids; } < <(python3 -I "$L" current "$ZL_SERP_CONFIG")

  local ids=()
  if [[ -n $profile ]]; then
    python3 -I "$L" ids "$profile" >/dev/null || { zl_err "Perfil desconocido: $profile (ver: $(python3 -I "$L" profiles | cut -d' ' -f1 | tr '\n' ' '))"; return 1; }
    mapfile -t ids < <(python3 -I "$L" ids "$profile")
  elif zl_interactive; then
    local plabels=() line sel
    mapfile -t plabels < <(python3 -I "$L" profiles)
    for line in "${plabels[@]}"; do [[ ${line%% *} == "$current" ]] && sel=$line; done
    profile=$(gum choose --height 10 --header "Perfil de escritorio (Enter para elegir; después podrás quitar o añadir widgets)" \
      --selected "$sel" "${plabels[@]}") || return 1
    profile=${profile%% *}

    local clabels=() pre=() want picked
    mapfile -t clabels < <(python3 -I "$L" catalog)
    if [[ $profile == "$current" ]]; then want=" $cur_ids "; else want=" $(python3 -I "$L" ids "$profile" | tr '\n' ' ') "; fi
    for line in "${clabels[@]}"; do [[ $want == *" ${line%% *} "* ]] && pre+=("$line"); done
    picked=$(IFS=,; gum choose --no-limit --height 18 \
      --header "Widgets en el escritorio (espacio para marcar, Enter para seguir)" \
      --selected "${pre[*]}" "${clabels[@]}") || return 1
    while read -r line; do [[ -n $line ]] && ids+=("${line%% *}"); done <<<"$picked"
    ((${#ids[@]})) || { zl_warn "No has marcado ningún widget; se usa el perfil tal cual."; }
  else
    profile=$current
    read -ra ids <<<"$cur_ids"
  fi
  python3 -I "$L" save "$ZL_SERP_CONFIG" "$profile" "${ids[@]}"
  read -ra ids < <(python3 -I "$L" current "$ZL_SERP_CONFIG" | sed -n 2p)
  widget_options "${ids[@]}"
  zl_ok "  Perfil: $profile · widgets: ${ids[*]}"

  [[ ${_ZL_IN_APPLY:-0} == 1 ]] && return 0
  if ! zl_is_installed serpantinum; then
    zl_dim "  Se aplicará al instalar: zerolayer install serpantinum"
    return 0
  fi
  serp_layout || return 1
  serp_widgets_reload
}

# Ajustes que necesitan algunos widgets; solo pregunta lo que falte.
widget_options() {
  local L="$MODULE_DIR/layout.py" have=" $* " v
  if [[ $have == *" repos "* && -z $(python3 -I "$L" get "$ZL_SERP_CONFIG" reposDirs) ]]; then
    v=""
    for d in ~/Work/PROYECTOS ~/Proyectos ~/proyectos ~/Projects ~/projects ~/src ~/code ~/dev; do
      [[ -d $d ]] && v+="${d/#$HOME/\~} "
    done
    if zl_interactive; then
      v=$(gum input --header "Carpetas con tus repos git (separadas por espacios)" --value "${v% }") || v=""
    fi
    [[ -n ${v// /} ]] && python3 -I "$L" set "$ZL_SERP_CONFIG" reposDirs "$(python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1].split()))' "$v")"
  fi
  if [[ $have == *" docker "* && -z $(python3 -I "$L" get "$ZL_SERP_CONFIG" dockerContext) ]] && command -v docker >/dev/null; then
    # Docker Desktop usa su propio contexto; solo se lee la lista de contextos.
    if docker context ls -q 2>/dev/null | grep -qx desktop-linux; then
      python3 -I "$L" set "$ZL_SERP_CONFIG" dockerContext '"desktop-linux"'
      zl_dim "  Docker: contexto desktop-linux"
    fi
  fi
  if [[ $have == *" agenda "* && -z $(python3 -I "$L" get "$ZL_SERP_CONFIG" agendaFile) ]] && zl_interactive; then
    v=$(gum input --header "Tabla de plazos .md para la agenda (vacío: solo calendario)" --placeholder "~/Notas/plazos.md") || v=""
    [[ -n $v ]] && python3 -I "$L" set "$ZL_SERP_CONFIG" agendaFile "$(python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$v")"
  fi
  return 0
}

# Recarga solo los widgets del monitor (sin reiniciar el escritorio).
serp_widgets_reload() {
  [[ $ZL_DRY_RUN == 1 || ${ZEROLAYER_NO_RELOAD:-0} == 1 ]] && return 0
  local target="widgets-${SERP_MONITOR//[^a-zA-Z0-9_-]/_}"
  if command -v quickshell >/dev/null && pgrep -x quickshell >/dev/null &&
    [[ $(quickshell -p "$SERP_QS/Shell.qml" ipc call "$target" reload 2>/dev/null) == ok ]]; then
    return 0
  fi
  serp_reload
}

module_revert() {
  local face layout created
  zl_run python3 -I "$MODULE_DIR/patch.py" revert "$SERP_QS"
  for face in "${FACES[@]}"; do
    # Solo borra caras nuestras (llevan la marca en la cabecera).
    if grep -qs 'ZeroLayer' "$SERP_QS/widgets/faces/$face"; then
      zl_run rm -f "$SERP_QS/widgets/faces/$face"
    fi
  done
  [[ -d $SERP_QS/widgets/faces/aichats ]] && zl_run rmdir --ignore-fail-on-non-empty "$SERP_QS/widgets/faces/aichats"
  local f
  for f in "$SERP_QS/widgets/faces/$FACES_DIR"/*; do
    grep -qs 'ZeroLayer' "$f" && zl_run rm -f "$f"
  done
  [[ -d $SERP_QS/widgets/faces/$FACES_DIR ]] && zl_run rmdir --ignore-fail-on-non-empty "$SERP_QS/widgets/faces/$FACES_DIR"

  layout=$(zl_state_get serpantinum layout)
  created=$(zl_state_get serpantinum layout-created)
  if [[ -n $layout ]]; then
    if ! zl_restore serpantinum "$layout" && [[ $created == "$layout" ]]; then
      zl_run rm -f "$layout"
    fi
  fi
  zl_state_set serpantinum layout-created ""
  zl_state_set serpantinum layout ""
  zl_dim "  Se conservan tus notas y $ZL_SERP_CONFIG"
  serp_reload
}
