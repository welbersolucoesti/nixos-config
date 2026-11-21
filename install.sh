#!/usr/bin/env bash
set -euo pipefail
umask 022
unset TAR_OPTIONS

default_destination=/etc/nixos/nixos-config
system_path=/run/current-system/sw/bin:/run/wrappers/bin
prepared=''
new_local=''
wizard_started=false
git_result=(neutral 'Não consultado')
local_result=(neutral 'Não preparada')
publication_result=(neutral 'Não iniciada')
backup_result=(neutral 'Não criado')
identity_result=(neutral 'Não aplicada')
published_destination=''

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
  if [[ -n ${ui_dialog:-} ]]; then
    ui_error "$*"
    exit "$status"
  fi
  die "$*"
}

show_result() {
  ui_section 'Resumo'
  ui_outcome 'Sincronização' "${git_result[@]}"
  ui_outcome 'Configuração local' "${local_result[@]}"
  if [[ -n $published_destination ]]; then
    ui_fields 'Arquivo local' "$published_destination/config/local.nix"
  fi
  ui_outcome 'Publicação' "${publication_result[@]}"
  ui_outcome 'Backup' "${backup_result[@]}"
  ui_outcome 'Identidade Git' "${identity_result[@]}"
  if [[ -n $published_destination ]]; then show_next_steps "$published_destination"; fi
}

finish() {
  local status=$1
  if [[ -n $prepared ]]; then rm -rf -- "$prepared"; fi
  if [[ -n $new_local ]]; then rm -f -- "$new_local"; fi
  if [[ -n ${ui_dialog_dir:-} ]]; then
    ui_dialog_finish "$status"
  elif "$wizard_started"; then
    show_result
  fi
  return "$status"
}

prepare_ui() {
  local backend=$1 candidate status=0
  ui_interactive || return 0
  if candidate=$(type -P "$backend") && candidate=$(realpath -e -- "$candidate") &&
     "ui_use_$backend" "$candidate"; then
    return
  fi
  if [[ $backend == dialog ]]; then
    die "Dialog indisponível. Abra uma sessão com nix-shell -p dialog ou execute com --plain."
  fi
  command -v nix-shell >/dev/null || return 0
  ui_info "Modo visual opcional · ${backend^} via nix-shell"
  if ui_confirm "Carregar ${backend^}?"; then
    ui_progress "Carregando ${backend^}"
    candidate=$(nix-shell -p "$backend" --run "type -P $backend") || status=$?
    if (( status >= 128 )); then cancel "$status"; fi
    if (( status == 0 )) && "ui_use_$backend" "$candidate"; then return; fi
    ui_warning "${backend^} indisponível. Modo texto."
  else
    status=$?
    if (( status >= 128 )); then cancel "$status"; fi
  fi
}

check_requirements() {
  local cmd mv_help publication_path=$PATH
  local publication_tools=(cat chmod cmp cp diff find flock mkdir mktemp mv rm sort stat tar)
  for cmd in git nix-instantiate grep id getent dirname realpath ln "${publication_tools[@]}"; do
    command -v "$cmd" >/dev/null || die "Comando necessário ausente: $cmd."
  done
  grep -Eq '^ID=(nixos|"nixos")$' /etc/os-release || die "Este instalador requer NixOS."
  if [[ $destination == "$default_destination" ]]; then
    command -v sudo >/dev/null || die "A publicação protegida requer sudo."
    [[ -x /run/current-system/sw/bin/bash ]] || die "Bash do sistema indisponível para publicar."
    for cmd in "${publication_tools[@]}"; do
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
  local branch remote upstream status head base address count
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

  [[ -z $status ]] || die "Resolva as alterações locais antes de aplicar o fast-forward."
  if [[ $head != "$base" ]]; then
    [[ $source_commit == "$base" ]] ||
      die "As branches divergiram e o fast-forward é impossível. Resolva a divergência no checkout."
    die "O checkout contém commits ainda ausentes no remoto. Sincronize a branch antes de instalar."
  fi
  if git ls-files --error-unmatch -- config/local.nix >/dev/null 2>&1 ||
     git cat-file -e "$source_commit:config/local.nix" 2>/dev/null; then
    die "config/local.nix aparece no histórico a usar. Preserve suas escolhas e retire o arquivo do controle de versão antes de instalar."
  fi
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
  local model=$1 output=$2 desktop line value
  local assignment='^([[:blank:]]*)(desktop|username|userName|userEmail)[[:blank:]]*='
  ui_section 'Ambiente gráfico'
  desktop=$(ui_choose 'KDE Plasma' 'XFCE') || cancel "$?"
  case $desktop in
    ''|1) desktop=kde ;;
    2) desktop=xfce ;;
    *) die "Escolha 1 para KDE Plasma ou 2 para XFCE." ;;
  esac
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ $assignment ]]; then
      case ${BASH_REMATCH[2]} in
        desktop) value=$desktop ;;
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
      evaluated = lib.evalModules {
        modules = [
          { inherit (import (builtins.toPath options) { inherit lib; config = { }; }) options; }
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
    builtins.deepSeq cfg "${cfg.username} ${if cfg.desktop == null then "machine" else cfg.desktop}"
  ' || fail_command "$?" "Revise $file conforme config/local.example.nix e execute novamente."
}

publish() (
  set -euo pipefail
  umask 022
  unset TAR_OPTIONS
  local target=$1 expected=$2 parent stage tree keep_stage=false
  local previous="$1.previous"
  local archive archive_size end_block end_offset trailer_size
  local tar_end='^block ([0-9]+): \*\* Block of NULs \*\*$'
  parent=${target%/*}

  [[ -d $parent && ! -L $parent ]] || die "Diretório pai de publicação inválido: $parent."
  if (( EUID == 0 )); then
    [[ $target == /etc/nixos/nixos-config && -O $parent &&
       -z $(find "$parent" -maxdepth 0 -perm /022 -print) ]] ||
      die "O destino protegido exige /etc/nixos sob controle de root."
  fi

  exec 9< "$parent"
  flock -x 9 || die "Não foi possível bloquear $parent para publicação."
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

  stage=$(mktemp -d -- "$parent/.nixos-config.XXXXXXXX") || die "Falha ao criar a área de publicação."
  trap 'if $keep_stage; then
          if [[ -d $tree && $(stat -c "%d:%i" -- "$tree") == "$expected" ]]; then
            printf "Cópia anterior preservada para recuperação: %s\n" "$tree" >&2
          fi
        else
          rm -rf -- "$stage"
        fi' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  archive=$stage/deployment.tar
  cat > "$archive" || die "Falha ao receber o TAR de implantação."
  tree=$stage/tree
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
     -f $tree/personal.nix && -f $tree/config/options.nix && -f $tree/config/local.nix &&
     ! -e $tree/.git ]] || die "Árvore de publicação inválida."
  chmod -R go-w -- "$tree"

  if [[ $expected == absent ]]; then
    mv -Tn --no-copy -- "$tree" "$target" && [[ ! -e $tree ]] || die "Falha ao publicar em $target."
    return
  fi

  cmp -s -- "$target/config/local.nix" "$tree/config/local.nix" ||
    die "A configuração local mudou durante a preparação. Execute novamente."
  cp -p -- "$target/config/local.nix" "$tree/config/local.nix" ||
    die "Falha ao preservar as permissões da configuração local."
  if diff -qr --no-dereference -- "$tree" "$target" >/dev/null &&
     cmp -s <(find "$tree" -type f -printf '%P %m\0' | sort -z) \
       <(find "$target" -type f -printf '%P %m\0' | sort -z); then
    printf 'A cópia implantada já contém os mesmos arquivos.\n'
    return
  fi

  if [[ -e $previous || -L $previous ]]; then
    [[ -d $previous && ! -L $previous && -O $previous ]] ||
      die "O caminho de backup $previous está ocupado. Verifique-o antes de continuar."
  fi
  # Antes e depois da troca, target aponta para uma árvore completa.
  printf 'Substituindo a implantação e preparando o backup anterior.\n'
  keep_stage=true
  if ! mv -T --exchange --no-copy -- "$tree" "$target"; then
    keep_stage=false
    die "Falha na troca em $target. A instalação anterior continua em uso."
  fi

  if [[ -d $previous ]]; then
    mv -T --exchange --no-copy -- "$tree" "$previous" ||
      die "A nova cópia está instalada. A cópia que estava em uso está em $tree. O backup em $previous foi mantido."
  else
    mv -Tn --no-copy -- "$tree" "$previous" && [[ ! -e $tree ]] ||
      die "A nova cópia está instalada. A anterior está em $tree; falhou a criação de $previous."
  fi
  keep_stage=false
  printf 'Cópia anterior para recuperação: %s\n' "$previous"
)

relay_sudo_dialog() {
  local prompt=$1 started=$2 line
  while IFS= read -r line || [[ -n $line ]]; do
    case $line in
      "$prompt"|"$started")
        # NOPASSWD fecha o canal sem enviar a senha ao comando ou ao log de E/S.
        if [[ -v password ]]; then
          if [[ $line == "$prompt" ]]; then printf '%s\n' "$password" || return "$?"; fi
          exec 1>&-
          unset -v password
        fi
        ;;
      *) printf '%s\n' "$line" >&2 || return "$?" ;;
    esac
  done
}

publish_dialog() (
  local archive=$1 root_script=$2 target=$3 expected=$4
  local relay='' input='' diagnostics='' status relay_status
  local prompt="Noir autenticação ${prepared##*/}" started="Noir publicação ${prepared##*/}"

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
  cat -- "$3" | publish "$1" "$2"
ROOT
  )

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
        printf "Falha no auxiliar de autenticação (código %s).\n" "$relay_status" >&2
        if (( status == 0 )); then status=$relay_status; fi
      }
    fi
    exit "$status"
  ' EXIT

  coproc NOIR_RELAY { relay_sudo_dialog "$prompt" "$started"; } || return 1
  relay=$! input=${NOIR_RELAY[0]:-} diagnostics=${NOIR_RELAY[1]:-}
  [[ -n $input && -n $diagnostics ]] || return 1

  # O sudo permanece em primeiro plano para receber a interrupção do terminal.
  sudo -k -S -p $'\n'"$prompt"$'\n' -- /run/current-system/sw/bin/bash -p -c "$root_script" \
    -- "$target" "$expected" "$archive" "$started" \
    <&"$input" 2>&"$diagnostics"
)

show_next_steps() {
  local destination=$1
  if [[ $destination == "$default_destination" ]]; then
    ui_section 'MIGRAÇÃO'
    cat <<'INSTRUCTIONS'

Em /etc/nixos/configuration.nix, adicione ./nixos-config/personal.nix a imports.
Remova os imports antigos do projeto. Preserve os imports de hardware e os ajustes da máquina.

Valide:
  sudo nixos-rebuild dry-build

Após conferir o resultado, aplique manualmente:
  sudo nixos-rebuild switch
INSTRUCTIONS
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
  fi
}

main() {
  local backend=$1 entrypoint
  shift
  local destination=$default_destination checkout parent expected=absent source_commit plain=false
  local username git_name git_email git_target tree entry mode file checkout_local root_script
  local revision local_info account profile previous backup status argument_error='' shell_options=$-
  local +x password
  local -a identity_args=() nix_files=() identity_summary=()
  case $backend in
    dialog) entrypoint=config.sh ;;
    gum) entrypoint=install.sh ;;
  esac
  local usage="Uso: bash $entrypoint [--plain] [--destination DIRETÓRIO]"
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
  (( EUID != 0 )) || die "Execute o instalador pela sua conta normal, sem sudo."
  command -v dirname >/dev/null || die "Comando necessário ausente: dirname."
  checkout=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  [[ -r $checkout/lib/ui.sh ]] || die "Módulo de interface ausente: $checkout/lib/ui.sh."
  source "$checkout/lib/ui.sh"
  trap 'finish "$?"' EXIT
  trap 'cancel 130' INT
  trap 'cancel 143' TERM
  if ! "$plain" && [[ $backend == dialog ]]; then
    [[ -r $checkout/lib/ui-dialog.sh ]] || die "Módulo de interface ausente: $checkout/lib/ui-dialog.sh."
    source "$checkout/lib/ui-dialog.sh"
    prepare_ui dialog
    if [[ -n $ui_dialog ]]; then
      ui_dialog_open "$checkout/lib/noir.dialogrc" || {
        if (( $? == 2 )); then exit 1; fi
        die "Não foi possível iniciar o Dialog. Use --plain."
      }
      export GIT_TERMINAL_PROMPT=0
    fi
  fi
  [[ -z $argument_error ]] || die "$argument_error"
  ui_progress 'Verificando pré-requisitos'
  check_requirements
  ui_success 'Pré-requisitos'
  if ! "$plain" && [[ $backend == gum ]]; then prepare_ui gum; fi
  cd -- "$checkout"
  if [[ $destination != "$default_destination" ]]; then
    destination=$(realpath -ms -- "$destination") || die "Destino alternativo inválido."
    parent=${destination%/*}
    [[ $destination != /etc/nixos && $destination != /etc/nixos/* &&
       -d $parent && $(realpath -e -- "$parent") == "$parent" && -w $parent ]] ||
      die "Use um diretório pai físico e gravável fora de /etc/nixos para o destino alternativo."
  fi
  [[ $destination != "$checkout" && $destination != "$checkout/"* && $checkout != "$destination/"* ]] ||
    die "Escolha um destino separado do checkout."
  # Identificação visual sem carregar configurações Git antes das verificações.
  revision=''
  if [[ -f .git/HEAD ]] && IFS= read -r revision < .git/HEAD; then
    revision=${revision#ref: refs/heads/}
    if [[ $revision =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]]; then revision=${revision:0:12}; fi
  fi
  [[ $revision =~ ^[a-zA-Z0-9._/-]+$ ]] || revision=''
  ui_start "$revision" || cancel "$?"
  wizard_started=true
  backup=$destination.previous
  if [[ -d $backup && ! -L $backup ]]; then backup_result=(ok "$backup"); fi
  if [[ -e $destination || -L $destination ]]; then
    [[ -d $destination && ! -L $destination && -d $destination/config && ! -L $destination/config &&
       -f $destination/config/local.nix && ! -L $destination/config/local.nix ]] ||
      die "Instalação incompleta em $destination. Prepare config/local.nix como arquivo regular e execute novamente."
    expected=$(stat -c '%d:%i' -- "$destination")
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
    ui_info 'Identidade e escolhas locais serão preservadas.'
  fi
  if [[ $expected == absent ]]; then check_git_identity "$git_target"; fi
  [[ $(git rev-parse --show-toplevel) == "$checkout" ]] || die "Execute o script a partir de um checkout Git."
  ui_section 'Sincronização Git'
  ui_confirm 'Consultar remoto?' || cancel "$?"
  sync_checkout
  git check-ignore --quiet -- config/local.nix ||
    die "Inclua config/local.nix nas regras de exclusão do Git antes de continuar."

  ui_progress 'Preparando arquivos'
  prepared=$(mktemp -d)
  tree=$prepared/tree
  mkdir -- "$tree"
  git ls-tree -rz "$source_commit" > "$prepared/files"
  while IFS= read -r -d '' entry; do
    mode=${entry%% *}
    file=${entry#*$'\t'}
    [[ ( $mode == 100644 || $mode == 100755 ) && $file != config/local.nix ]] ||
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
  [[ -f $tree/personal.nix && -f $tree/config/options.nix && -f $tree/config/local.example.nix ]] ||
    die "O checkout atualizado está incompleto."
  ui_run 'Validando arquivos Nix' nix-instantiate --parse "${nix_files[@]}" >/dev/null || {
    fail_command "$?" "A validação dos arquivos Nix falhou."
  }
  ui_success 'Arquivos Nix'

  ui_progress 'Preparando configuração local'
  checkout_local=$checkout/config/local.nix
  if [[ -e $checkout_local || -L $checkout_local ]]; then
    [[ -f $checkout_local && ! -L $checkout_local ]] || die "Use um arquivo regular em $checkout_local."
    validate_local "$tree/config/options.nix" "$checkout_local" "${identity_args[@]}" >/dev/null
  fi
  if [[ $expected != absent ]]; then
    validate_local "$tree/config/options.nix" "$destination/config/local.nix" >/dev/null
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
  local_info=$(validate_local "$tree/config/options.nix" "$tree/config/local.nix" "${identity_args[@]}")
  # A saída é composta apenas pelo nome de conta validado e pelo enum do perfil.
  read -r account profile <<< "${local_info:1:-1}"
  case $profile in
    kde) profile='KDE Plasma' ;;
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
  ui_review 'Revisar publicação' show_publication "$account" "$profile" "$checkout" "$source_commit" \
    "$destination" "$previous" "$backup" "${identity_summary[@]}" ||
    cancel "$?" 'Publicação cancelada.'
  ui_section 'Publicação'
  ui_confirm 'Publicar a configuração revisada?' || cancel "$?" 'Publicação cancelada.'
  if [[ -n $ui_dialog && $destination == "$default_destination" ]]; then
    set +x +a
    password=$(ui_dialog_password) || cancel "$?" 'Autenticação cancelada.'
  fi
  if [[ ! -e $checkout_local && ! -L $checkout_local ]]; then
    new_local=$(mktemp -- "$checkout/config/.local.nix.XXXXXXXX")
    cat -- "$tree/config/local.nix" > "$new_local"
    ln -T -- "$new_local" "$checkout_local" || die "Falha ao criar $checkout_local. Preserve o arquivo existente."
    rm -- "$new_local"
    new_local=''
  fi

  tar -cf "$prepared/deployment.tar" -C "$tree" . || die "Falha ao preparar a cópia para publicação."
  publication_result=(error 'Interrompida ou com falha')
  ui_progress 'Publicando configuração'
  if [[ $destination == "$default_destination" ]]; then
    root_script="PATH=$system_path"$'\n'
    root_script+=$(declare -f die publish)
    if [[ -n $ui_dialog ]]; then
      status=0
      publish_dialog "$prepared/deployment.tar" "$root_script" "$destination" "$expected" || status=$?
      unset -v password
      if [[ $shell_options == *a* ]]; then set -a; fi
      if [[ $shell_options == *x* ]]; then set -x; fi
      if (( status != 0 )); then fail_command "$status" "Falha na publicação. Consulte os diagnósticos."; fi
    else
      root_script+=$'\npublish "$@"'
      sudo -- /run/current-system/sw/bin/bash -p -c "$root_script" -- "$destination" "$expected" \
        < "$prepared/deployment.tar" ||
        fail_command "$?" "Falha na publicação. Consulte os diagnósticos."
    fi
  else
    publish "$destination" "$expected" < "$prepared/deployment.tar"
  fi

  published_destination=$destination
  publication_result=(ok "Concluída em $destination")
  if [[ ${local_result[0]} == warning ]]; then local_result=(ok 'Gerada e publicada'); fi
  if [[ $expected != absent && -d $backup ]]; then backup_result=(ok "$backup"); fi
  if [[ $expected == absent ]] && ! configure_git; then
    identity_result=(error 'Ajuste manual pendente')
    ui_section 'AJUSTE MANUAL DO GIT' >&2
    ui_info "Conta $username. Execute os comandos pendentes." >&2
    printf '  git config --global user.name %q\n  git config --global user.email %q\n  git config --global init.defaultBranch main\n' \
      "$git_name" "$git_email" >&2
    return 1
  fi
  if [[ $expected == absent ]]; then identity_result=(ok 'Aplicada'); fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main gum "$@"
fi
