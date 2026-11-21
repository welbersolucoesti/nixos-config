#!/usr/bin/env bash
set -euo pipefail
umask 022

default_destination=/etc/nixos/nixos-config
destination=$default_destination
configuration=/etc/nixos/configuration.nix
revision_ref=''
rollback_revision=''

source_files=(
  personal.nix
  config/options.nix config/local.example.nix
  modules/personal.nix
  modules/desktops/kde.nix modules/desktops/xfce.nix
  modules/system/hardware.nix modules/system/maintenance.nix
  modules/system/packages.nix modules/system/postgresql.nix
  modules/optional/cron.nix modules/optional/virtualization.nix modules/optional/zsh-theme.nix
)

die() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Uso: bash install.sh [--revision REV | --check-rollback HASH] [--configuration ARQUIVO] [--destination DIRETÓRIO]

Publica os módulos de um commit Git. O padrão é HEAD, com avaliação de
/etc/nixos/configuration.nix e publicação em /etc/nixos/nixos-config.
--configuration seleciona a configuração revisada com os imports da implantação.
--check-rollback avalia uma revisão preservada com o config/local.nix atual, sem publicar.
--destination usa um diretório alternativo sem sudo.
EOF
}

confirm() {
  local answer
  read -r -p "$1 [s/N] " answer && [[ $answer == [sS] ]]
}

digest() {
  local checksum
  checksum=$(sha256sum < "$1") || return
  printf '%s\n' "${checksum%% *}"
}

inspect_deployment() {
  local target=$1 link
  if [[ ! -e $target && ! -L $target ]]; then
    printf '\n'
    return
  fi

  if [[ ! -e $target/config/local.nix && -f $target/local.nix ]]; then
    die "Layout anterior encontrado em $target/local.nix. Preserve o arquivo e prepare manualmente $target/config/local.nix com a identidade. Consulte a migração no README."
  fi
  [[ -d $target && ! -L $target && -d $target/revisions && ! -L $target/revisions &&
     -d $target/config && ! -L $target/config &&
     -f $target/config/local.nix && ! -L $target/config/local.nix && -L $target/current ]] ||
    die "Instalação anterior incompleta ou layout desconhecido em $target. Revise o diretório antes de continuar."
  link=$(readlink -- "$target/current") || die "Não foi possível ler $target/current."
  [[ $link =~ ^revisions/([0-9a-f]{40}|[0-9a-f]{64})$ &&
     -d $target/$link && ! -L $target/$link &&
     -f $target/$link/personal.nix && ! -L $target/$link/personal.nix ]] ||
    die "Revisão ativa inválida em $target/current."
  printf '%s\n' "$link"
}

check_protected_permissions() {
  local metadata owner mode
  metadata=$(stat -c '%u %a' -- "$1") || die "Não foi possível verificar as permissões de $1."
  read -r owner mode <<< "$metadata"
  [[ $owner == 0 ]] && (( (8#$mode & 022) == 0 )) ||
    die "$1 deve pertencer a root e permitir escrita apenas ao proprietário."
}

protected_dir() {
  [[ -d $1 && ! -L $1 ]] || die "Diretório protegido inválido: $1."
  check_protected_permissions "$1"
}

verify_release() {
  local release=$1 manifest=$2 file
  shift 2
  [[ -d $release && ! -L $release ]] || die "Caminho de revisão inválido: $release."
  for file; do
    [[ -f $release/$file && ! -L $release/$file ]] || die "Arquivo de revisão inválido: $file."
  done
  (cd -- "$release" && sha256sum --check --status <<< "$manifest") ||
    die "O conteúdo da revisão não corresponde ao commit aprovado."
}

verify_local_link() {
  [[ -d $1/config && ! -L $1/config &&
     -L $1/config/local.nix && $(readlink -- "$1/config/local.nix") == "$2" ]] ||
    die "Revisão incompatível: $1 não referencia a configuração persistente esperada em $2."
}

nix_string() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//\$\{/\\\$\{}
  printf '"%s"' "$value"
}

write_new_local() {
  printf '{\n  personalConfig = {\n    desktop = %s;\n    username = %s;\n    git = {\n      userName = %s;\n      userEmail = %s;\n    };\n  };\n}\n' \
    "$(nix_string "$desktop")" "$(nix_string "$username")" \
    "$(nix_string "$git_name")" "$(nix_string "$git_email")"
}

valid_username() {
  local LC_ALL=C
  [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

read_identity() {
  local suggested
  suggested=$(id -un) || die "Não foi possível identificar a conta da sessão."
  if valid_username "$suggested"; then
    IFS= read -r -p "Conta Linux existente [$suggested]: " username || die "Entrada da conta interrompida."
    username=${username:-$suggested}
  else
    IFS= read -r -p "Conta Linux existente: " username || die "Entrada da conta interrompida."
  fi
  valid_username "$username" ||
    die "Nome de conta inválido. Use até 32 caracteres, iniciando por letra minúscula ou _, seguidos por minúsculas, números, _ ou -."
  [[ $username == "$suggested" ]] ||
    die "Execute a primeira instalação pela própria conta Linux selecionada."
  IFS= read -r -p "Nome para autoria Git: " git_name || die "Entrada do nome Git interrompida."
  IFS= read -r -p "E-mail para autoria Git: " git_email || die "Entrada do e-mail Git interrompida."
  [[ $git_name != *[[:cntrl:]]* && $git_email != *[[:cntrl:]]* ]] ||
    die "A identidade Git deve ser informada sem caracteres de controle."
}

trusted_git_path() {
  local item=$1 kind=$2 mode
  while :; do
    if [[ -e $item || -L $item ]]; then
      [[ ! -L $item && -O $item ]] || return 1
      if [[ $kind == directory ]]; then
        [[ -d $item ]] || return 1
      else
        [[ -f $item && -r $item ]] || return 1
      fi
      mode=$(stat -c %a -- "$item") || return 1
      (( (8#$mode & 022) == 0 )) || return 1
    fi
    [[ $item == "$git_home" ]] && return 0
    item=${item%/*}
    kind=directory
  done
}

git_user_config() {
  HOME="$git_home" XDG_CONFIG_HOME="$git_xdg" git -C "$prepared" config --global "$@"
}

prepare_git_config() {
  local variable entry account uid passwd_home origin key status=0
  local -A seen=()
  for variable in GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM \
                  GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR \
                  GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL; do
    [[ ! -v $variable ]] || die "Remova $variable do ambiente antes da primeira instalação."
  done
  entry=$(getent passwd "$EUID") || die "Não foi possível consultar a conta Linux executora."
  IFS=: read -r account _ uid _ _ passwd_home _ <<< "$entry"
  [[ $account == "$username" && $uid == "$EUID" && $passwd_home == /* && ${HOME:-} == /* ]] ||
    die "A conta efetiva ou HOME não corresponde à configuração da conta selecionada."
  git_home=$(realpath -e -- "$passwd_home") && [[ $git_home != / && -d $git_home &&
    $(realpath -e -- "$HOME") == "$git_home" ]] ||
    die "HOME deve apontar para o diretório pessoal da conta selecionada."
  git_xdg=${XDG_CONFIG_HOME:-$git_home/.config}
  [[ $git_xdg == /* ]] || die "XDG_CONFIG_HOME deve ser um caminho absoluto dentro de HOME."
  git_xdg=$(realpath -ms -- "$git_xdg") || die "XDG_CONFIG_HOME inválido."
  [[ $git_xdg == "$git_home/"* ]] ||
    die "XDG_CONFIG_HOME deve ficar dentro do diretório pessoal da conta selecionada."

  local dotfile=$git_home/.gitconfig xdgfile=$git_xdg/git/config
  trusted_git_path "$dotfile" file && trusted_git_path "$xdgfile" file ||
    die "Configuração Git global em caminho inseguro. Revise a propriedade, as permissões e os links sob HOME."
  git_target=$dotfile
  if [[ ! -e $dotfile && -f $xdgfile ]]; then git_target=$xdgfile; fi
  [[ -w ${git_target%/*} && ( ! -e $git_target || -w $git_target ) ]] ||
    die "O destino global do Git não permite gravação pela conta selecionada: $git_target."

  # Só lemos as origens e as chaves, sem copiar seus valores para o diagnóstico.
  git_user_config --includes --show-origin --null --name-only \
    --get-regexp '^(user\.(name|email)|init\.defaultbranch)$' > "$prepared/git-origins" 2>/dev/null || status=$?
  (( status <= 1 )) || die "O Git não conseguiu ler a configuração global. Revise os arquivos e includes."
  while IFS= read -r -d '' origin && IFS= read -r -d '' key; do
    [[ ( $origin == "file:$dotfile" || $origin == "file:$xdgfile" ) && ! -v "seen[$key]" ]] ||
      die "Configuração Git em conflito para $key. Revise includes e definições duplicadas antes da instalação."
    seen[$key]=1
  done < "$prepared/git-origins"
}

apply_git_config() {
  local index key effective
  local keys=(user.name user.email init.defaultBranch)
  local values=("$git_name" "$git_email" main)
  printf 'Publicação concluída. Aplicando a identidade Git em %s.\n' "$git_target"
  for index in "${!keys[@]}"; do
    key=${keys[index]}
    if ! trusted_git_path "$git_target" file ||
       ! GIT_CONFIG_GLOBAL="$git_target" git_user_config -- "$key" "${values[index]}" 2>/dev/null; then
      printf 'Erro ao gravar %s. A revisão permanece publicada. As chaves posteriores ficaram pendentes.\n' "$key" >&2
      return 1
    fi
    if ! effective=$(git_user_config --includes --get "$key" 2>/dev/null) || [[ $effective != "${values[index]}" ]]; then
      printf 'A chave %s foi gravada, mas seu valor efetivo não pôde ser confirmado. A revisão permanece publicada. As chaves posteriores ficaram pendentes.\n' "$key" >&2
      return 1
    fi
    printf 'Git: %s gravada e verificada.\n' "$key"
  done
}

send_payload() {
  local include_local=$1 file
  shift
  if [[ $include_local == yes ]]; then
    write_new_local | base64 -w0 && printf '\n' || return 1
  fi
  for file; do
    git -C "$checkout" cat-file blob "$revision:$file" | base64 -w0 && printf '\n' || return 1
  done
}

receive_file() {
  local encoded
  IFS= read -r encoded || die "Conteúdo incompleto para $1."
  printf '%s' "$encoded" | base64 --decode > "$1" ||
    die "Conteúdo inválido para $1."
}

publish() (
  set -euo pipefail
  umask 022
  local target=$1 revision=$2 expected_previous=$3 expected_local=$4 manifest=$5
  shift 5
  local parent previous stage='' revision_stage='' tree release file extra
  parent=${target%/*}

  if (( EUID == 0 )); then
    [[ $target == /etc/nixos/nixos-config ]] || die "Destino administrativo inválido."
    protected_dir /etc
    protected_dir "$parent"
  fi

  # O bloqueio é compartilhado pelas execuções do instalador, sem criar um arquivo.
  exec 9< "$parent"
  flock -x 9 || die "Não foi possível bloquear $parent para publicar."
  previous=$(inspect_deployment "$target") || exit 1
  [[ $previous == "$expected_previous" ]] ||
    die "A revisão ativa mudou durante a preparação. Execute novamente."

  if [[ -n $previous ]]; then
    if (( EUID == 0 )); then
      protected_dir "$target"
      protected_dir "$target/config"
      protected_dir "$target/revisions"
      protected_dir "$target/$previous"
      check_protected_permissions "$target/config/local.nix"
    fi
    [[ $(digest "$target/config/local.nix") == "$expected_local" ]] ||
      die "A configuração local mudou durante a preparação. Execute novamente."
  fi

  trap '[[ -z $revision_stage ]] || rm -rf -- "$revision_stage"
        [[ -z $stage ]] || rm -rf -- "$stage"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  if [[ -z $previous ]]; then
    stage=$(mktemp -d -- "$parent/.nixos-config.XXXXXXXX") || die "Não foi possível preparar $target."
    tree=$stage
    mkdir -- "$tree/revisions" "$tree/config" || die "Não foi possível criar os diretórios da implantação."
    receive_file "$tree/config/local.nix"
    [[ $(digest "$tree/config/local.nix") == "$expected_local" ]] ||
      die "O módulo local recebido diverge do conteúdo aprovado."
  else
    stage=$(mktemp -d -- "$target/.install.XXXXXXXX") || die "Não foi possível preparar a troca de revisão."
    tree=$target
  fi

  release=$tree/revisions/$revision
  revision_stage=$(mktemp -d -- "$tree/revisions/.prepare.XXXXXXXX") ||
    die "Não foi possível preparar os arquivos da revisão."
  for file; do
    mkdir -p -- "$revision_stage/$(dirname -- "$file")" ||
      die "Não foi possível preparar o diretório de $file."
    receive_file "$revision_stage/$file"
  done
  extra=''
  if IFS= read -r extra || [[ -n $extra ]]; then
    die "Foram recebidos dados além dos arquivos aprovados."
  fi
  verify_release "$revision_stage" "$manifest" "$@"

  if [[ -e $release || -L $release ]]; then
    verify_release "$release" "$manifest" "$@"
    verify_local_link "$release" "$target/config/local.nix"
    if (( EUID == 0 )); then
      protected_dir "$release"
      protected_dir "$release/modules"
      for file; do
        protected_dir "$(dirname -- "$release/$file")"
        check_protected_permissions "$release/$file"
      done
    fi
  else
    ln -s -- "$target/config/local.nix" "$revision_stage/config/local.nix" ||
      die "Não foi possível apontar a revisão para a configuração persistente."
    chmod 0755 -- "$revision_stage" || die "Não foi possível ajustar as permissões da revisão."
    mv -Tn -- "$revision_stage" "$release" && [[ ! -e $revision_stage ]] ||
      die "Falha ao gravar a revisão completa."
    revision_stage=''
  fi

  ln -s -- "revisions/$revision" "$stage/current" || die "Não foi possível preparar o link da revisão."
  if [[ -z $previous ]]; then
    chmod 0755 -- "$stage" || die "Não foi possível ajustar as permissões da implantação."
    mv -Tn -- "$stage" "$target" && [[ ! -e $stage ]] ||
      die "Falha ao publicar a instalação."
  else
    [[ $(digest "$target/config/local.nix") == "$expected_local" ]] ||
      die "O módulo local mudou antes da troca de revisão."
    mv -Tf -- "$stage/current" "$target/current" ||
      die "Falha ao trocar a revisão ativa. A revisão anterior continua em uso."
  fi
)

evaluate_candidate() {
  nix-instantiate --eval --strict --json \
    --argstr host "$configuration" --argstr deployment "$prepared" --argstr target "$destination" \
    --expr '
      { host, deployment, target }:
      let
        evaluated = import (<nixpkgs> + "/nixos/lib/eval-config.nix") {
          modules = [ (builtins.toPath host) ];
          specialArgs.nixosConfigDeployment = installedPath:
            if toString installedPath == target
            then builtins.toPath deployment
            else throw "O destino declarado no módulo da máquina difere do destino selecionado no instalador.";
        };
        c = evaluated.config;
        options = evaluated.options.personalConfig or {};
        localPath = deployment + "/current/config/local.nix";
        fromLocal = option: (option.files or []) == [ localPath ];
        selected = c.personalConfig.desktop;
        kde = selected == "kde";
        profileMatches =
          (kde || selected == "xfce")
          && c.services.xserver.enable
          && c.services.desktopManager.plasma6.enable == kde
          && c.services.displayManager.sddm.enable == kde
          && c.services.xserver.desktopManager.xfce.enable == !kde
          && c.services.xserver.displayManager.lightdm.enable == !kde;
      in
        if (options.desktop.declarations or []) != [ (deployment + "/current/config/options.nix") ]
        then throw "Importe current/personal.nix via nixosConfigDeployment. A revisão deve declarar as opções em config/options.nix."
        else if !(builtins.all fromLocal [
          (options.desktop or {}) (options.username or {})
          (options.git.userName or {}) (options.git.userEmail or {})
        ]) || c.personalConfig.username == null || c.personalConfig.git.userName == null
           || c.personalConfig.git.userEmail == null
        then throw "Defina desktop, username, git.userName e git.userEmail em config/local.nix. Remova imports diretos do módulo local e definições duplicadas da configuração da máquina."
        else builtins.seq c.system.build.toplevel.drvPath
          (if profileMatches then selected else throw "Os serviços gráficos efetivos não correspondem ao perfil selecionado.")
    '
}

show_migration() {
  printf '\nUse no módulo da máquina o argumento nixosConfigDeployment descrito no README e o destino padrão %s.\n' "$destination"
  printf 'Importe somente current/personal.nix da implantação. Complete a identidade em config/local.nix no destino e retire imports diretos do arquivo local.\n'
  printf 'Preserve os outros imports, o hardware e system.stateVersion. Para XFCE, remova as ativações locais de Plasma e SDDM.\n'
  printf 'Revise e instale manualmente a cópia avaliada, se aplicável. Valide a configuração final com nixos-rebuild dry-build.\n'
}

publish_protected() {
  local root_script=$'PATH=/run/current-system/sw/bin:/run/wrappers/bin\n'
  root_script+=$(declare -f die digest inspect_deployment check_protected_permissions protected_dir \
    verify_release verify_local_link receive_file publish)
  root_script+=$'\npublish "$@"'
  sudo -- /run/current-system/sw/bin/bash -p -c "$root_script" -- "$@"
}

main() {
  local cmd repo revision file entry mode local_hash manifest use_sudo=false
  local checkout previous local_config desktop username git_name git_email evaluated_desktop revision_directory
  local include_local=no configuration_hash git_home git_xdg git_target configure_git=false

  while (( $# > 0 )); do
    case $1 in
      --help|-h) usage; return ;;
      --revision|--configuration|--destination|--check-rollback)
        (( $# >= 2 )) && [[ -n $2 && $2 != --* ]] || die "$1 requer um valor."
        case $1 in
          --revision) revision_ref=$2 ;;
          --configuration) configuration=$2 ;;
          --destination) destination=$2 ;;
          --check-rollback) rollback_revision=$2 ;;
        esac
        shift 2
        ;;
      *) die "Opção desconhecida: $1. Consulte --help." ;;
    esac
  done

  if [[ -n $rollback_revision ]]; then
    [[ -z $revision_ref && $rollback_revision =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] ||
      die "Use --check-rollback com o hash completo de uma revisão preservada, sem --revision."
  fi
  revision_ref=${revision_ref:-HEAD}
  (( EUID != 0 )) || die "Execute o instalador com sua conta normal, sem sudo."
  [[ -r /etc/os-release ]] && grep -Eq '^ID="?nixos"?$' /etc/os-release ||
    die "Este instalador requer NixOS."
  for cmd in git grep nix-instantiate realpath dirname readlink mktemp sha256sum base64 flock mkdir \
             stat chmod mv ln rm id; do
    command -v "$cmd" >/dev/null || die "Comando necessário ausente: $cmd."
  done
  nix-instantiate --find-file nixpkgs >/dev/null ||
    die "Nixpkgs não encontrado no NIX_PATH. Verifique o canal ou a revisão da máquina."

  checkout=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) ||
    die "Não foi possível localizar o checkout."
  repo=$(git -C "$checkout" rev-parse --show-toplevel) &&
    [[ $repo == "$checkout" ]] || die "Execute o script a partir de um checkout deste repositório."
  configuration=$(realpath -se -- "$configuration") && [[ -f $configuration && -r $configuration ]] ||
    die "Configuração da máquina ausente ou ilegível."
  destination=$(realpath -ms -- "$destination") || die "Destino de publicação inválido."
  [[ $destination != / && $destination != "$checkout" && $destination != "$checkout/"* &&
     -d ${destination%/*} &&
     $destination =~ ^/[a-zA-Z0-9._/-]+$ ]] ||
    die "Use um destino fora do checkout, com diretório pai existente e caminho sem espaços."
  if [[ -n $rollback_revision ]]; then
    revision=$rollback_revision
  elif [[ $destination == "$default_destination" ]]; then
    command -v sudo >/dev/null || die "O destino protegido requer sudo."
    [[ -x /run/current-system/sw/bin/bash ]] || die "Bash do sistema indisponível para publicar."
    use_sudo=true
  else
    [[ -w ${destination%/*} ]] || die "O destino alternativo requer um diretório pai gravável."
  fi
  previous=$(inspect_deployment "$destination") || exit 1

  prepared=$(mktemp -d) || die "Não foi possível criar a área de preparação."
  trap 'rm -rf -- "$prepared"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  mkdir -- "$prepared/revisions" || die "Não foi possível preparar o diretório de revisões."
  if [[ -n $rollback_revision ]]; then
    [[ -n $previous ]] || die "Não há instalação em $destination."
    revision_directory=$destination/revisions/$revision
    [[ -d $revision_directory && ! -L $revision_directory &&
       -f $revision_directory/personal.nix && ! -L $revision_directory/personal.nix ]] ||
      die "Revisão preservada ausente ou inválida: $revision_directory."
    verify_local_link "$revision_directory" "$destination/config/local.nix"
    ln -s -- "$revision_directory" "$prepared/revisions/$revision" ||
      die "Não foi possível preparar a revisão preservada."
  else
    revision=$(git -C "$checkout" rev-parse --verify --end-of-options "$revision_ref^{commit}") ||
      die "A revisão $revision_ref não identifica um commit neste checkout."
    revision_directory=$prepared/revisions/$revision
    for file in "${source_files[@]}"; do
      entry=$(git -C "$checkout" ls-tree "$revision" -- "$file") || die "Falha ao consultar $file."
      mode=${entry%% *}
      [[ $mode == 100644 || $mode == 100755 ]] || die "Arquivo regular ausente no commit: $file."
      mkdir -p -- "$revision_directory/$(dirname -- "$file")"
      git -C "$checkout" cat-file blob "$revision:$file" > "$revision_directory/$file" ||
        die "Falha ao preparar $file da revisão $revision."
    done
    manifest=$(cd -- "$revision_directory" && sha256sum -- "${source_files[@]}") ||
      die "Não foi possível calcular a integridade dos arquivos."
  fi
  ln -s -- "revisions/$revision" "$prepared/current" || die "Não foi possível preparar o link de avaliação."

  if [[ -n $previous ]]; then
    local_config=$destination/config/local.nix
    ln -s -- "$destination/config" "$prepared/config" || die "Não foi possível preparar o import local."
    printf 'Instalação encontrada em %s. Módulo local preservado: %s.\n' "$destination" "$local_config"
  else
    printf 'Escolha o ambiente gráfico.\n  1) KDE Plasma\n  2) XFCE\n'
    read -r -p 'Desktop [1/2, Enter cancela]: ' desktop || desktop=''
    case $desktop in
      1) desktop=kde ;;
      2) desktop=xfce ;;
      '') printf 'Instalação cancelada.\n'; return ;;
      *) die "Escolha 1 para KDE Plasma ou 2 para XFCE." ;;
    esac
    read_identity
    mkdir -- "$prepared/config" || die "Não foi possível preparar a configuração local."
    local_config=$prepared/config/local.nix
    include_local=yes
    write_new_local > "$local_config" ||
      die "Não foi possível preparar o módulo local."
  fi
  if [[ -z $rollback_revision ]]; then
    ln -s -- "$prepared/config/local.nix" "$revision_directory/config/local.nix" ||
      die "Não foi possível preparar o vínculo local da revisão."
  fi
  local_hash=$(digest "$local_config") || die "Não foi possível verificar o módulo local."
  configuration_hash=$(digest "$configuration") || die "Não foi possível verificar o módulo da máquina."

  printf '\nRevisão avaliada: %s\nConfiguração avaliada: %s\nDestino: %s\nRevisão ativa: %s\n' \
    "$revision" "$configuration" "$destination" "${previous:-primeira instalação}"
  if [[ $include_local == yes ]]; then
    printf 'Conta Linux: %s\nMódulo local a criar: %s/config/local.nix\n' \
      "$username" "$destination"
  fi
  if ! evaluated_desktop=$(evaluate_candidate); then
    if [[ -n $rollback_revision ]]; then
      die "Rollback não validado com a configuração e o módulo local atuais. Mantenha current até resolver o erro acima."
    fi
    show_migration >&2
    die "A configuração candidata falhou. Use --configuration com a cópia revisada da configuração da máquina."
  fi
  [[ $(digest "$configuration") == "$configuration_hash" && $(digest "$local_config") == "$local_hash" ]] ||
    die "A configuração da máquina ou o módulo local mudou durante a avaliação. Execute novamente."
  printf 'Avaliação Nix concluída. Desktop: %s.\n' "${evaluated_desktop//\"/}"

  if [[ -n $rollback_revision ]]; then
    printf 'A revisão preservada foi avaliada com o módulo local atual. O link current não foi alterado.\n'
    return
  fi
  verify_release "$revision_directory" "$manifest" "${source_files[@]}"

  if [[ $previous == "revisions/$revision" ]]; then
    verify_release "$destination/$previous" "$manifest" "${source_files[@]}"
    verify_local_link "$destination/$previous" "$destination/config/local.nix"
    printf 'Revisão já publicada. Nenhuma alteração necessária.\n'
  else
    local privilege='sem sudo'
    if "$use_sudo"; then privilege='com sudo'; fi
    local confirmation="Publicar em $destination $privilege?"
    if [[ $include_local == yes ]]; then
      printf 'Nome Git: %s\nE-mail Git: informado na coleta\nBranch inicial: main\n' "$git_name"
      if "$use_sudo"; then
        command -v getent >/dev/null || die "Comando necessário ausente: getent."
        prepare_git_config
        configure_git=true
        printf 'Destino global do Git: %s\n' "$git_target"
        confirmation="Publicar em $destination $privilege e, depois, configurar o Git desta conta?"
      else
        printf 'Destino alternativo. A identidade fica registrada apenas no módulo local.\n'
      fi
    fi
    confirm "$confirmation" || { printf 'Instalação cancelada.\n'; return; }
    [[ $(digest "$configuration") == "$configuration_hash" ]] ||
      die "O módulo da máquina mudou após a avaliação. Execute novamente."
    if "$use_sudo"; then
      send_payload "$include_local" "${source_files[@]}" |
        publish_protected \
          "$destination" "$revision" "$previous" "$local_hash" "$manifest" "${source_files[@]}" ||
        die "Publicação interrompida. Confira a revisão ativa em $destination/current."
    else
      send_payload "$include_local" "${source_files[@]}" |
        publish "$destination" "$revision" "$previous" "$local_hash" "$manifest" "${source_files[@]}" ||
        die "Publicação interrompida. Confira a revisão ativa em $destination/current."
    fi
    printf 'Revisão publicada: %s\n' "$revision"
    if "$configure_git"; then
      apply_git_config || { show_migration; exit 1; }
      printf 'Identidade Git configurada.\n'
    fi
  fi

  if [[ -n $previous && $previous != "revisions/$revision" ]]; then
    printf 'Revisão preservada para recuperação: %s/%s\n' "$destination" "$previous"
  fi
  show_migration
}

main "$@"
