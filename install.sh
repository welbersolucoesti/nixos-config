#!/usr/bin/env bash
set -euo pipefail
umask 022
unset TAR_OPTIONS

default_destination=/etc/nixos/nixos-config
system_path=/run/current-system/sw/bin:/run/wrappers/bin
prepared=''
new_local=''

die() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

confirm() {
  local answer
  IFS= read -r -p "$1 [s/N] " answer && [[ $answer == [sS] ]]
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
    publication_path=$system_path
  fi
  mv_help=$(PATH=$publication_path mv --help) || die "Não foi possível consultar os recursos de mv."
  [[ $mv_help == *--exchange* && $mv_help == *--no-copy* ]] ||
    die "A publicação requer mv com suporte a --exchange e --no-copy."
  nix-instantiate --eval --strict --expr '(import <nixpkgs> {}).lib.version' >/dev/null ||
    die "Nixpkgs indisponível. Verifique o canal ou o NIX_PATH antes de instalar."
}

read_identity() {
  local account uid
  account=$(id -un)
  IFS= read -r -p "Conta Linux [$account]: " username || die "Entrada interrompida."
  username=${username:-$account}
  [[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Nome de conta Linux inválido."
  uid=$(id -u -- "$username") && [[ $uid != 0 ]] || die "Escolha uma conta Linux existente sem UID 0."

  IFS= read -r -p 'Nome para autoria Git: ' git_name || die "Entrada interrompida."
  IFS= read -r -p 'E-mail para autoria Git: ' git_email || die "Entrada interrompida."
  [[ $git_name =~ ^[^[:cntrl:]\<\>]*[^[:space:][:cntrl:]\<\>][^[:cntrl:]\<\>]*$ ]] ||
    die "Informe um nome para o Git sem caracteres de controle ou sinais de menor e maior."
  [[ $git_email =~ ^[^[:space:][:cntrl:]\<\>@]+@[^[:space:][:cntrl:]\<\>@]+$ ]] ||
    die "Informe um e-mail Git com um único @ e sem espaços."
  printf '\nConta Linux: %s\nNome Git: %s\nE-mail Git: %s\n\n' "$username" "$git_name" "$git_email"
}

sync_checkout() {
  local branch remote upstream status head base
  branch=$(git symbolic-ref --quiet --short HEAD) || die "Abra uma branch local antes de instalar."
  remote=$(git config --get "branch.$branch.remote") && [[ -n $remote && $remote != . ]] ||
    die "Configure uma branch remota correspondente para $branch."
  git fetch --prune -- "$remote" || die "Falha ao buscar atualizações de $remote."
  upstream=$(git rev-parse --symbolic-full-name '@{upstream}') ||
    die "A branch remota de $branch não está disponível. Confira o upstream configurado."

  head=$(git rev-parse HEAD)
  source_commit=$(git rev-parse --verify "$upstream^{commit}") ||
    die "A branch remota de $branch não está disponível."
  status=$(git status --porcelain=v1 --untracked-files=all) || die "Falha ao consultar o checkout."
  printf '\nComparando %s com %s.\n' "$branch" "${upstream#refs/remotes/}"
  if [[ -n $status ]]; then
    printf '\nAlterações locais não commitadas:\n%s\n' "$status"
  fi
  base=$(git merge-base "$head" "$source_commit") || die "As branches não têm histórico em comum."
  if [[ $source_commit != "$base" ]]; then
    printf '\nCommits novos no remoto:\n'
    git --no-pager log --oneline "$base..$source_commit"
    printf '\nArquivos alterados no remoto:\n'
    git --no-pager diff --name-status "$base" "$source_commit"
  fi
  if [[ $head != "$base" ]]; then
    printf '\nCommits apenas locais:\n'
    git --no-pager log --oneline "$base..$head"
    printf '\nArquivos alterados nos commits locais:\n'
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
    printf 'O checkout já está atualizado.\n'
    return
  fi

  if ! confirm "Aplicar o fast-forward até o commit $source_commit?"; then
    update_cancelled=true
    return
  fi
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
  git merge --ff-only --no-autostash --no-overwrite-ignore -- "$source_commit" ||
    die "O fast-forward falhou. Verifique o diagnóstico do Git e o estado do checkout."
  [[ $(git rev-parse HEAD) == "$source_commit" ]] || die "O checkout mudou durante o fast-forward."
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
  printf 'Ambiente gráfico\n  1) KDE Plasma\n  2) XFCE\n'
  IFS= read -r -p 'Desktop [1/2, padrão 1]: ' desktop || die "Entrada interrompida."
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
  nix-instantiate --eval --strict --argstr options "$options" --argstr file "$file" "$@" --expr '
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
    builtins.deepSeq cfg true
  ' >/dev/null || die "Revise $file conforme config/local.example.nix e execute novamente."
}

publish() (
  set -euo pipefail
  umask 022
  unset TAR_OPTIONS
  local target=$1 expected=$2 parent stage tree keep_stage=false
  local previous="$1.previous"
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
  trap 'if ! $keep_stage; then rm -rf -- "$stage"; fi' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  tree=$stage/tree
  mkdir -- "$tree"
  tar --extract --file=- --directory="$tree" --no-same-owner --no-same-permissions ||
    die "Falha ao receber a árvore preparada."
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

show_next_steps() {
  printf '\nInstalação: %s\nConfiguração local: %s/config/local.nix\n' "$destination" "$destination"
  if [[ $destination == "$default_destination" ]]; then
    cat <<'INSTRUCTIONS'

Edite /etc/nixos/configuration.nix e inclua ./nixos-config/personal.nix na lista imports.
Remova os imports antigos deste projeto para evitar duplicações. Preserve os imports
de hardware e os demais ajustes da máquina.

Valide com:
  sudo nixos-rebuild dry-build

Somente depois de conferir o resultado, aplique manualmente com:
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
  printf 'Identidade Git configurada para %s.\n' "$username"
}

main() {
  local destination=$default_destination checkout parent expected=absent source_commit update_cancelled=false
  local username git_name git_email git_target tree entry mode file checkout_local root_script
  local identity_args=()
  case ${1:-} in
    '') [[ $# == 0 ]] || die "Uso: bash install.sh [--destination DIRETÓRIO]" ;;
    --help|-h) printf 'Uso: bash install.sh [--destination DIRETÓRIO]\n'; return ;;
    --destination) [[ $# == 2 && -n $2 ]] || die "Informe o destino alternativo."; destination=$2 ;;
    *) die "Uso: bash install.sh [--destination DIRETÓRIO]" ;;
  esac
  (( EUID != 0 )) || die "Execute o instalador pela sua conta normal, sem sudo."
  check_requirements
  checkout=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
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
  if [[ -e $destination || -L $destination ]]; then
    [[ -d $destination && ! -L $destination && -d $destination/config && ! -L $destination/config &&
       -f $destination/config/local.nix && ! -L $destination/config/local.nix ]] ||
      die "Instalação incompleta em $destination. Prepare config/local.nix como arquivo regular e execute novamente."
    expected=$(stat -c '%d:%i' -- "$destination")
  fi

  if [[ $expected == absent ]]; then
    read_identity
    [[ $(id -u -- "$username") == "$EUID" ]] ||
      die "Execute a primeira instalação pela própria conta Linux selecionada."
    git_target=$(git_config_target)
    identity_args=(--argstr username "$username" --argstr gitName "$git_name" --argstr gitEmail "$git_email")
  else
    printf 'A instalação existente preservará seu config/local.nix e a configuração global do Git.\n'
  fi
  if [[ $expected == absent ]]; then check_git_identity "$git_target"; fi
  [[ $(git rev-parse --show-toplevel) == "$checkout" ]] || die "Execute o script a partir de um checkout Git."
  confirm "Prosseguir com a verificação do repositório?" || { printf 'Instalação cancelada.\n'; return; }
  sync_checkout
  if "$update_cancelled"; then
    printf 'Atualização do checkout cancelada. Nenhuma cópia foi publicada.\n'
    return
  fi
  git check-ignore --quiet -- config/local.nix ||
    die "Inclua config/local.nix nas regras de exclusão do Git antes de continuar."

  prepared=$(mktemp -d)
  trap 'rm -rf -- "$prepared"; if [[ -n $new_local ]]; then rm -f -- "$new_local"; fi' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
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
      nix-instantiate --parse "$tree/$file" >/dev/null || die "Arquivo Nix inválido: $file."
    fi
  done < "$prepared/files"
  [[ -f $tree/personal.nix && -f $tree/config/options.nix && -f $tree/config/local.example.nix ]] ||
    die "O checkout atualizado está incompleto."

  checkout_local=$checkout/config/local.nix
  if [[ -e $checkout_local || -L $checkout_local ]]; then
    [[ -f $checkout_local && ! -L $checkout_local ]] || die "Use um arquivo regular em $checkout_local."
    validate_local "$tree/config/options.nix" "$checkout_local" "${identity_args[@]}"
  fi
  if [[ $expected != absent ]]; then
    validate_local "$tree/config/options.nix" "$destination/config/local.nix"
    cp -- "$destination/config/local.nix" "$tree/config/local.nix"
  else
    if [[ -f $checkout_local ]]; then
      cp -- "$checkout_local" "$tree/config/local.nix"
    else
      generate_local "$tree/config/local.example.nix" "$tree/config/local.nix"
    fi
  fi
  validate_local "$tree/config/options.nix" "$tree/config/local.nix" "${identity_args[@]}"

  confirm "Publicar a cópia em $destination?" || { printf 'Instalação cancelada.\n'; return; }
  if [[ ! -e $checkout_local && ! -L $checkout_local ]]; then
    new_local=$(mktemp -- "$checkout/config/.local.nix.XXXXXXXX")
    cat -- "$tree/config/local.nix" > "$new_local"
    ln -T -- "$new_local" "$checkout_local" || die "Falha ao criar $checkout_local. Preserve o arquivo existente."
    rm -- "$new_local"
    new_local=''
  fi

  tar -cf "$prepared/deployment.tar" -C "$tree" . || die "Falha ao preparar a cópia para publicação."
  if [[ $destination == "$default_destination" ]]; then
    root_script="PATH=$system_path"$'\n'
    root_script+=$(declare -f die publish)
    root_script+=$'\npublish "$@"'
    sudo -- /run/current-system/sw/bin/bash -p -c "$root_script" -- "$destination" "$expected" \
      < "$prepared/deployment.tar" || die "Falha na publicação. Confira a mensagem acima."
  else
    publish "$destination" "$expected" < "$prepared/deployment.tar"
  fi

  show_next_steps
  if [[ $expected == absent ]] && ! configure_git; then
    printf '\nA cópia foi instalada em %s. A configuração Git falhou.\n' "$destination" >&2
    printf 'Pela conta %s, confira os valores e execute somente os comandos pendentes:\n' "$username" >&2
    printf '  git config --global user.name %q\n  git config --global user.email %q\n  git config --global init.defaultBranch main\n' \
      "$git_name" "$git_email" >&2
    return 1
  fi
}

main "$@"
