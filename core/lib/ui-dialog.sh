# Widgets do configurador. Respostas saem pelo descritor separado da tela.

ui_dialog_dir=''
ui_dialog_theme=''
ui_dialog_width=68
ui_dialog_report_width=96
ui_dialog_report_height=18
ui_dialog_report_x=2
ui_dialog_heading='NOIR | NixOS Configuration'
ui_dialog_backtitle=$ui_dialog_heading
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
  ui_dialog_report_width=$((columns - 4 < 96 ? columns - 4 : 96))
  ui_dialog_report_height=$((rows - 3 < 24 ? rows - 3 : 24))
  ui_dialog_report_x=$(((columns - ui_dialog_report_width) / 2))
  if (( rows < 16 )); then ui_dialog_backtitle=''; fi
  ui_dialog_dir=$(mktemp -d) || return 1
  exec {ui_dialog_stderr}>&2
  exec >"$ui_dialog_dir/log" 2>&1
}

ui_dialog_run() (
  local status=0 argument escaped=false
  local -a header=()
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
  if [[ -n $ui_dialog_backtitle ]]; then header=(--backtitle "$ui_dialog_backtitle"); fi
  "$ui_dialog" "${header[@]}" --no-shadow --output-fd 3 "$@" \
    3>&1 >/dev/tty <"${ui_dialog_stdin:-/dev/tty}" || status=$?
  case $status in
    0|3|130|143) return "$status" ;;
    10|11) return 1 ;;
    *) return 2 ;;
  esac
)

ui_dialog_list() {
  local title=$1 prompt=$2 footer=$3
  shift 3
  local option item answer selection key index=0
  local -a items=()
  for option; do
    index=$((index + 1))
    # O Dialog centraliza pela largura do item mais longo.
    printf -v item '%-*s' "$((ui_dialog_width - 10))" "$index. $option"
    items+=("$index" -- "$item")
  done
  while :; do
    answer=$(ui_dialog_run --title -- "$title" --hline "$footer" \
      --ok-label 'Selecionar' --no-cancel --no-tags --no-hot-list --last-key \
      --menu -- "$prompt" 0 "$ui_dialog_width" "$#" "${items[@]}") || return "$?"
    read -r selection key <<< "$answer"
    # LEAVE retorna o item em foco e o código ASCII da tecla pressionada.
    case $key in
      49) selection=1 ;;
      50)
        if (( $# < 2 )); then continue; fi
        selection=2
        ;;
      51|52|53|54|55|56|57)
        selection=$((key - 48))
        if (( selection > $# )); then continue; fi
        ;;
    esac
    [[ $selection =~ ^[1-9][0-9]*$ ]] && (( selection <= $# )) || return 2
    printf '%s\n' "$selection"
    return
  done
}

ui_dialog_start() {
  local ui_dialog_backtitle=''
  local prompt='Checkout: indisponível' revision=$1 limit=$((ui_dialog_width - 15))
  shift
  local footer="↑↓ 1–$#/Enter  Esc Sair"
  if [[ -n $revision ]]; then
    if (( ${#revision} > limit )); then revision="${revision:0:limit}…"; fi
    prompt="Checkout: $revision"
  fi
  if (( ui_dialog_width >= 52 )); then footer="↑↓ Navegar  1–$# / Enter Selecionar  Esc Sair"; fi
  ui_dialog_list "$ui_dialog_heading" "$prompt" "$footer" "$@"
}

ui_dialog_input() {
  ui_dialog_run --title -- "$ui_section_title" --ok-label 'Continuar' --cancel-label 'Cancelar' \
    --hline 'Enter Continuar Esc Voltar' \
    --inputbox -- "$1" 0 "$ui_dialog_width" -- "$2"
}

ui_dialog_git_identity() {
  local field_width=$((ui_dialog_width - 15))
  ui_dialog_run --title 'Identidade Git' --ok-label 'Continuar' --cancel-label 'Cancelar' \
    --hline '↑↓ Campos Tab Enter/Esc' \
    --form 'Autoria dos commits' 0 "$ui_dialog_width" 2 \
    'Nome'   1 2 '' 1 10 "$field_width" 2048 \
    'E-mail' 2 2 '' 2 10 "$field_width" 2048
}

ui_dialog_choose() {
  local prompt=$1
  shift
  ui_dialog_list "$ui_section_title" "$prompt" "↑↓ 1–$#/Enter Esc Voltar" "$@"
}

ui_dialog_optionals() {
  ui_dialog_run --title 'Gerenciar opcionais' --separate-output \
    --ok-label 'Revisar' --cancel-label 'Cancelar' --no-tags \
    --checklist 'Use Espaço para alterar uma opção.' 0 "$ui_dialog_width" 3 "$@"
}

ui_dialog_confirm() {
  ui_dialog_run --title -- "${ui_section_title:-Confirmar}" \
    --hline '←→ Opção Enter Esc' \
    --defaultno --yes-label 'Sim' --no-label 'Não' --yesno -- "$1" 7 "$ui_dialog_width"
}

ui_dialog_textbox() {
  local ui_dialog_backtitle="NOIR | $1" file=$2 height
  shift 2
  height=$(wc -l < "$file") || return 2
  height=$((height + 4))
  if (( height < 7 )); then height=7; fi
  if (( height > ui_dialog_report_height )); then height=$ui_dialog_report_height; fi
  ui_dialog_run --begin 2 "$ui_dialog_report_x" --scrollbar "$@" \
    --textbox -- "$file" "$height" "$ui_dialog_report_width"
}

ui_dialog_review() (
  set -o pipefail
  local title=$1 report
  shift
  report=$(mktemp) || return 2
  trap 'rm -f -- "$report"' EXIT
  "$@" | fold -s -w "$((ui_dialog_report_width - 5))" > "$report" || return 2
  ui_dialog_textbox "$title" "$report" --exit-label 'Continuar' --hline '↑↓ Rolar Enter/Esc'
)

ui_dialog_progress() {
  ui_dialog_run --title 'Em andamento' --hline 'Ctrl+C Interromper' \
    --infobox -- "$1" 7 "$ui_dialog_width"
}

ui_dialog_switch_progress() {
  local ui_dialog_stdin=/dev/stdin
  ui_dialog_run --title 'Em andamento' --hline 'Ctrl+C Interromper' \
    --progressbox 'Aplicando configuração (switch)' 7 "$ui_dialog_width"
}

ui_dialog_password() {
  ui_dialog_run --title 'Autenticação administrativa' \
    --ok-label 'Autenticar' --cancel-label 'Cancelar' \
    --hline 'Enter Autenticar Esc Voltar' \
    --passwordbox 'Senha da sua conta Linux' 0 "$ui_dialog_width"
}

ui_dialog_result() {
  local status=$1 title='Resultado' message='Operação concluída.' action=0
  local diagnostics=${rebuild_log:-$ui_dialog_dir/log}
  if [[ -n $ui_dialog_cancelled ]]; then
    title='Operação cancelada'
    if (( status >= 128 )); then title='Operação interrompida'; fi
    message=$ui_dialog_cancelled
  elif (( status != 0 )); then
    title='Falha na operação'
    message="Código de saída: $status."
    if partial_publication "$status"; then
      title='Publicação parcial'
      message=$'Arquivos publicados. Uma etapa posterior falhou.\n'"$message"
    fi
    if [[ -s $ui_dialog_dir/error ]]; then message+=$'\n'"$(<"$ui_dialog_dir/error")"; fi
  fi
  {
    printf '%s\n' "$message"
    if "$wizard_started"; then show_result; fi
  } | fold -s -w "$((ui_dialog_report_width - 5))" > "$ui_dialog_dir/result" || action=2
  while (( action == 0 )); do
    ui_dialog_textbox "$title" "$ui_dialog_dir/result" --ok-label 'Continuar' \
      --extra-button --extra-label 'Registros' --hline '↑↓ Rolar Tab Enter/Esc' \
      --erase-on-exit || action=$?
    if (( action != 3 )); then break; fi
    action=0
    ui_dialog_textbox 'Registros da operação' "$diagnostics" --exit-label 'Voltar' \
      --hline '↑↓ Rolar ←→ Colunas Esc' || action=$?
    if (( action == 1 )); then action=0; fi
  done
  if (( action > 1 )); then
    printf 'Falha ao exibir os diagnósticos no Dialog. Código da operação: %s.\n' "$status" >&"$ui_dialog_stderr"
    cat -- "$ui_dialog_dir/result" "$diagnostics" >&"$ui_dialog_stderr" || :
  fi
}
