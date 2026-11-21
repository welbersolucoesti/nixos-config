# Widgets do configurador. Respostas saem pelo descritor separado da tela.

ui_use_dialog() {
  [[ $1 == /* && -x $1 && $1 != *$'\n'* ]] || return 1
  DIALOGOPTS='' DIALOG_OK=0 DIALOG_ERROR=2 "$1" --version >/dev/null 2>&1 || return 1
  ui_dialog=$1
}

ui_dialog_run() (
  local status=0 argument escaped=false
  # -- protege o próximo argumento, mas versões do Dialog examinam certas opções
  # antes de abrir o widget, inclusive quando aparecem como texto escapado.
  for argument; do
    if "$escaped"; then
      case $argument in
        --help|--version|--input-fd|--output-fd|--stdout|--stderr|--keep-tite) return 2 ;;
      esac
      escaped=false
    elif [[ $argument == -- ]]; then
      escaped=true
    fi
  done
  unset DIALOGOPTS DIALOG_TTY DIALOG_OK DIALOG_EXTRA DIALOG_HELP DIALOG_ITEM_HELP DIALOG_TIMEOUT
  # O código 1 também pode vir do shell ou do ncurses antes de abrir o widget.
  export DIALOG_CANCEL=10 DIALOG_ESC=11 DIALOG_ERROR=2
  "$ui_dialog" --backtitle 'NixOS Config' --output-fd 3 "$@" 3>&1 >/dev/tty </dev/tty || status=$?
  case $status in
    0|130|143) return "$status" ;;
    10|11) return 1 ;;
    *) return 2 ;;
  esac
)

ui_dialog_start() {
  local prompt='Configuração do NixOS' selection
  if [[ -n $1 ]]; then prompt+=$'\n'"Checkout: $1"; fi
  selection=$(ui_dialog_run --title 'Noir' --ok-label 'Selecionar' --cancel-label 'Sair' \
    --no-tags --menu "$prompt" 0 0 1 install 'Instalar ou atualizar') || return "$?"
  [[ $selection == install ]] || return 2
}

ui_dialog_input() {
  ui_dialog_run --title -- "$ui_section_title" --ok-label 'Continuar' --cancel-label 'Cancelar' \
    --inputbox -- "$1" 0 0 -- "$2"
}

ui_dialog_choose() {
  local option index=0
  local -a items=()
  for option; do
    index=$((index + 1))
    items+=("$index" -- "$option")
  done
  ui_dialog_run --title -- "$ui_section_title" --ok-label 'Selecionar' --cancel-label 'Cancelar' \
    --menu 'Escolha uma opção' 0 0 "$#" "${items[@]}"
}

ui_dialog_confirm() {
  ui_dialog_run --defaultno --yes-label 'Sim' --no-label 'Não' --yesno -- "$1" 0 0
}

ui_dialog_review() (
  local title=$1 report
  shift
  report=$(mktemp) || return 2
  trap 'rm -f -- "$report"' EXIT
  "$@" > "$report" || return 2
  ui_dialog_run --title -- "$title" --exit-label 'Continuar' --textbox -- "$report" -1 -1
)
