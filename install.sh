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
--check-rollback avalia uma revisão preservada com o local.nix atual, sem publicar.
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

  [[ -d $target && ! -L $target && -d $target/revisions && ! -L $target/revisions &&
     -f $target/local.nix && ! -L $target/local.nix && -L $target/current ]] ||
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

write_new_local() {
  printf '{\n  personalConfig.desktop = "%s";\n}\n' "$1"
}

send_payload() {
  local include_local=$1 desktop=$2 file
  shift 2
  if [[ $include_local == yes ]]; then
    write_new_local "$desktop" | base64 -w0 && printf '\n' || return 1
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
      protected_dir "$target/revisions"
      protected_dir "$target/$previous"
      check_protected_permissions "$target/local.nix"
    fi
    [[ $(digest "$target/local.nix") == "$expected_local" ]] ||
      die "A configuração local mudou durante a preparação. Execute novamente."
  fi

  trap '[[ -z $revision_stage ]] || rm -rf -- "$revision_stage"
        [[ -z $stage ]] || rm -rf -- "$stage"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  if [[ -z $previous ]]; then
    stage=$(mktemp -d -- "$parent/.nixos-config.XXXXXXXX") || die "Não foi possível preparar $target."
    tree=$stage
    mkdir -- "$tree/revisions" || die "Não foi possível criar o diretório de revisões."
    receive_file "$tree/local.nix"
    [[ $(digest "$tree/local.nix") == "$expected_local" ]] ||
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
    if (( EUID == 0 )); then
      protected_dir "$release"
      protected_dir "$release/modules"
      for file; do
        protected_dir "$(dirname -- "$release/$file")"
        check_protected_permissions "$release/$file"
      done
    fi
  else
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
        desktopOption = evaluated.options.personalConfig.desktop or {};
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
        if (desktopOption.declarations or []) != [ (deployment + "/current/personal.nix") ]
          || !(builtins.elem (deployment + "/local.nix") (desktopOption.files or []))
        then throw "A configuração deve importar somente current/personal.nix e o módulo local por nixosConfigDeployment. A revisão precisa declarar personalConfig.desktop."
        else builtins.seq c.system.build.toplevel.drvPath
          (if profileMatches then selected else throw "Os serviços gráficos efetivos não correspondem ao perfil selecionado.")
    '
}

show_migration() {
  printf '\nUse no módulo da máquina o argumento nixosConfigDeployment descrito no README e o destino padrão %s.\n' "$destination"
  printf 'Preserve os outros imports, o hardware e system.stateVersion. Para XFCE, remova as ativações locais de Plasma e SDDM.\n'
  printf 'Revise e instale manualmente a cópia avaliada, se aplicável. Valide a configuração final com nixos-rebuild dry-build.\n'
}

main() {
  local cmd repo revision file entry mode local_hash manifest root_script use_sudo=false
  local checkout previous local_config desktop evaluated_desktop revision_directory
  local include_local=no configuration_hash

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
             stat chmod mv ln rm; do
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

  if [[ -n $rollback_revision ]]; then
    [[ -n $previous ]] || die "Não há instalação em $destination."
    revision_directory=$destination/revisions/$revision
    [[ -d $revision_directory && ! -L $revision_directory &&
       -f $revision_directory/personal.nix && ! -L $revision_directory/personal.nix ]] ||
      die "Revisão preservada ausente ou inválida: $revision_directory."
  else
    revision=$(git -C "$checkout" rev-parse --verify --end-of-options "$revision_ref^{commit}") ||
      die "A revisão $revision_ref não identifica um commit neste checkout."
    revision_directory=$prepared/source
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
  ln -s -- "$revision_directory" "$prepared/current" || die "Não foi possível preparar o link de avaliação."

  if [[ -n $previous ]]; then
    local_config=$destination/local.nix
    ln -s -- "$local_config" "$prepared/local.nix" || die "Não foi possível preparar o import local."
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
    local_config=$prepared/local.nix
    include_local=yes
    write_new_local "$desktop" > "$local_config" ||
      die "Não foi possível preparar o módulo local."
  fi
  local_hash=$(digest "$local_config") || die "Não foi possível verificar o módulo local."
  configuration_hash=$(digest "$configuration") || die "Não foi possível verificar o módulo da máquina."

  printf '\nRevisão avaliada: %s\nConfiguração avaliada: %s\nDestino: %s\nRevisão ativa: %s\n' \
    "$revision" "$configuration" "$destination" "${previous:-primeira instalação}"
  if [[ $include_local == yes ]]; then printf 'Módulo local a criar: %s/local.nix\n' "$destination"; fi
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
    printf 'Revisão já publicada. Nenhuma alteração necessária.\n'
  else
    local privilege='sem sudo'
    if "$use_sudo"; then privilege='com sudo'; fi
    confirm "Publicar em $destination $privilege?" || { printf 'Instalação cancelada.\n'; return; }
    [[ $(digest "$configuration") == "$configuration_hash" ]] ||
      die "O módulo da máquina mudou após a avaliação. Execute novamente."
    if "$use_sudo"; then
      root_script=$'PATH=/run/current-system/sw/bin:/run/wrappers/bin\n'
      root_script+=$(declare -f die digest inspect_deployment check_protected_permissions protected_dir \
        verify_release receive_file publish)
      root_script+=$'\npublish "$@"'
      send_payload "$include_local" "${desktop:-}" "${source_files[@]}" |
        sudo -- /run/current-system/sw/bin/bash -p -c "$root_script" -- \
          "$destination" "$revision" "$previous" "$local_hash" "$manifest" "${source_files[@]}" ||
        die "Publicação interrompida. Confira a revisão ativa em $destination/current."
    else
      send_payload "$include_local" "${desktop:-}" "${source_files[@]}" |
        publish "$destination" "$revision" "$previous" "$local_hash" "$manifest" "${source_files[@]}" ||
        die "Publicação interrompida. Confira a revisão ativa em $destination/current."
    fi
    printf 'Revisão publicada: %s\n' "$revision"
  fi

  if [[ -n $previous && $previous != "revisions/$revision" ]]; then
    printf 'Revisão preservada para recuperação: %s/%s\n' "$destination" "$previous"
  fi
  show_migration
}

main "$@"
