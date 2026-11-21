# Widgets do configurador. Respostas saem pelo descritor separado da tela.

ui_dialog_dir=''
ui_dialog_theme=''
ui_dialog_width=68
ui_dialog_report_height=18
ui_dialog_cancelled=''

ui_use_dialog() {
  [[ $1 == /* && -x $1 && $1 != *$'\n'* ]] || return 1
  DIALOGOPTS='' DIALOG_OK=0 DIALOG_ERROR=2 "$1" --version >/dev/null 2>&1 || return 1
  ui_dialog=$1
}

ui_dialog_open() {
  local rows columns
  ui_dialog_theme=$1
  [[ -r $ui_dialog_theme ]] || return 1
  read -r rows columns < <(stty size </dev/tty) || return 1
  [[ $rows =~ ^[0-9]+$ && $columns =~ ^[0-9]+$ ]] || return 1
  if (( rows == 0 )); then rows=24; fi
  if (( columns == 0 )); then columns=80; fi
  if (( rows < 12 || columns < 40 )); then
    ui_dialog_run --title 'Terminal pequeno' --ok-label 'Fechar' \
      --msgbox 'Use 40×12 ou --plain.' 7 0 && return 2
    return 1
  fi
  ui_dialog_width=$((columns - 4 < 68 ? columns - 4 : 68))
  ui_dialog_report_height=$((rows - 2 < 18 ? rows - 2 : 18))
  ui_dialog_dir=$(mktemp -d) || return 1
  exec {ui_dialog_stderr}>&2
  exec >"$ui_dialog_dir/log" 2>&1
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
  unset DIALOGOPTS DIALOG_TTY DIALOG_OK DIALOG_HELP DIALOG_ITEM_HELP DIALOG_TIMEOUT
  # O código 1 também pode vir do shell ou do ncurses antes de abrir o widget.
  export DIALOG_CANCEL=10 DIALOG_ESC=11 DIALOG_ERROR=2 DIALOG_EXTRA=3
  if [[ -n $ui_dialog_theme ]]; then export DIALOGRC=$ui_dialog_theme; fi
  "$ui_dialog" --backtitle 'Noir  /  NixOS' --no-shadow --output-fd 3 "$@" \
    3>&1 >/dev/tty </dev/tty || status=$?
  case $status in
    0|3|130|143) return "$status" ;;
    10|11) return 1 ;;
    *) return 2 ;;
  esac
)

ui_dialog_start() {
  local prompt='Escolha a operação.' revision=$1 limit=$((ui_dialog_width - 15)) selection
  if [[ -n $revision ]]; then
    if (( ${#revision} > limit )); then revision="${revision:0:limit}…"; fi
    prompt="Checkout: $revision"
  fi
  selection=$(ui_dialog_run --title 'Configuração do sistema' \
    --ok-label 'Continuar' --cancel-label 'Sair' --no-tags \
    --menu "$prompt" 0 "$ui_dialog_width" 1 install 'Instalar ou atualizar') || return "$?"
  [[ $selection == install ]] || return 2
}

ui_dialog_input() {
  ui_dialog_run --title -- "$ui_section_title" --ok-label 'Continuar' --cancel-label 'Cancelar' \
    --inputbox -- "$1" 0 "$ui_dialog_width" -- "$2"
}

ui_dialog_git_identity() {
  local field_width=$((ui_dialog_width - 13))
  ui_dialog_run --title 'Identidade Git' --ok-label 'Continuar' --cancel-label 'Cancelar' \
    --hline 'Tab: botões · Esc: sair' \
    --form 'Autoria dos commits (↑ ↓)' 0 "$ui_dialog_width" 2 \
    'Nome'   1 1 '' 1 9 "$field_width" 2048 \
    'E-mail' 2 1 '' 2 9 "$field_width" 2048
}

ui_dialog_choose() {
  local option index=0
  local -a items=()
  for option; do
    index=$((index + 1))
    items+=("$index" -- "$option")
  done
  ui_dialog_run --title -- "$ui_section_title" --ok-label 'Continuar' --cancel-label 'Cancelar' \
    --no-tags --menu 'Escolha o ambiente gráfico.' 0 "$ui_dialog_width" "$#" "${items[@]}"
}

ui_dialog_confirm() {
  ui_dialog_run --title -- "${ui_section_title:-Confirmar}" \
    --defaultno --yes-label 'Sim' --no-label 'Não' --yesno -- "$1" 7 "$ui_dialog_width"
}

ui_dialog_textbox() {
  local title=$1 file=$2 height
  shift 2
  height=$(wc -l < "$file") || return 2
  height=$((height + 4))
  if (( height < 7 )); then height=7; fi
  if (( height > ui_dialog_report_height )); then height=$ui_dialog_report_height; fi
  ui_dialog_run --title -- "$title" "$@" --textbox -- "$file" "$height" "$ui_dialog_width"
}

ui_dialog_review() (
  set -o pipefail
  local title=$1 report
  shift
  report=$(mktemp) || return 2
  trap 'rm -f -- "$report"' EXIT
  "$@" | fold -s -w "$((ui_dialog_width - 5))" > "$report" || return 2
  ui_dialog_textbox "$title" "$report" --exit-label 'Continuar'
)

ui_dialog_progress() {
  ui_dialog_run --title 'Em andamento' --infobox "$1"$'\n\nCtrl+C: interromper' 7 "$ui_dialog_width"
}

ui_dialog_password() {
  ui_dialog_run --title 'Autenticação administrativa' \
    --ok-label 'Autenticar' --cancel-label 'Cancelar' \
    --passwordbox 'Senha da sua conta Linux' 0 "$ui_dialog_width"
}

ui_dialog_finish() {
  local status=$1 title='Resultado' message='Operação concluída.' action=0
  if [[ -n $ui_dialog_cancelled ]]; then
    title='Operação cancelada'
    if (( status >= 128 )); then title='Operação interrompida'; fi
    message=$ui_dialog_cancelled
  elif (( status != 0 )); then
    title='Falha na operação'
    message="Código de saída: $status."
    if [[ -s $ui_dialog_dir/error ]]; then message+=$'\n'"$(<"$ui_dialog_dir/error")"; fi
  fi
  {
    printf '%s\n' "$message"
    if "$wizard_started"; then show_result; fi
  } | fold -s -w "$((ui_dialog_width - 5))" > "$ui_dialog_dir/result" || action=2
  while (( action == 0 )); do
    ui_dialog_textbox "$title" "$ui_dialog_dir/result" --ok-label 'Fechar' \
      --extra-button --extra-label 'Registros' --erase-on-exit || action=$?
    if (( action != 3 )); then break; fi
    action=0
    ui_dialog_textbox 'Registros da operação' "$ui_dialog_dir/log" --exit-label 'Voltar' || action=$?
    if (( action == 1 )); then action=0; fi
  done
  if (( action > 1 )); then
    printf 'Falha ao exibir os diagnósticos no Dialog. Código da operação: %s.\n' "$status" >&"$ui_dialog_stderr"
    cat -- "$ui_dialog_dir/result" "$ui_dialog_dir/log" >&"$ui_dialog_stderr" || :
  fi
  rm -rf -- "$ui_dialog_dir"
}
