# Interface do instalador. Entradas retornam pela saída padrão; avisos vão para stderr.

ui_gum=''
ui_foreground=255
ui_muted=249
ui_background=234
ui_accent=109

ui_interactive() {
  [[ -t 0 && -t 1 && -t 2 && ${TERM:-dumb} != dumb ]]
}

ui_use_gum() {
  [[ $1 == /* && -x $1 && $1 != *$'\n'* ]] || return 1
  "$1" --version >/dev/null 2>&1 || return 1
  ui_gum=$1
}

ui_header() {
  printf '\n'
  if [[ -n $ui_gum ]]; then
    "$ui_gum" style --foreground "$ui_foreground" --background "$ui_background" \
      --bold --padding '1 2' 'NIXOS CONFIG'
    "$ui_gum" style --foreground "$ui_accent" 'NOIR INSTALLATION WIZARD'
  else
    printf 'NIXOS CONFIG\nNOIR INSTALLATION WIZARD\n'
  fi
  printf 'Configuração do NixOS\n'
  if [[ -n $1 ]]; then printf 'Checkout: %s\n' "$1"; fi
  printf '\n'
}

ui_info() {
  printf '%s\n' "$*"
}

ui_message() {
  local color=$1 label=$2
  shift 2
  if [[ -n $ui_gum ]]; then
    "$ui_gum" style --foreground "$color" -- "$label $*" || printf '%s %s\n' "$label" "$*"
  else
    printf '%s %s\n' "$label" "$*"
  fi
}

ui_success() { ui_message 114 'OK' "$@"; }
ui_warning() { ui_message 221 'Aviso:' "$@" >&2; }
ui_error() { ui_message 203 'Erro:' "$@" >&2; }
ui_progress() { ui_message "$ui_accent" '›' "$@"; }

ui_input() {
  local label=$1 default=${2:-} answer
  if [[ -n $ui_gum ]]; then
    answer=$("$ui_gum" input --prompt "  $label: " --value "$default" --placeholder '' --char-limit 0 \
      --cursor.mode static --prompt.foreground "$ui_foreground" --cursor.foreground "$ui_accent") || return "$?"
    printf '  %s: %s\n' "$label" "${answer:-$default}" >&2
  else
    printf '  %s: ' "$label" >&2
    if [[ -t 0 && -n $default ]]; then printf '[%s] ' "$default" >&2; fi
    IFS= read -r answer || return 1
    if [[ ! -t 0 ]]; then printf '%s\n' "${answer:-$default}" >&2; fi
  fi
  printf '%s\n' "${answer:-$default}"
}

ui_choose() {
  local option answer index=0
  local -a options=()
  for option; do
    index=$((index + 1))
    options+=("$option|$index")
    if [[ -z $ui_gum ]]; then
      printf '  %s) %s\n' "$index" "$option" >&2
    fi
  done
  if [[ -n $ui_gum ]]; then
    answer=$("$ui_gum" choose --header '' --limit 1 --label-delimiter '|' \
      --cursor.foreground "$ui_accent" \
      --item.foreground "$ui_muted" --selected.foreground "$ui_foreground" \
      -- "${options[@]}" 'Cancelar|q') || return "$?"
  else
    printf '  Opção [1-%s, Enter: 1, q: cancelar]: ' "$index" >&2
    IFS= read -r answer || return 1
    answer=${answer:-1}
    if [[ ! -t 0 ]]; then printf '%s\n' "$answer" >&2; fi
  fi
  [[ $answer != [qQ] ]] || return 1
  printf '%s\n' "$answer"
}

ui_confirm() {
  local answer
  if [[ -n $ui_gum ]]; then
    "$ui_gum" confirm --default=false --affirmative Sim --negative Não \
      --prompt.foreground "$ui_foreground" --selected.foreground "$ui_foreground" \
      --selected.background 238 --unselected.foreground "$ui_muted" \
      --unselected.background "$ui_background" -- "$1"
  else
    printf '%s [s/N] ' "$1" >&2
    IFS= read -r answer || return 1
    if [[ ! -t 0 ]]; then printf '\n' >&2; fi
    [[ $answer == [sS] ]]
  fi
}

ui_run() {
  local title=$1
  shift
  if [[ -n $ui_gum ]]; then
    "$ui_gum" spin --title "$title" --spinner line --spinner.foreground "$ui_accent" \
      --title.foreground "$ui_foreground" --show-stderr -- "$@"
  else
    ui_progress "$title" >&2
    "$@"
  fi
}

ui_section() {
  printf '\n'
  if [[ -n $ui_gum ]]; then
    "$ui_gum" style --bold --foreground "$ui_accent" -- "$1" || printf '%s\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

ui_fields() {
  while (( $# )); do
    printf '  %s: %s\n' "$1" "$2"
    shift 2
  done
}

ui_outcome() {
  local text="$1 — $3"
  case $2 in
    ok) ui_message 114 '  [OK]' "$text" ;;
    warning) ui_message 221 '  [AVISO]' "$text" ;;
    error) ui_message 203 '  [FALHA]' "$text" ;;
    *) ui_message "$ui_muted" '  [—]' "$text" ;;
  esac
}
