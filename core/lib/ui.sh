# Interface do instalador. Entradas retornam pela saída padrão; avisos vão para stderr.

ui_dialog=''
ui_section_title=''

ui_interactive() {
  [[ -t 0 && -t 1 && -t 2 && ${TERM:-dumb} != dumb ]]
}

ui_start() {
  local revision=$1
  shift
  if [[ -n $ui_dialog ]]; then
    ui_dialog_start "$revision" "$@"
  else
    printf '\nNoir · Configuração do NixOS\n' >&2
    if [[ -n $revision ]]; then printf 'Checkout: %s\n' "$revision" >&2; fi
    ui_choose 'Selecione uma opção.' "$@"
  fi
}

ui_review() {
  if [[ -n $ui_dialog ]]; then
    ui_dialog_review "$@"
  else
    shift
    "$@"
  fi
}

ui_info() { printf '%s\n' "$*"; }
ui_success() { printf 'OK %s\n' "$*"; }
ui_warning() { printf 'Aviso: %s\n' "$*" >&2; }

ui_error() {
  if [[ -n ${ui_dialog_dir:-} ]]; then printf '%s\n' "$*" > "$ui_dialog_dir/error"; fi
  printf 'Erro: %s\n' "$*" >&2
}

ui_progress() {
  printf '› %s\n' "$*"
  if [[ -n $ui_dialog ]]; then ui_dialog_progress "$*"; fi
}

ui_input() {
  local label=$1 default=${2:-} answer
  if [[ -n $ui_dialog ]]; then
    answer=$(ui_dialog_input "$label" "$default") || return "$?"
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
  local prompt=$1 option answer index=0
  shift
  if [[ -n $ui_dialog ]]; then
    ui_dialog_choose "$prompt" "$@"
    return "$?"
  fi
  for option; do
    index=$((index + 1))
    printf '  %s) %s\n' "$index" "$option" >&2
  done
  printf '  %s [1-%s, Enter: 1, q: voltar/sair] ' "$prompt" "$index" >&2
  IFS= read -r answer || return 1
  answer=${answer:-1}
  if [[ ! -t 0 ]]; then printf '%s\n' "$answer" >&2; fi
  [[ $answer != [qQ] ]] || return 1
  printf '%s\n' "$answer"
}

ui_confirm() {
  local answer
  if [[ -n $ui_dialog ]]; then
    ui_dialog_confirm "$1"
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
  ui_progress "$title" >&2 || return "$?"
  "$@"
}

ui_section() {
  ui_section_title=$1
  printf '\n%s\n' "$1"
}

ui_fields() {
  while (( $# )); do
    printf '  %s: %s\n' "$1" "$2"
    shift 2
  done
}

ui_outcome() {
  local label
  case $2 in
    ok) label=OK ;;
    warning) label=AVISO ;;
    error) label=FALHA ;;
    *) label=— ;;
  esac
  printf '  [%s] %s — %s\n' "$label" "$1" "$3"
}
