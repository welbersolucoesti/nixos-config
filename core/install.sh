#!/usr/bin/env bash
set -euo pipefail
umask 022
unset TAR_OPTIONS

default_destination=/etc/nixos/nixos-config
system_path=/run/current-system/sw/bin:/run/wrappers/bin
system_rebuild=/run/current-system/sw/bin/nixos-rebuild
prepared=''
new_local=''
new_choices=''
settings_result=''
wizard_started=false
git_result=(neutral 'Não consultado')
local_result=(neutral 'Não preparada')
publication_result=(neutral 'Não iniciada')
backup_result=(neutral 'Não criado')
identity_result=(neutral 'Não aplicada')
machine_result=()
published_destination=''
rebuild_operation=''
rebuild_log=''
rebuild_lock_fd=''
validation_result=(neutral 'Não iniciada')
activation_result=(neutral 'Não iniciada')

die() {
  if declare -F ui_error >/dev/null; then
    ui_error "$*"
  else
    printf 'Erro: %s\n' "$*" >&2
  fi
  exit 1
}

cancel() {
  local status=$1 message=${2:-Operação cancelada.}
  if (( status >= 128 )); then
    ui_dialog_cancelled='Operação interrompida.'
    ui_warning "Operação interrompida."
    exit "$status"
  fi
  if (( status == 2 )) && [[ -n ${ui_dialog:-} ]]; then
    die "Falha na interface Dialog ou na preparação da revisão. Execute novamente com --plain."
  fi
  ui_dialog_cancelled=$message
  ui_warning "$message"
  exit 0
}

fail_command() {
  local status=$1
  shift
  if (( status >= 128 )); then cancel "$status"; fi
  ui_error "$*"
  exit "$status"
}

partial_publication() {
  (( $1 != 0 && $1 < 128 )) && [[ -n $published_destination && -z ${ui_dialog_cancelled:-} ]]
}

show_result() {
  ui_section 'Resumo'
  if [[ -n $settings_result ]]; then
    ui_info "$settings_result"
    return
  fi
  if [[ -n $rebuild_operation ]]; then
    ui_outcome 'Validação (dry-build)' "${validation_result[@]}"
    if [[ $rebuild_operation == switch ]]; then
      ui_outcome 'Ativação (switch)' "${activation_result[@]}"
    fi
    if [[ -n $rebuild_log ]]; then ui_fields 'Registro' "$rebuild_log"; fi
    return
  fi
  ui_outcome 'Sincronização' "${git_result[@]}"
  ui_outcome 'Configuração local' "${local_result[@]}"
  if [[ -n $published_destination ]]; then
    ui_fields 'Arquivo local' "$published_destination/config/local.nix"
  fi
  ui_outcome 'Publicação' "${publication_result[@]}"
  ui_outcome 'Backup' "${backup_result[@]}"
  ui_outcome 'Identidade Git' "${identity_result[@]}"
  if [[ -n ${machine_result[0]:-} ]]; then
    ui_outcome 'Import do NixOS' "${machine_result[@]}"
  fi
}

finish() {
  local status=$1 report=${2:-true}
  if [[ -n ${ui_dialog_dir:-} ]]; then
    if "$report" && (( status != 0 )); then ui_dialog_result "$status"; fi
    rm -rf -- "$ui_dialog_dir"
  fi
  return "$status"
}

finish_operation() {
  local status=$1
  if (( status == 0 )) && [[ -n ${ui_dialog_cancelled:-} ]]; then status=1; fi
  if [[ -n $rebuild_lock_fd ]]; then exec {rebuild_lock_fd}<&-; fi
  if [[ -n $prepared ]]; then rm -rf -- "$prepared"; fi
  if [[ -n $new_local ]]; then rm -f -- "$new_local"; fi
  if [[ -n $new_choices ]]; then rm -f -- "$new_choices"; fi
  if [[ -n ${ui_dialog_dir:-} ]]; then
    ui_dialog_result "$status"
    rm -f -- "$ui_dialog_dir/error"
  elif "$wizard_started"; then
    if partial_publication "$status"; then
      ui_warning "Publicação parcial. Os arquivos foram publicados, mas uma etapa falhou (código $status)."
    fi
    show_result
  fi
  exit "$status"
}

run_operation() (
  # O chamador coleta o status. A operação mantém seu próprio errexit e limpeza.
  set -e
  trap 'finish_operation "$?"' EXIT
  trap 'cancel 130' INT
  trap 'cancel 143' TERM
  "$@"
)

prepare_ui() {
  local candidate status=0
  ui_interactive || return 0
  if candidate=$(type -P dialog) && candidate=$(realpath -e -- "$candidate") &&
     ui_use_dialog "$candidate"; then
    return
  fi
  command -v nix-shell >/dev/null ||
    die "Dialog e nix-shell indisponíveis. Execute com --plain para usar o modo texto."
  ui_progress 'Carregando Dialog'
  candidate=$(nix-shell -p dialog --run 'type -P dialog') || status=$?
  if (( status >= 128 )); then cancel "$status"; fi
  if (( status == 0 )) && ui_use_dialog "$candidate"; then return; fi
  die "Não foi possível carregar o Dialog pelo nix-shell. Execute com --plain para usar o modo texto."
}

check_requirements() {
  local cmd mv_help publication_path=$PATH
  local publication_tools=(cat chmod cmp cp diff find flock mkdir mktemp mv rm sha256sum sort stat tar)
  for cmd in git nix-instantiate grep id getent dirname realpath ln chmod "${publication_tools[@]}"; do
    command -v "$cmd" >/dev/null || die "Comando necessário ausente: $cmd."
  done
  grep -Eq '^ID=(nixos|"nixos")$' /etc/os-release || die "Este instalador requer NixOS."
  if [[ $destination == "$default_destination" ]]; then
    command -v sudo >/dev/null || die "A publicação protegida requer sudo."
    [[ -x /run/current-system/sw/bin/bash ]] || die "Bash do sistema indisponível para publicar."
    command -v sed >/dev/null || die 'Comando necessário ausente: sed.'
    for cmd in "${publication_tools[@]}" sed setfacl; do
      PATH=$system_path command -v "$cmd" >/dev/null ||
        die "Comando necessário no ambiente da publicação protegida: $cmd."
    done
    if [[ -n $ui_dialog ]]; then
      PATH=$system_path command -v setpriv >/dev/null ||
        die "Comando necessário na publicação pelo Dialog: setpriv."
    fi
    publication_path=$system_path
  fi
  mv_help=$(PATH=$publication_path mv --help) || die "Não foi possível consultar os recursos de mv."
  [[ $mv_help == *--exchange* && $mv_help == *--no-copy* ]] ||
    die "A publicação requer mv com suporte a --exchange e --no-copy."
  nix-instantiate --eval --strict --expr '(import <nixpkgs> {}).lib.version' >/dev/null ||
    die "Nixpkgs indisponível. Verifique o canal ou o NIX_PATH antes de instalar."
}

read_identity() {
  local account uid identity
  account=$(id -un)
  ui_section 'Conta Linux'
  username=$(ui_input 'Conta para esta configuração' "$account") || cancel "$?"
  username=${username:-$account}
  [[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Nome de conta Linux inválido."
  uid=$(id -u -- "$username") && [[ $uid != 0 ]] || die "Escolha uma conta Linux existente sem UID 0."

  ui_section 'Identidade Git'
  if [[ -n $ui_dialog ]]; then
    identity=$(ui_dialog_git_identity) || cancel "$?"
    # A primeira quebra separa os campos. As validações abaixo rejeitam campos vazios.
    git_name=${identity%%$'\n'*}
    git_email=''
    if [[ $identity == *$'\n'* ]]; then git_email=${identity#*$'\n'}; fi
  else
    git_name=$(ui_input 'Nome') || cancel "$?"
    git_email=$(ui_input 'E-mail') || cancel "$?"
  fi
  [[ $git_name =~ ^[^[:cntrl:]\<\>]*[^[:space:][:cntrl:]\<\>][^[:cntrl:]\<\>]*$ ]] ||
    die "Informe um nome para o Git sem caracteres de controle ou sinais de menor e maior."
  [[ $git_email =~ ^[^[:space:][:cntrl:]\<\>@]+@[^[:space:][:cntrl:]\<\>@]+$ ]] ||
    die "Informe um e-mail Git com um único @ e sem espaços."
}

show_remote_changes() {
  local base=$1 commit=$2
  shift 2
  ui_fields "$@"
  ui_info $'\nCommits no remoto'
  git --no-pager log --oneline "$base..$commit" || return
  ui_info $'\nArquivos modificados no remoto'
  git --no-pager diff --name-status "$base" "$commit"
}

sync_checkout() {
  local branch remote upstream status head base address count path
  local -a summary
  branch=$(git symbolic-ref --quiet --short HEAD) || die "Abra uma branch local antes de instalar."
  remote=$(git config --get "branch.$branch.remote") && [[ -n $remote && $remote != . ]] ||
    die "Configure uma branch remota correspondente para $branch."
  # Use o endereço do fetch sem informações de autenticação nem parâmetros.
  address=$(git remote get-url "$remote") || die "Não foi possível consultar o remoto $remote."
  address=${address%%[?#]*}
  if [[ $address =~ ^(https?://|ssh://|git://)([^/]+)(/.*)?$ ]]; then
    address="${BASH_REMATCH[1]}${BASH_REMATCH[2]##*@}${BASH_REMATCH[3]:-}"
  elif [[ $address =~ ^[^[:space:]@:]+@([^[:space:]:]+:.+)$ ]]; then
    address=${BASH_REMATCH[1]}
  elif [[ $address != /* ]]; then
    address=$remote
  fi
  git_result=(error 'Consulta interrompida ou com falha')
  ui_progress "Consultando $remote"
  git fetch --prune -- "$remote" || fail_command "$?" "Falha ao buscar atualizações de $remote."
  git_result=(warning 'Checkout mantido')
  upstream=$(git rev-parse --symbolic-full-name '@{upstream}') ||
    die "A branch remota de $branch não está disponível. Confira o upstream configurado."

  head=$(git rev-parse HEAD)
  source_commit=$(git rev-parse --verify "$upstream^{commit}") ||
    die "A branch remota de $branch não está disponível."
  status=$(git status --porcelain=v1 --untracked-files=all) || die "Falha ao consultar o checkout."
  count=$(git rev-list --count "$head..$source_commit")
  summary=('Branch' "$branch" 'Remoto' "$address (${upstream#refs/remotes/})"
    'Commit local' "$head" 'Commit remoto' "$source_commit" 'Commits disponíveis' "$count")
  base=$(git merge-base "$head" "$source_commit") || die "As branches não têm histórico em comum."
  if [[ -n ${ui_dialog:-} && -z $status && $head == "$base" && $source_commit != "$base" ]]; then
    ui_review 'Atualizações do remoto' show_remote_changes "$base" "$source_commit" "${summary[@]}" ||
      cancel "$?" 'Atualização do checkout cancelada.'
  else
    ui_fields "${summary[@]}"
    if [[ -n $status ]]; then
      ui_warning 'Alterações locais não commitadas'
      ui_info "$status"
    fi
    if [[ $source_commit != "$base" ]]; then
      show_remote_changes "$base" "$source_commit"
    fi
  fi
  if [[ $head != "$base" ]]; then
    ui_info $'\nCommits apenas locais'
    git --no-pager log --oneline "$base..$head"
    ui_info $'\nArquivos modificados nos commits locais'
    git --no-pager diff --name-status "$base" "$head"
  fi

  if [[ $head != "$base" ]]; then
    [[ $source_commit == "$base" ]] ||
      die "As branches divergiram e o fast-forward é impossível. Resolva a divergência no checkout."
    die "O checkout contém commits ainda ausentes no remoto. Sincronize a branch antes de instalar."
  fi
  for path in config/local.nix settings.json; do
    if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1 ||
       git cat-file -e "$source_commit:$path" 2>/dev/null; then
      die "$path deve ficar fora do controle de versão."
    fi
  done
  [[ -z $status ]] || die "Resolva as alterações locais antes de publicar ou aplicar o fast-forward."
  if [[ $head == "$source_commit" ]]; then
    git_result=(ok 'Já atualizado')
    ui_fields 'Arquivos modificados' 'Nenhum'
    return
  fi

  ui_info $'\nFast-forward do checkout local.'
  ui_confirm 'Aplicar atualização?' ||
    cancel "$?" 'Atualização do checkout cancelada.'
  status=$(git status --porcelain=v1 --untracked-files=all) || die "Falha ao consultar o checkout."
  [[ $(git symbolic-ref --quiet --short HEAD) == "$branch" && $(git rev-parse HEAD) == "$head" &&
     -z $status ]] ||
    die "O checkout mudou durante a confirmação. Execute novamente."
  # Identifique colisões com arquivos ignorados antes da tentativa de merge.
  git diff --name-only --diff-filter=A --no-renames -z "$head" "$source_commit" |
    while IFS= read -r -d '' path; do
      [[ ! -e $path && ! -L $path ]] || die "O fast-forward sobrescreveria arquivos locais em $path."
      while [[ $path == */* ]]; do
        path=${path%/*}
        if [[ -L $path || ( -e $path && ! -d $path ) ]]; then
          git ls-files --error-unmatch -- "$path" >/dev/null 2>&1 ||
            die "O fast-forward sobrescreveria arquivos locais em $path."
        fi
      done
    done
  # Use o objeto já obtido pelo fetch e aprovado pelo usuário.
  git_result=(error 'Fast-forward interrompido ou com falha')
  ui_progress 'Aplicando fast-forward'
  git merge --ff-only --no-autostash --no-overwrite-ignore -- "$source_commit" ||
    fail_command "$?" "O fast-forward falhou. Verifique o diagnóstico do Git e o estado do checkout."
  [[ $(git rev-parse HEAD) == "$source_commit" ]] || die "O checkout mudou durante o fast-forward."
  git_result=(ok 'Fast-forward concluído')
  ui_success 'Checkout atualizado'
}

nix_string() {
  local value=$1
  value=${value//\\/'\\'}
  value=${value//\"/'\"'}
  value=${value//\$\{/'\${'}
  printf '"%s"' "$value"
}

generate_local() {
  local model=$1 output=$2 line value
  local assignment='^([[:blank:]]*)(username|userName|userEmail)[[:blank:]]*='
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ $assignment ]]; then
      case ${BASH_REMATCH[2]} in
        username) value=$username ;;
        userName) value=$git_name ;;
        userEmail) value=$git_email ;;
      esac
      printf '%s%s = %s;\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$(nix_string "$value")"
    else
      printf '%s\n' "$line"
    fi
  done < "$model" > "$output"
}

validate_local() {
  local options=$1 file=$2
  shift 2
  # Avalia o módulo local com as declarações de personalConfig para conferir
  # tipos, campos obrigatórios e, na primeira instalação, a identidade coletada.
  # Os módulos e as asserções da máquina são avaliados no dry-build manual.
  nix-instantiate --eval --strict --json --argstr options "$options" --argstr file "$file" "$@" --expr '
    { options, file, username ? null, gitName ? null, gitEmail ? null }:
    let
      inherit (import <nixpkgs> { }) lib;
      evaluated = import <nixpkgs/nixos/lib/eval-config.nix> {
        modules = [
          (builtins.toPath options)
          (builtins.toPath file)
        ];
      };
      cfg = evaluated.config.personalConfig;
    in
    assert lib.assertMsg (cfg.username != null && cfg.git.userName != null && cfg.git.userEmail != null)
      "Preencha personalConfig.username, personalConfig.git.userName e personalConfig.git.userEmail.";
    assert lib.assertMsg (username == null || (
      cfg.username == username && cfg.git.userName == gitName && cfg.git.userEmail == gitEmail
    )) "A identidade do arquivo difere da informada. Confira username, git.userName e git.userEmail.";
    builtins.deepSeq cfg cfg.username
  ' || fail_command "$?" "Revise $file conforme config/local.example.nix e execute novamente."
}

settings_eval() {
  local tree=$1 file=$2
  shift 2
  nix-instantiate --eval --strict --json "$tree/core/config/edit-settings.nix" \
    --argstr root "$tree" --argstr file "$file" "$@"
}

evaluate_codex_package() {
  nix-instantiate --eval --strict --argstr package "$1" --expr '
    { package }:
    let
      pkgs = import <nixpkgs> { };
      codex = import (builtins.toPath package) { inherit pkgs; };
    in
    builtins.seq codex.drvPath codex.version
  ' >/dev/null || fail_command "$?" 'Falha ao avaliar o pacote Codex CLI.'
}

validate_settings() {
  local tree=$1 file=$2 states
  states=$(settings_eval "$tree" "$file" --argstr attr states) ||
    fail_command "$?" "Revise as preferências em $file."
  if [[ $states == *' on"' ]]; then
    evaluate_codex_package "$tree/core/optional/codex-package.nix"
  fi
}

# O identificador detecta substituições, alterações de conteúdo e permissões.
file_revision() {
  local file=$1 metadata digest
  check_regular_file "$file"
  if [[ ! -e $file ]]; then
    printf 'absent\n'
    return
  fi
  metadata=$(TZ=UTC0 stat -c '%d:%i:%u:%g:%a:%s:%y|%z' -- "$file") || return
  digest=$(file_digest "$file") || return
  printf '%s|%s\n' "$digest" "$metadata"
}

file_digest() {
  local digest
  digest=$(sha256sum < "$1") || return
  printf '%s\n' "${digest%% *}"
}

require_revision() {
  local current
  current=$(file_revision "$1") && [[ $current == "$2" ]] ||
    die "O arquivo $1 mudou durante a operação. Confira o conteúdo e execute novamente."
}

check_regular_file() {
  if [[ -e $1 || -L $1 ]]; then
    [[ -f $1 && ! -L $1 && -r $1 ]] || die "Use um arquivo regular e legível em $1."
  fi
}

require_searchable_directory() {
  local path=$1
  [[ -d $path ]] || die "Diretório ausente ou inválido: $path."
  [[ -x $path ]] || die "UID $EUID sem permissão de atravessar o diretório $path."
}

require_readable_file() {
  local path=$1
  [[ -e $path ]] || die "Arquivo ausente ou destino do link inacessível: $path."
  [[ -f $path ]] || die "Esperado um arquivo regular em $path."
  [[ -r $path ]] || die "UID $EUID sem permissão de leitura em $path."
}

show_file_diff() {
  local label=$1 old=$2 new=$3 status=0
  diff -u --label "$label (anterior)" --label "$label (proposto)" -- "$old" "$new" || status=$?
  (( status <= 1 ))
}

insert_noir_import() {
  sed -zE '
    :again
    s@(^|\n)([[:blank:]]*imports[[:blank:]]*=[[:blank:]]*\n[[:blank:]]*\[ # Include the results of the hardware scan\.[[:blank:]]*\n)([[:blank:]]*)(\./hardware-configuration\.nix[[:blank:]]*)(\n[[:blank:]]*\];[[:blank:]]*)(\n|$)@\1\2\3\4\n\3./nixos-config/noir.nix\5\6@g
    t again
  ' -- "$1"
}

machine_imports() {
  # Consulte somente imports, sem carregar os módulos referenciados pelo bloco convencional.
  nix-instantiate --eval --strict --argstr file "$1" --expr '
    { file }:
    let
      source = import (builtins.toPath file);
      module = if builtins.isFunction source then
        source (builtins.mapAttrs (_: _: null) (builtins.functionArgs source))
        else source;
      dir = dirOf file;
      hardware = dir + "/hardware-configuration.nix";
      noir = dir + "/nixos-config/noir.nix";
      paths = map (item: if builtins.isPath item then toString item else null)
        (module.imports or []);
      count = entry: builtins.length (builtins.filter (path: path == entry) paths);
    in
    if paths == [ hardware noir ] then "integrated"
    else if paths == [ hardware ] then "conventional"
    else if builtins.any (entry: entry != null && count entry > 1) paths then "duplicate"
    else if paths == [] then "missing"
    else "conflict"
  '
}

machine_blocks() {
  # Reconhece as linhas do modelo. O Nix verifica separadamente os imports ativos.
  local -a lines=()
  local i hardware indent state
  local assignment='^[[:blank:]]*imports[[:blank:]]*=[[:blank:]]*$'
  local comment='^[[:blank:]]*\[ # Include the results of the hardware scan\.[[:blank:]]*$'
  local hardware_path='^([[:blank:]]*)\./hardware-configuration\.nix[[:blank:]]*$'
  local noir_path='^[[:blank:]]*\./nixos-config/noir\.nix[[:blank:]]*$'
  local closing='^[[:blank:]]*\];[[:blank:]]*$'
  mapfile -t lines < "$1" || return
  for ((i=3; i<${#lines[@]}; i++)); do
    [[ ${lines[i]} =~ $closing ]] || continue
    hardware=$((i-1)) state=conventional
    if [[ ${lines[hardware]} =~ $noir_path ]]; then
      hardware=$((hardware-1)) state=integrated
    fi
    [[ $hardware -ge 2 && ${lines[hardware-2]} =~ $assignment &&
       ${lines[hardware-1]} =~ $comment && ${lines[hardware]} =~ $hardware_path ]] || continue
    indent=${BASH_REMATCH[1]}
    [[ $state == conventional || ${lines[i-1]} == "$indent./nixos-config/noir.nix"* ]] || continue
    printf '%s:%s:%s\n' "$state" "$((i+1))" "$indent"
  done
}

prepare_machine_import() {
  local machine=$1 original=$prepared/configuration.nix proposed=$prepared/proposed.nix
  local revision imports block state line indent changes status=0
  [[ -e $machine || -L $machine ]] || die "Arquivo ausente: $machine."
  [[ -f $machine && ! -L $machine && -r $machine ]] ||
    die "Arquivo inválido ou ilegível: $machine. Use um arquivo regular."
  revision=$(file_revision "$machine")
  cp -- "$machine" "$original" || die "Falha ao copiar $machine para revisão."
  require_revision "$machine" "$revision"
  nix-instantiate --parse "$original" >/dev/null || die "Sintaxe Nix inválida em $machine."
  imports=$(machine_imports "$original") || die "Não foi possível avaliar imports em $machine."
  block=$(machine_blocks "$original") || die "Não foi possível conferir o bloco de imports em $machine."
  [[ $block != *$'\n'* ]] ||
    die "Correspondências ambíguas em $machine. Mantenha um único bloco convencional."
  case $imports in
    '"duplicate"') die "Import duplicado em $machine. Corrija o bloco antes de publicar." ;;
    '"conflict"') die "Imports adicionais ou conflitantes em $machine. Corrija o bloco antes de publicar." ;;
  esac
  IFS=: read -r state line indent <<< "$block"
  [[ -n $state && $imports == \""$state"\" ]] ||
    die "Bloco de imports modificado ou não reconhecido em $machine."
  machine_revision=$revision
  if [[ $state == integrated ]]; then
    machine_result=(ok 'Import já presente')
    return
  fi
  insert_noir_import "$original" > "$proposed" || die 'Falha na transformação do configuration.nix com sed.'
  changes=$(diff --unchanged-line-format='' --old-line-format='remoção' \
    --new-line-format='%dn:%L' -- "$original" "$proposed") || status=$?
  [[ $status == 1 && $changes == "$line:$indent./nixos-config/noir.nix" ]] &&
    nix-instantiate --parse "$proposed" >/dev/null &&
    [[ $(machine_imports "$proposed") == '"integrated"' ]] ||
    die 'Resultado inesperado da transformação do configuration.nix.'
  ui_review 'Revisar import do NixOS' show_file_diff "$machine" "$original" "$proposed" ||
    cancel "$?" 'Publicação cancelada.'
  machine_digest=$(file_digest "$proposed")
  machine_result=(neutral 'Inclusão revisada')
}

choose_desktop() {
  local selection
  selection=$(ui_choose 'Selecione o desktop.' 'KDE Plasma' 'GNOME' 'Cinnamon' 'XFCE' 'Definido pela máquina') ||
    return "$?"
  case $selection in
    1) printf 'kde\n' ;;
    2) printf 'gnome\n' ;;
    3) printf 'cinnamon\n' ;;
    4) printf 'xfce\n' ;;
    5) printf 'null\n' ;;
    *) die 'Desktop inválido.' ;;
  esac
}

manage_settings() {
  local checkout=$1 destination=$2 selection field value states source source_revision choices_revision checkout_lock original
  local choices=$checkout/settings.json
  local -a optionals=()
  local -a names=('CRON' 'Virtualização' 'Codex CLI') items=() enabled=(false false false)
  local index tag
  wizard_started=true
  ui_section_title='Editar preferências'
  exec {checkout_lock}< "$checkout"
  flock -n -x "$checkout_lock" || die 'Outra edição ou publicação está em andamento neste checkout.'
  choices_revision=$(file_revision "$choices")
  source=$choices
  if [[ $choices_revision == absent ]]; then
    source=$(realpath -ms -- "$destination")/settings.json
  fi
  source_revision=$(file_revision "$source")
  prepared=$(mktemp -d)
  if [[ $source_revision == absent ]]; then
    printf '{}\n' > "$prepared/settings.json"
  else
    cp -- "$source" "$prepared/settings.json"
    require_revision "$source" "$source_revision"
  fi
  states=$(settings_eval "$checkout" "$prepared/settings.json" --argstr attr states) ||
    fail_command "$?" 'Corrija settings.json antes de editar no Noir.'
  ui_review 'Preferências atuais em settings.json' cat -- "$prepared/settings.json" ||
    cancel "$?" 'Edição das preferências cancelada.'
  selection=$(ui_choose 'Qual preferência deseja editar?' 'Desktop' 'Wallpaper' 'Opcionais' 'Tema Zsh') ||
    cancel "$?" 'Edição das preferências cancelada.'
  case $selection in
    1)
      field=desktop
      value=$(choose_desktop) ||
        cancel "$?" 'Edição das preferências cancelada.'
      ;;
    2)
      field=wallpaper
      value=$(ui_input 'Nome do arquivo em core/wallpapers (vazio para o padrão)') ||
        cancel "$?" 'Edição das preferências cancelada.'
      ;;
    3)
      field=optionals
      read -r -a optionals <<< "${states:1:-1}"
      for index in "${!names[@]}"; do
        items+=("$((index + 1))" "${names[index]}" "${optionals[index]}")
      done
      selection=$(ui_dialog_optionals "${items[@]}") || cancel "$?" 'Edição das preferências cancelada.'
      for tag in $selection; do
        [[ $tag =~ ^[1-3]$ ]] || die 'Seleção de opcionais inválida.'
        enabled[tag - 1]=true
      done
      printf -v value '{"cron":%s,"virtualization":%s,"codex":%s}' "${enabled[@]}"
      ;;
    4)
      field=theme
      value=$(ui_input 'Nome do tema Zsh (vazio para desativar)') ||
        cancel "$?" 'Edição das preferências cancelada.'
      ;;
    *) die 'Preferência inválida.' ;;
  esac

  new_choices=$(mktemp -- "$checkout/.settings.XXXXXXXX")
  settings_eval "$checkout" "$prepared/settings.json" --argstr field "$field" --argstr value "$value" \
    > "$new_choices" || fail_command "$?" 'Falha ao preparar as preferências.'
  original=$(settings_eval "$checkout" "$prepared/settings.json" --argstr attr choices)
  if [[ $(<"$new_choices") == "$original" ]]; then
    settings_result='Nenhuma preferência foi alterada.'
    return
  fi
  printf '\n' >> "$new_choices"
  validate_settings "$checkout" "$new_choices"
  ui_review 'Revisar settings.json' show_file_diff settings.json "$prepared/settings.json" "$new_choices" ||
    cancel "$?" 'Edição das preferências cancelada.'
  ui_confirm 'Salvar as preferências para a próxima publicação?' ||
    cancel "$?" 'Edição das preferências cancelada.'
  if [[ $source != "$choices" ]]; then require_revision "$source" "$source_revision"; fi
  if [[ $choices_revision == absent ]]; then
    ln -T -- "$new_choices" "$choices" || die 'settings.json apareceu durante a edição.'
    rm -- "$new_choices"
  else
    chmod --reference="$choices" -- "$new_choices"
    require_revision "$choices" "$choices_revision"
    mv -fT -- "$new_choices" "$choices" || die 'Falha ao salvar settings.json.'
  fi
  new_choices=''
  settings_result='Preferências salvas. Use Instalar ou atualizar para publicá-las.'
}

publication_revision() {
  local path=$1 inode revision
  local -a member
  if [[ ! -e $path && ! -L $path ]]; then
    printf 'absent\n'
    return
  fi
  [[ ! -L $path ]] || return 1
  inode=$(stat -c '%d:%i' -- "$path") || return
  if [[ -d $path ]]; then
    member=(-C "$path" .)
  elif [[ -f $path ]]; then
    member=(--transform='s|^.*$|configuration.nix|' -C "${path%/*}" -- "${path##*/}")
  else
    return 1
  fi
  # O nome e os tempos de acesso e troca não fazem parte do conteúdo a restaurar.
  revision=$(LC_ALL=C tar --sort=name --format=pax --numeric-owner --acls --xattrs \
    --pax-option=exthdr.name=NoirPaxHeader,delete=atime,delete=ctime \
    -cf - "${member[@]}" | sha256sum) || return
  printf '%s|%s\n' "$inode" "${revision%% *}"
}

move_publication() {
  local from=$1 to=$2 from_before=$3 to_before=$4 description=$5 index
  local from_after to_after
  [[ $(publication_revision "$from") == "$from_before" &&
     $(publication_revision "$to") == "$to_before" ]] ||
    die "Alteração concorrente durante $description. Confira $from e $to."

  # Registre antes do mv para que uma interrupção após a troca também possa ser revertida.
  index=${#move_from[@]}
  move_from+=("$from")
  move_to+=("$to")
  saved_from+=("$from_before")
  saved_to+=("$to_before")
  if [[ $to_before == absent ]]; then
    mv -Tn --no-copy -- "$from" "$to" || die "Falha durante $description."
  else
    mv -T --exchange --no-copy -- "$from" "$to" || die "Falha durante $description."
  fi
  from_after=$(publication_revision "$from") || die "Falha ao conferir $from após $description."
  to_after=$(publication_revision "$to") || die "Falha ao conferir $to após $description."
  if [[ $to_before != absent && $from_after != absent && $to_after == "$from_before" ]]; then
    # Se o original recebeu uma edição durante a troca, devolva a versão que foi deslocada.
    saved_to[index]=$from_after
  fi
  [[ $from_after == "$to_before" && $to_after == "$from_before" ]] ||
    die "Alteração concorrente detectada após $description. Confira $from e $to."
}

finish_publication() {
  local status=$1 index from to from_now to_now restored=true changed=false
  trap '' HUP INT TERM
  if (( status != 0 && ${#move_from[@]} > 0 )); then
    for ((index=${#move_from[@]}-1; index>=0; index--)); do
      from=${move_from[index]} to=${move_to[index]}
      from_now=$(publication_revision "$from") || from_now=unavailable
      to_now=$(publication_revision "$to") || to_now=unavailable
      if [[ $from_now == "${saved_from[index]}" &&
            ${to_now%%|*} != "${saved_from[index]%%|*}" ]]; then
        continue
      fi
      if [[ $from_now != "${saved_to[index]}" || $to_now != "${saved_from[index]}" ]]; then
        printf 'Reversão bloqueada por estado divergente em %s ou %s.\n' "$from" "$to" >&2
        restored=false
        # As etapas anteriores podem sustentar o estado que não pôde ser desfeito.
        break
      fi
      changed=true
      if [[ $from_now == absent ]]; then
        mv -Tn --no-copy -- "$to" "$from" || restored=false
      else
        mv -T --exchange --no-copy -- "$to" "$from" || restored=false
      fi
      if ! "$restored" ||
         [[ $(publication_revision "$from") != "${saved_from[index]}" ||
            $(publication_revision "$to") != "${saved_to[index]}" ]]; then
        printf 'Falha ao restaurar %s e %s.\n' "$from" "$to" >&2
        restored=false
        break
      fi
    done
    if "$restored"; then
      if "$changed"; then printf 'Publicação revertida. A operação não foi concluída.\n' >&2; fi
    else
      printf 'Reversão incompleta. Originais e cópias disponíveis foram preservados.\n' >&2
      printf 'Área de recuperação: %s\nImplantação: %s\nBackup da implantação: %s\n' \
        "$stage" "$target" "$previous" >&2
      if [[ -n $machine ]]; then
        printf 'Configuração: %s\n' "$machine" >&2
        if [[ -n $machine_backup ]]; then printf 'Backup da configuração: %s\n' "$machine_backup" >&2; fi
      fi
      exit 75
    fi
  fi
  rm -rf -- "$stage" || printf 'Confira a área temporária %s.\n' "$stage" >&2
  exit "$status"
}

publish() (
  set -euo pipefail
  umask 022
  unset TAR_OPTIONS
  local target=$1 expected=$2 expected_settings=$3 parent stage tree
  local expected_machine=${4:-} reviewed_digest=${5:-} machine='' candidate='' machine_backup=''
  local deploy=true target_before previous_before=absent machine_before candidate_before tree_before
  local -a move_from=() move_to=() saved_from=() saved_to=()
  local previous="$1.previous"
  local archive archive_size end_block end_offset trailer_size
  local tar_end='^block ([0-9]+): \*\* Block of NULs \*\*$'
  parent=${target%/*}

  [[ -d $parent && ! -L $parent ]] || die "Diretório pai de publicação inválido: $parent."
  if (( EUID == 0 )); then
    [[ $target == /etc/nixos/nixos-config && -O $parent &&
       -z $(find "$parent" -maxdepth 0 -perm /022 -print) ]] ||
      die "O destino protegido exige /etc/nixos sob controle de root."
    [[ ${SUDO_UID:-} =~ ^[1-9][0-9]*$ ]] ||
      die "UID da conta que solicitou a publicação protegida indisponível."
  fi

  exec 9< "$parent"
  flock -x 9 || die "Não foi possível bloquear $parent para publicação."
  if [[ $target == "$default_destination" ]]; then
    [[ -n $expected_machine && $expected_machine != absent ]] ||
      die 'A publicação oficial exige a validação do configuration.nix.'
    machine=$parent/configuration.nix
    require_revision "$machine" "$expected_machine"
    machine_before=$(publication_revision "$machine")
  elif [[ -n $expected_machine || -n $reviewed_digest ]]; then
    die 'Integração disponível somente no destino oficial.'
  fi
  if [[ $expected == absent ]]; then
    [[ ! -e $target && ! -L $target ]] || die "O destino foi criado durante a preparação. Execute novamente."
  else
    [[ -d $target && ! -L $target && -O $target && -d $target/config && ! -L $target/config &&
       -f $target/config/local.nix && ! -L $target/config/local.nix &&
       $(stat -c '%d:%i' -- "$target") == "$expected" ]] ||
      die "O destino mudou durante a preparação. Execute novamente."
    if (( EUID == 0 )); then
      [[ -z $(find "$target" "$target/config" "$target/config/local.nix" -maxdepth 0 \
        \( ! -user root -o -perm /022 \) -print) ]] ||
        die "A implantação e a configuração local devem pertencer a root, com escrita restrita ao proprietário."
    fi
  fi

  if [[ $expected != absent ]]; then
    require_revision "$target/settings.json" "$expected_settings"
    if (( EUID == 0 )) && [[ $expected_settings != absent ]]; then
      [[ -z $(find "$target/settings.json" -maxdepth 0 \
        \( ! -user root -o -perm /022 \) -print) ]] ||
        die 'O settings.json publicado deve pertencer a root, com escrita restrita ao proprietário.'
    fi
  fi
  target_before=$(publication_revision "$target")
  [[ ${target_before%%|*} == "$expected" ]] ||
    die "O destino $target mudou durante a preparação."

  stage=$(mktemp -d -- "$parent/.nixos-config.XXXXXXXX") || die "Falha ao criar a área de publicação."
  tree=$stage/tree
  trap 'finish_publication "$?"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  archive=$stage/deployment.tar
  cat > "$archive" || die "Falha ao receber o TAR de implantação."
  mkdir -- "$tree"
  if ! end_block=$(LC_ALL=C tar --extract --block-number --warning=none --warning=missing-zero-blocks \
      --warning=alone-zero-block --file="$archive" --directory="$tree" \
      --no-same-owner --no-same-permissions 2> "$stage/tar.log") || [[ -s $stage/tar.log ]]; then
    cat -- "$stage/tar.log" >&2
    die "Falha ao receber a árvore preparada."
  fi
  # O GNU tar pode aceitar EOF entre membros e ignorar dados após o primeiro fim.
  [[ $end_block =~ $tar_end ]] || die "Fim do TAR de implantação inválido."
  end_offset=$((BASH_REMATCH[1] * 512))
  archive_size=$(stat -c %s -- "$archive") || die "Falha ao conferir o tamanho do TAR de implantação."
  trailer_size=$((archive_size - end_offset))
  (( trailer_size >= 1024 && archive_size % 512 == 0 )) &&
    cmp -s -n "$trailer_size" -- "$archive" /dev/zero "$end_offset" ||
    die "Fim do TAR de implantação inválido."
  [[ -z $(find "$tree" ! -type d ! -type f -print -quit) &&
     -f $tree/noir.nix && -f $tree/core/config/options.nix && -f $tree/config/local.nix &&
     -f $tree/settings.json && -f $tree/applications.nix && ! -e $tree/.git ]] || die "Árvore de publicação inválida."
  chmod -R go-w -- "$tree"

  if [[ -n $reviewed_digest ]]; then
    [[ -n $machine && -O $machine && -z $(find "$machine" -maxdepth 0 -perm /022 -print) ]] ||
      die 'O configuration.nix deve pertencer ao proprietário da publicação e ter escrita restrita.'
    require_revision "$machine" "$expected_machine"
    candidate=$stage/configuration.nix
    machine_backup=$machine.noir.${stage##*.}.previous
    cp --preserve=all -- "$machine" "$candidate"
    insert_noir_import "$machine" > "$candidate" || die 'Falha na transformação do configuration.nix com sed.'
    [[ $(file_digest "$candidate") == "$reviewed_digest" ]] ||
      die 'O configuration.nix proposto difere do arquivo revisado.'
    candidate_before=$(publication_revision "$candidate")
  fi

  if [[ $expected == absent ]]; then
    if (( EUID == 0 )); then
      # O dry-build lê o módulo na conta que chamou o sudo.
      setfacl --set "u::rw-,u:$SUDO_UID:r--,g::---,o::---" -- "$tree/config/local.nix" ||
        die "Falha ao conceder leitura de config/local.nix ao UID $SUDO_UID por ACL."
    fi
  else
    cmp -s -- "$target/config/local.nix" "$tree/config/local.nix" ||
      die "A configuração local mudou durante a preparação. Execute novamente."
    cp -p -- "$target/config/local.nix" "$tree/config/local.nix" ||
      die "Falha ao preservar as permissões da configuração local."
    if diff -qr --no-dereference -- "$tree" "$target" >/dev/null &&
       cmp -s <(find "$tree" -type f -printf '%P %m\0' | sort -z) \
         <(find "$target" -type f -printf '%P %m\0' | sort -z); then
      printf 'A cópia implantada já contém os mesmos arquivos.\n'
      deploy=false
    elif [[ -e $previous || -L $previous ]]; then
      [[ -d $previous && ! -L $previous && -O $previous ]] ||
        die "O caminho de backup $previous está ocupado. Verifique-o antes de continuar."
      previous_before=$(publication_revision "$previous")
    fi
    require_revision "$target/settings.json" "$expected_settings"
  fi
  if [[ -n $machine ]]; then require_revision "$machine" "$expected_machine"; fi
  if "$deploy"; then
    tree_before=$(publication_revision "$tree")
    move_publication "$tree" "$target" "$tree_before" "$target_before" 'a publicação da implantação'
  fi

  if [[ -n $candidate ]]; then
    require_revision "$machine" "$expected_machine"
    move_publication "$candidate" "$machine" "$candidate_before" "$machine_before" 'a integração do configuration.nix'
  fi
  if "$deploy" && [[ $expected != absent ]]; then
    move_publication "$tree" "$previous" "$target_before" "$previous_before" 'a consolidação do backup da implantação'
  fi
  if [[ -n $candidate ]]; then
    move_publication "$candidate" "$machine_backup" "$machine_before" absent 'a consolidação do backup do configuration.nix'
    [[ $(publication_revision "$machine") == "$candidate_before" &&
       $(publication_revision "$machine_backup") == "$machine_before" ]] ||
      die 'O configuration.nix ou seu backup mudou durante a publicação.'
  elif [[ -n $machine ]]; then
    require_revision "$machine" "$expected_machine"
  fi
  if "$deploy"; then
    [[ $(publication_revision "$target") == "$tree_before" ]] ||
      die 'A implantação mudou durante a publicação.'
  fi
  if "$deploy" && [[ $expected != absent ]]; then
    [[ $(publication_revision "$previous") == "$target_before" ]] ||
      die 'O backup da implantação mudou durante a publicação.'
  fi
  if [[ -n $candidate ]]; then printf 'configuration.nix original preservado em %s.\n' "$machine_backup"; fi
  if "$deploy" && [[ $expected != absent ]]; then
    printf 'Cópia anterior para recuperação: %s\n' "$previous"
  fi
)

start_switch_progress() {
  # A substituição é criada antes de o relay abrir a ponta de escrita.
  exec {progress_fd}> >(ui_dialog_switch_progress >/dev/null) || return "$?"
  progress_pid=$!
}

stop_switch_progress() {
  exec {progress_fd}>&-
  wait "$progress_pid" || :
  progress_pid=''
}

relay_sudo_dialog() {
  local prompt=$1 started=$2 mode=$3 line result=0 pending=true
  local progress_fd progress_pid='' relay_status
  set +x +a
  # Executado no coproc. Enquanto a ponta de escrita está aberta, o relay
  # usa só builtins. Feche-a também antes de criar o subprocesso da senha.
  if [[ $mode == on-demand ]]; then
    trap '
      relay_status=$?
      if [[ -n $progress_pid ]]; then stop_switch_progress; fi
      exit "$relay_status"
    ' EXIT
    # Deixe printf devolver o erro do pipe para que o EXIT faça a limpeza.
    trap ':' PIPE
    trap 'exit 143' TERM
    start_switch_progress || exit "$?"
  fi
  while IFS= read -r line || [[ -n $line ]]; do
    case $line in
      "$prompt")
        if "$pending"; then
          if [[ $mode == on-demand ]]; then
            stop_switch_progress
            local +x password
            password=$(ui_dialog_password) || result=$?
            if (( result == 1 )); then result=125; fi
          fi
          if (( result == 0 )); then printf '%s\n' "$password" || exit "$?"; fi
          pending=false
          exec 1>&-
          unset -v password
          if [[ $mode == on-demand ]] && (( result == 0 )); then start_switch_progress || exit "$?"; fi
        fi
        ;;
      "$started")
        if [[ -z $started ]]; then
          printf '\n' >&2 || exit "$?"
        elif "$pending"; then
          pending=false
          exec 1>&-
          unset -v password
        fi
        ;;
      *) printf '%s\n' "$line" >&2 || exit "$?" ;;
    esac
  done
  exit "$result"
}

sudo_dialog() (
  local mode=$1 started=$2
  shift 2
  local relay='' input='' diagnostics='' status relay_status
  local prompt="Noir autenticação $BASHPID-$RANDOM"

  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap '
    status=$?
    # Feche as duas pontas do sudo antes de esperar o auxiliar.
    if [[ -n $diagnostics ]]; then exec {diagnostics}>&-; fi
    if [[ -n $input ]]; then exec {input}<&-; fi
    if [[ -n $relay ]]; then
      wait "$relay" || {
        relay_status=$?
        if (( relay_status != 125 )); then
          (printf "Falha no auxiliar de autenticação (código %s).\n" "$relay_status" >&2) || :
        fi
        if (( status == 0 || (status == 1 && relay_status == 125) )); then status=$relay_status; fi
      }
    fi
    exit "$status"
  ' EXIT

  coproc NOIR_RELAY { relay_sudo_dialog "$prompt" "$started" "$mode"; } || return 1
  relay=$! input=${NOIR_RELAY[0]:-} diagnostics=${NOIR_RELAY[1]:-}
  [[ -n $input && -n $diagnostics ]] || return 1

  # O sudo permanece em primeiro plano para receber a interrupção do terminal.
  sudo -k -S -p $'\n'"$prompt"$'\n' -- "$@" <&"$input" 2>&"$diagnostics"
)

publish_dialog() {
  local archive=$1 root_script=$2 target=$3 expected=$4 expected_settings=$5
  local expected_machine=$6 reviewed_digest=$7
  local started="Noir publicação ${prepared##*/}"
  if [[ $archive != /* ]]; then archive=$PWD/$archive; fi
  [[ -f $archive && -r $archive ]] || {
    printf 'TAR de implantação indisponível: %s\n' "$archive" >&2
    return 1
  }
  root_script+=$'\n'
  root_script+=$(cat <<'ROOT'
set -o pipefail
exec </dev/null
printf '%s\n' "$4" >&2
[[ ${SUDO_UID:-} =~ ^[1-9][0-9]*$ && ${SUDO_GID:-} =~ ^[0-9]+$ ]] ||
  die "Identidade do usuário de publicação indisponível."
# O leitor abre o TAR como usuário. O publicador herda a entrada pelo pipe.
setpriv --reuid "$SUDO_UID" --regid "$SUDO_GID" --clear-groups --no-new-privs -- \
  cat -- "$3" | publish "$1" "$2" "$5" "$6" "$7"
ROOT
  )
  sudo_dialog prepared "$started" /run/current-system/sw/bin/bash -p -c "$root_script" \
    -- "$target" "$expected" "$archive" "$started" "$expected_settings" "$expected_machine" "$reviewed_digest"
}

run_logged_rebuild() {
  local title=$1
  shift
  local -a statuses=()

  if [[ -n $ui_dialog && $1 == sudo_dialog ]]; then
    # O relay mantém a tela do switch e a pausa durante a autenticação.
    ui_message "$ui_accent" '›' "$title" || return "$?"
  else
    ui_progress "$title" || return "$?"
  fi
  printf '\n%s\n' "$title" >> "$rebuild_log" || return "$?"
  if [[ -n $ui_dialog ]]; then
    "$@" >> "$rebuild_log" 2>&1
  else
    # O comando recebe Ctrl+C. O leitor drena também os diagnósticos da limpeza.
    "$@" 2>&1 | (trap '' INT; exec tee -a -- "$rebuild_log") || statuses=("${PIPESTATUS[@]}")
    if (( ${statuses[0]:-0} != 0 )); then return "${statuses[0]}"; fi
    return "${statuses[1]:-0}"
  fi
}

rebuild_configuration() {
  local operation=$1 interactive=$2 machine_dir=${default_destination%/*} status tool
  local log_dir=${XDG_STATE_HOME:-$HOME/.local/state}/noir/rebuilds
  local -a args=(--no-flake -I "nixos-config=$machine_dir/configuration.nix")
  local system_channel=/nix/var/nix/profiles/per-user/root/channels/nixos pinned_channel

  rebuild_operation=$operation
  wizard_started=true
  validation_result=(error 'Bloqueada antes do dry-build')
  if [[ $operation == switch ]] && ! "$interactive"; then
    die 'A ativação exige um terminal interativo para a confirmação.'
  fi
  [[ -f $system_rebuild && -x $system_rebuild ]] || die "Executável indisponível: $system_rebuild."
  for tool in flock mkdir mktemp realpath tee; do
    command -v "$tool" >/dev/null || die "Comando necessário ausente: $tool."
  done
  if [[ $operation == switch ]]; then
    command -v sudo >/dev/null || die 'A ativação requer sudo.'
    ui_section 'Ativação do NixOS'
  fi

  require_searchable_directory "$machine_dir"
  [[ -r $machine_dir ]] || die "UID $EUID sem permissão de leitura para abrir a trava em $machine_dir."
  cd -- "$machine_dir" || die "Não foi possível entrar em $machine_dir."
  # Use a mesma trava de diretório da publicação protegida, inclusive entre contas.
  exec {rebuild_lock_fd}< . || die "Não foi possível abrir $machine_dir para bloqueio."
  flock -n -E 75 -x "$rebuild_lock_fd" || {
    status=$?
    if (( status == 75 )); then
      die "Outra publicação ou operação de rebuild do Noir mantém a trava em $machine_dir."
    fi
    die "Falha ao bloquear $machine_dir (código $status)."
  }
  require_readable_file "$machine_dir/configuration.nix"
  require_searchable_directory "$default_destination"
  require_readable_file "$default_destination/noir.nix"
  require_searchable_directory "$default_destination/config"
  require_readable_file "$default_destination/config/local.nix"

  if pinned_channel=$(realpath -e -- "$system_channel") && [[ $pinned_channel == /nix/store/* ]]; then
    args+=(-I "nixpkgs=$pinned_channel")
  fi
  (umask 077; mkdir -p -- "$log_dir") || die "Não foi possível criar o diretório de registros: $log_dir."
  rebuild_log=$(mktemp -- "$log_dir/$operation.XXXXXXXX.log") || die 'Não foi possível criar o registro do rebuild.'
  printf 'Configuração: %s/configuration.nix\nImplantação: %s\n' "$machine_dir" "$default_destination" > "$rebuild_log" ||
    die 'Não foi possível gravar o registro do rebuild.'
  ui_fields 'Registro' "$rebuild_log"

  validation_result=(error 'Interrompida ou com falha')
  run_logged_rebuild 'Validando configuração (dry-build)' "$system_rebuild" dry-build "${args[@]}" || {
    status=$?
    fail_command "$status" "A validação falhou (código $status). Consulte o registro do rebuild."
  }
  validation_result=(ok 'Concluída')
  ui_success 'Validação (dry-build) concluída.'
  if [[ $operation == switch ]]; then
    ui_confirm $'Aplicar configuração agora?\nServiços podem reiniciar.' || cancel "$?" 'Ativação cancelada.'
    activation_result=(error 'Interrompida ou com falha. Confira a geração atual e o registro.')
    local -a elevate=(sudo --)
    if [[ -n $ui_dialog ]]; then elevate=(sudo_dialog on-demand ''); fi
    run_logged_rebuild 'Aplicando configuração (switch)' "${elevate[@]}" "$system_rebuild" switch "${args[@]}" || {
      status=$?
      if [[ -n $ui_dialog ]] && (( status == 125 )); then
        activation_result=(neutral 'Autenticação cancelada')
        cancel 1 'Autenticação cancelada.'
      fi
      fail_command "$status" "A ativação falhou (código $status). Consulte o registro e confira as gerações do NixOS."
    }
    activation_result=(ok 'Concluída')
    ui_success 'Ativação (switch) concluída.'
  fi
}

trusted_git_path() {
  local item=$1 kind=file mode
  while :; do
    if [[ -e $item || -L $item ]]; then
      [[ ! -L $item && -O $item ]] || return 1
      if [[ $kind == file ]]; then
        [[ -f $item && -r $item ]] || return 1
      else
        [[ -d $item && -x $item ]] || return 1
      fi
      mode=$(stat -c %a -- "$item") || return 1
      (( (8#$mode & 022) == 0 )) || return 1
    fi
    [[ $item == "$HOME" ]] && return 0
    item=${item%/*}
    kind=directory
  done
}

git_config_target() {
  local variable entry account uid passwd_home xdg dotfile xdgfile target
  for variable in GIT_CONFIG "${!GIT_CONFIG_@}" GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE \
                  GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL; do
    [[ ! -v $variable ]] || die "Remova $variable do ambiente antes da primeira instalação."
  done
  entry=$(getent passwd "$username") || die "Não foi possível consultar a conta Linux selecionada."
  IFS=: read -r account _ uid _ _ passwd_home _ <<< "$entry"
  [[ $account == "$username" && $uid == "$EUID" && $passwd_home == /* &&
     ${HOME:-} == /* && $HOME != / && -d $HOME && $HOME == "$(realpath -e -- "$passwd_home")" ]] ||
    die "HOME deve usar o caminho físico do diretório pessoal da conta selecionada."

  xdg=${XDG_CONFIG_HOME:-$HOME/.config}
  [[ $xdg == "$HOME/"* && $xdg == "$(realpath -ms -- "$xdg")" ]] ||
    die "XDG_CONFIG_HOME deve ser um caminho absoluto e normalizado dentro de HOME."
  dotfile=$HOME/.gitconfig
  xdgfile=$xdg/git/config
  trusted_git_path "$dotfile" ||
    die "Caminho inseguro para $dotfile. Revise links, propriedade e permissões."
  trusted_git_path "$xdgfile" ||
    die "Caminho inseguro para $xdgfile. Revise links, propriedade e permissões."
  target=$dotfile
  # O Git grava no arquivo XDG quando ele existe e ~/.gitconfig está ausente.
  if [[ ! -e $dotfile && -f $xdgfile ]]; then target=$xdgfile; fi
  [[ -w ${target%/*} && ( ! -e $target || -w $target ) ]] ||
    die "O destino global do Git não permite gravação: $target."
  printf '%s\n' "$target"
}

check_git_identity() (
  local target=$1 verify=${2:-false} fd reader status=0 scope origin entry key value
  local -A seen=() values=([user.name]="$git_name" [user.email]="$git_email" [init.defaultbranch]=main)
  # A leitura por escopo inclui os dois arquivos globais e seus includes.
  # Com --null, o Git emite escopo\0origem\0chave[\nvalor]\0.
  exec {fd}< <(git config --includes --show-scope --show-origin --null \
    --get-regexp '^(user\.(name|email)|init\.defaultbranch)$') || return 1
  reader=$!

  while IFS= read -r -d '' scope <&"$fd"; do
    IFS= read -r -d '' origin <&"$fd" && IFS= read -r -d '' entry <&"$fd" ||
      die "Registro incompleto na saída do Git config."
    case $scope in
      global) ;;
      system|local|worktree|command) continue ;;
      *) die "Escopo inesperado na saída do Git config." ;;
    esac
    key=${entry%%$'\n'*}
    value=${entry#*$'\n'}
    case $key in
      user.name|user.email|init.defaultbranch) ;;
      *) die "Chave inesperada na saída do Git config." ;;
    esac
    [[ $origin == "file:$target" && ! -v 'seen[$key]' ]] ||
      die "Configuração Git em conflito para $key. Revise arquivos incluídos e definições duplicadas."
    seen[$key]=1
    if "$verify" && [[ $entry != *$'\n'* || $value != "${values[$key]}" ]]; then
      die "O Git global retornou um valor diferente para $key."
    fi
  done
  [[ -z $scope ]] || die "Registro incompleto na saída do Git config."
  exec {fd}<&-
  wait "$reader" || status=$?
  (( status <= 1 )) || die "O Git não conseguiu ler a configuração global. Revise os arquivos e includes."
  if "$verify" && (( ${#seen[@]} != 3 )); then
    die "O Git global não retornou as três preferências esperadas."
  fi
)

configure_git() {
  local i current
  local keys=(user.name user.email init.defaultBranch)
  local values=("$git_name" "$git_email" main)
  current=$(git_config_target) || return 1
  [[ $current == "$git_target" ]] || { printf 'O destino do Git global mudou durante a instalação.\n' >&2; return 1; }
  check_git_identity "$git_target" || return 1
  for i in "${!keys[@]}"; do
    if ! git config --global -- "${keys[i]}" "${values[i]}"; then
      printf 'Falha ao gravar %s no Git global.\n' "${keys[i]}" >&2
      return 1
    fi
  done
  trusted_git_path "$git_target" || { printf 'O caminho do Git global se tornou inseguro.\n' >&2; return 1; }
  check_git_identity "$git_target" true || return 1
}

show_publication() {
  local account=$1 profile=$2 checkout=$3 commit=$4 destination=$5 previous=$6 backup=$7
  shift 7
  ui_section 'CONTA'
  ui_fields 'Usuário' "$account" 'Ambiente gráfico' "$profile"
  if (( $# )); then
    ui_section 'GIT'
    ui_fields 'Nome' "$1" 'E-mail' "$2"
  fi
  ui_section 'IMPLANTAÇÃO'
  ui_fields 'Origem' "$checkout ($commit)" 'Destino' "$destination" \
    'Instalação anterior' "$previous" 'Backup' "$backup"
  printf '\n'
  if [[ $destination == "$default_destination" ]]; then
    ui_info 'Autenticação via sudo necessária.'
    ui_outcome 'Import do NixOS' "${machine_result[@]}"
  fi
}

main() {
  local destination=$default_destination checkout plain=false
  local revision status last_status=0 argument_error='' selection interactive=false screen=main operation
  local -a menu=('Instalar ou atualizar')
  local usage='Uso: ./noir [--plain] [--destination DIRETÓRIO]'
  while (( $# )); do
    case $1 in
      --help|-h) printf '%s\n' "$usage"; return ;;
      --plain) plain=true; shift ;;
      --destination)
        if [[ $# -lt 2 || -z $2 || $2 == --* ]]; then
          argument_error='Informe o destino alternativo.'
          break
        fi
        destination=$2
        shift 2
        ;;
      *) argument_error=$usage; break ;;
    esac
  done
  (( EUID != 0 )) || die "Execute o Noir pela sua conta normal, sem sudo."
  command -v dirname >/dev/null || die "Comando necessário ausente: dirname."
  checkout=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  [[ -r $checkout/core/lib/ui.sh ]] || die "Módulo de interface ausente: $checkout/core/lib/ui.sh."
  source "$checkout/core/lib/ui.sh"
  if ui_interactive; then interactive=true; fi
  trap 'finish "$?"' EXIT
  trap 'cancel 130' INT
  trap 'cancel 143' TERM
  if ! "$plain"; then
    [[ -r $checkout/core/lib/ui-dialog.sh ]] || die "Módulo de interface ausente: $checkout/core/lib/ui-dialog.sh."
    source "$checkout/core/lib/ui-dialog.sh"
    prepare_ui
    if [[ -n $ui_dialog ]]; then
      ui_dialog_open "$checkout/core/lib/noir.dialogrc" || {
        if (( $? == 2 )); then exit 1; fi
        die "Não foi possível iniciar o Dialog. Use --plain."
      }
      export GIT_TERMINAL_PROMPT=0
    fi
  fi
  [[ -z $argument_error ]] || die "$argument_error"
  cd -- "$checkout"
  # Identificação visual sem carregar configurações Git.
  revision=''
  if [[ -f .git/HEAD ]] && IFS= read -r revision < .git/HEAD; then
    revision=${revision#ref: refs/heads/}
    if [[ $revision =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]]; then revision=${revision:0:12}; fi
  fi
  [[ $revision =~ ^[a-zA-Z0-9._/-]+$ ]] || revision=''
  if [[ $destination == "$default_destination" ]]; then menu+=('Gerenciar sistema'); fi
  if [[ -n $ui_dialog ]]; then menu+=('Editar preferências'); fi
  while :; do
    status=0
    case $screen in
      main)
        selection=$(ui_start "$revision" "${menu[@]}") || status=$?
        ;;
      system)
        ui_section_title='Gerenciar sistema'
        selection=$(ui_choose 'Selecione uma operação.' 'Validar configuração (dry-build)' \
          'Aplicar configuração (switch)') || status=$?
        ;;
      published)
        ui_section_title='Publicação concluída'
        selection=$(ui_choose 'O que deseja fazer agora?' 'Validar agora (dry-build)' \
          'Voltar ao menu principal' 'Sair') || status=$?
        ;;
      validated)
        ui_section_title='Validação concluída'
        selection=$(ui_choose 'O que deseja fazer agora?' 'Aplicar configuração (switch)' \
          'Voltar a Gerenciar sistema' 'Sair') || status=$?
        ;;
      dry-result)
        ui_section_title='Validação'
        selection=$(ui_choose 'O que deseja fazer agora?' 'Voltar a Gerenciar sistema' 'Sair') || status=$?
        ;;
      switch-result|alternate-publication)
        ui_section_title='Resultado'
        selection=$(ui_choose 'O que deseja fazer agora?' 'Voltar ao menu principal' 'Sair') || status=$?
        ;;
    esac
    if (( status > 1 )); then cancel "$status"; fi
    if (( status == 1 )); then selection=back; fi
    case $screen:$selection in
      main:back|published:3|validated:3|dry-result:2|switch-result:2|alternate-publication:2)
        trap 'finish "$?" false' EXIT
        return "$last_status"
        ;;
      main:2)
        if [[ $destination == "$default_destination" ]]; then
          screen=system; continue
        fi
        [[ -n $ui_dialog ]] || die 'Selecione uma opção do menu.'
        operation=settings ;;
      main:3)
        [[ $destination == "$default_destination" && -n $ui_dialog ]] || die 'Selecione uma opção do menu.'
        operation=settings ;;
      system:back|published:2|published:back|switch-result:1|switch-result:back|alternate-publication:1|alternate-publication:back)
        screen=main; continue ;;
      validated:2|validated:back|dry-result:1|dry-result:back)
        screen=system; continue ;;
      main:1) operation=install ;;
      system:1|published:1) operation=dry-build ;;
      system:2|validated:1) operation=switch ;;
      *) die 'Selecione uma opção do menu.' ;;
    esac

    # Chame diretamente para que o errexit continue ativo dentro da operação.
    set +e
    trap ':' INT
    case $operation in
      install) run_operation install_configuration "$checkout" "$destination" ;;
      settings) run_operation manage_settings "$checkout" "$destination" ;;
      *) run_operation rebuild_configuration "$operation" "$interactive" ;;
    esac
    status=$?
    last_status=$status
    trap 'cancel 130' INT
    set -e
    case $operation in
      install)
        screen=main
        if (( status == 0 )); then
          screen=published
          if [[ $destination != "$default_destination" ]]; then screen=alternate-publication; fi
        fi
        ;;
      dry-build)
        screen=dry-result
        if (( status == 0 )); then screen=validated; fi
        ;;
      switch) screen=switch-result ;;
      settings) screen=main ;;
    esac
  done
}

install_configuration() {
  local checkout=$1 destination=$2 parent expected=absent source_commit
  local username git_name git_email git_target tree entry mode file checkout_local root_script
  local local_info account profile previous backup status shell_options=$- checkout_lock
  local choices_revision published_revision=absent machine_revision='' machine_digest='' checkout_status
  local +x password
  local -a identity_args=() nix_files=() identity_summary=()

  ui_section_title=''
  ui_progress 'Verificando pré-requisitos'
  check_requirements
  ui_success 'Pré-requisitos'
  if [[ $destination != "$default_destination" ]]; then
    destination=$(realpath -ms -- "$destination") || die "Destino alternativo inválido."
    parent=${destination%/*}
    [[ $destination != /etc/nixos && $destination != /etc/nixos/* &&
       -d $parent && $(realpath -e -- "$parent") == "$parent" && -w $parent ]] ||
      die "Use um diretório pai físico e gravável fora de /etc/nixos para o destino alternativo."
  fi
  [[ $destination != "$checkout" && $destination != "$checkout/"* && $checkout != "$destination/"* ]] ||
    die "Escolha um destino separado do checkout."
  wizard_started=true
  exec {checkout_lock}< "$checkout"
  flock -n -x "$checkout_lock" || die 'Outra edição ou publicação está em andamento neste checkout.'
  backup=$destination.previous
  if [[ -d $backup && ! -L $backup ]]; then backup_result=(ok "$backup"); fi
  if [[ -e $destination || -L $destination ]]; then
    require_searchable_directory "$destination"
    require_searchable_directory "$destination/config"
    for file in "$destination" "$destination/config" "$destination/config/local.nix"; do
      [[ ! -L $file ]] || die "Link simbólico não permitido na implantação: $file."
    done
    require_readable_file "$destination/config/local.nix"
    published_revision=$(file_revision "$destination/settings.json")
    expected=$(stat -c '%d:%i' -- "$destination") || die "Não foi possível identificar a implantação em $destination."
  fi

  if [[ $expected == absent ]]; then
    identity_result=(warning 'Pendente')
    read_identity
    [[ $(id -u -- "$username") == "$EUID" ]] ||
      die "Execute a primeira instalação pela própria conta Linux selecionada."
    git_target=$(git_config_target)
    identity_args=(--argstr username "$username" --argstr gitName "$git_name" --argstr gitEmail "$git_email")
  else
    identity_result=(ok 'Preservada')
    ui_info 'A identidade da implantação será preservada.'
  fi
  if [[ $expected == absent ]]; then check_git_identity "$git_target"; fi
  [[ $(git rev-parse --show-toplevel) == "$checkout" ]] || die "Execute o script a partir de um checkout Git."
  ui_section 'Sincronização Git'
  ui_confirm 'Consultar remoto?' || cancel "$?"
  sync_checkout
  for file in config/local.nix settings.json; do
    git check-ignore --quiet -- "$file" ||
      die "Inclua $file nas regras de exclusão do Git antes de continuar."
  done

  ui_progress 'Preparando arquivos'
  prepared=$(mktemp -d)
  tree=$prepared/tree
  mkdir -- "$tree"
  git ls-tree -rz "$source_commit" > "$prepared/files"
  while IFS= read -r -d '' entry; do
    mode=${entry%% *}
    file=${entry#*$'\t'}
    [[ ( $mode == 100644 || $mode == 100755 ) && $file != config/local.nix && $file != settings.json ]] ||
      die "Arquivo versionado incompatível com a implantação: $file."
  done < "$prepared/files"
  git -c tar.umask=0022 archive --format=tar "$source_commit" | tar -xf - -C "$tree" ||
    die "Não foi possível preparar os arquivos do Git."
  while IFS= read -r -d '' entry; do
    file=${entry#*$'\t'}
    [[ -f $tree/$file && ! -L $tree/$file ]] || die "Arquivo versionado ausente na cópia: $file."
    if [[ $file == *.nix ]]; then
      nix_files+=("$tree/$file")
    fi
  done < "$prepared/files"
  [[ -f $tree/noir.nix && -f $tree/applications.nix &&
     -f $tree/core/config/options.nix && -f $tree/config/local.example.nix ]] ||
    die "O checkout atualizado está incompleto."
  ui_run 'Validando arquivos Nix' nix-instantiate --parse "${nix_files[@]}" >/dev/null || {
    fail_command "$?" "A validação dos arquivos Nix falhou."
  }
  ui_success 'Arquivos Nix'

  ui_progress 'Preparando configuração local'
  checkout_local=$checkout/config/local.nix
  if [[ -e $checkout_local || -L $checkout_local ]]; then
    [[ -f $checkout_local && ! -L $checkout_local ]] || die "Use um arquivo regular em $checkout_local."
    validate_local "$tree/core/config/options.nix" "$checkout_local" "${identity_args[@]}" >/dev/null
  fi
  if [[ $expected != absent ]]; then
    validate_local "$tree/core/config/options.nix" "$destination/config/local.nix" >/dev/null
    cp -- "$destination/config/local.nix" "$tree/config/local.nix"
    local_result=(ok 'Preservada da implantação')
  else
    if [[ -f $checkout_local ]]; then
      cp -- "$checkout_local" "$tree/config/local.nix"
      local_result=(ok 'Preservada do checkout')
    else
      generate_local "$tree/config/local.example.nix" "$tree/config/local.nix"
      local_result=(warning 'Gerada na área de preparação')
    fi
  fi
  local_info=$(validate_local "$tree/core/config/options.nix" "$tree/config/local.nix" "${identity_args[@]}")
  choices_revision=$(file_revision "$checkout/settings.json")
  if [[ $published_revision == absent ]]; then
    printf '{}\n' > "$prepared/settings.json"
  else
    cp -- "$destination/settings.json" "$prepared/settings.json"
    require_revision "$destination/settings.json" "$published_revision"
  fi
  if [[ $choices_revision == absent ]]; then
    if [[ $expected == absent ]]; then
      ui_section 'Ambiente gráfico'
      profile=$(choose_desktop) || cancel "$?" 'Publicação cancelada.'
      settings_eval "$tree" "$prepared/settings.json" --argstr field desktop --argstr value "$profile" \
        > "$tree/settings.json"
      printf '\n' >> "$tree/settings.json"
    else
      cp -- "$prepared/settings.json" "$tree/settings.json"
    fi
  else
    cp -- "$checkout/settings.json" "$tree/settings.json"
    require_revision "$checkout/settings.json" "$choices_revision"
  fi
  chmod 644 -- "$tree/settings.json"
  validate_settings "$tree" "$tree/settings.json"
  account=${local_info:1:-1}
  profile=$(settings_eval "$tree" "$tree/settings.json" --argstr attr desktop)
  profile=${profile:1:-1}
  case $profile in
    kde) profile='KDE Plasma' ;;
    gnome) profile='GNOME' ;;
    cinnamon) profile='Cinnamon' ;;
    xfce) profile='XFCE' ;;
    machine) profile='Definido pela máquina' ;;
  esac
  ui_success 'Configuração local'

  previous='Nenhuma'
  if [[ $expected == absent ]]; then
    identity_summary=("$git_name" "$git_email")
    backup='Não se aplica'
  else
    previous='Substituída se houver mudanças'
  fi
  if [[ $destination == "$default_destination" ]]; then
    prepare_machine_import "${destination%/*}/configuration.nix"
  fi
  ui_review 'Revisar publicação' show_publication "$account" "$profile" "$checkout" "$source_commit" \
    "$destination" "$previous" "$backup" "${identity_summary[@]}" ||
    cancel "$?" 'Publicação cancelada.'
  if ! cmp -s -- "$prepared/settings.json" "$tree/settings.json"; then
    ui_review 'Preferências para publicação' show_file_diff settings.json \
      "$prepared/settings.json" "$tree/settings.json" || cancel "$?" 'Publicação cancelada.'
  fi
  ui_section 'Publicação'
  ui_confirm 'Publicar a configuração revisada?' || cancel "$?" 'Publicação cancelada.'
  if [[ -n $ui_dialog && $destination == "$default_destination" ]]; then
    set +x +a
    password=$(ui_dialog_password) || cancel "$?" 'Autenticação cancelada.'
  fi
  require_revision "$checkout/settings.json" "$choices_revision"
  checkout_status=$(git status --porcelain=v1 --untracked-files=all)
  [[ -z $checkout_status && $(git rev-parse HEAD) == "$source_commit" &&
     $(git rev-parse '@{upstream}') == "$source_commit" ]] ||
    die 'O checkout ou o upstream mudou durante a confirmação. Execute novamente.'
  if [[ ! -e $checkout_local && ! -L $checkout_local ]]; then
    new_local=$(mktemp -- "$checkout/config/.local.nix.XXXXXXXX")
    cat -- "$tree/config/local.nix" > "$new_local"
  fi
  if [[ $choices_revision == absent ]]; then
    new_choices=$(mktemp -- "$checkout/.settings.XXXXXXXX")
    cat -- "$tree/settings.json" > "$new_choices"
  fi

  tar -cf "$prepared/deployment.tar" -C "$tree" . || die "Falha ao preparar a cópia para publicação."
  publication_result=(error 'Interrompida ou com falha')
  ui_progress 'Publicando configuração'
  status=0
  if [[ $destination == "$default_destination" ]]; then
    root_script="PATH=$system_path"$'\n'"default_destination=$default_destination"$'\n'
    root_script+=$(declare -f die check_regular_file file_digest file_revision require_revision \
      insert_noir_import publication_revision move_publication finish_publication publish)
    if [[ -n $ui_dialog ]]; then
      publish_dialog "$prepared/deployment.tar" "$root_script" "$destination" "$expected" "$published_revision" \
        "$machine_revision" "$machine_digest" || status=$?
      unset -v password
      if [[ $shell_options == *a* ]]; then set -a; fi
      if [[ $shell_options == *x* ]]; then set -x; fi
    else
      root_script+=$'\npublish "$@"'
      sudo -- /run/current-system/sw/bin/bash -p -c "$root_script" -- "$destination" "$expected" "$published_revision" \
        "$machine_revision" "$machine_digest" < "$prepared/deployment.tar" || status=$?
    fi
  else
    # Colete o status sem suprimir o errexit do publicador.
    set +e
    publish "$destination" "$expected" "$published_revision" < "$prepared/deployment.tar"
    status=$?
    set -e
  fi

  if (( status == 75 )); then
    publication_result=(error 'Reversão incompleta. Consulte os caminhos de recuperação nos registros.')
  fi
  if (( status != 0 )); then
    fail_command "$status" 'Falha na publicação. Consulte os diagnósticos.'
  fi
  published_destination=$destination
  publication_result=(ok "Concluída em $destination")
  if [[ -n $machine_digest ]]; then machine_result=(ok 'Import incluído'); fi
  if [[ -n $new_local ]] && ! ln -T -- "$new_local" "$checkout_local"; then
    ui_warning "Preservado o arquivo em $checkout_local. Confira a identidade do checkout."
  fi
  if [[ -n $new_choices ]] && ! ln -T -- "$new_choices" "$checkout/settings.json"; then
    ui_warning 'Preservado settings.json do checkout. Confira as preferências antes da próxima publicação.'
  fi
  if [[ ${local_result[0]} == warning ]]; then local_result=(ok 'Gerada e publicada'); fi
  if [[ $expected != absent && -d $backup ]]; then backup_result=(ok "$backup"); fi
  if [[ $expected == absent ]]; then
    configure_git || status=$?
  fi
  if (( status != 0 )); then
    identity_result=(error 'Ajuste manual pendente')
    ui_section 'AJUSTE MANUAL DO GIT' >&2
    ui_info "Conta $username. Execute os comandos pendentes." >&2
    printf '  git config --global user.name %q\n  git config --global user.email %q\n  git config --global init.defaultBranch main\n' \
      "$git_name" "$git_email" >&2
    return "$status"
  fi
  if [[ $expected == absent ]]; then identity_result=(ok 'Aplicada'); fi
}
