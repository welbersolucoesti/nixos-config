{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) username;
  initZshrc = ''
    set -eu
    zshrc="$1/.zshrc"
    if [[ -e "$zshrc" || -L "$zshrc" ]]; then exit 0; fi

    umask 077
    temp=$(${pkgs.coreutils}/bin/mktemp -- "$1/.zshrc.XXXXXXXX")
    trap '${pkgs.coreutils}/bin/rm -f -- "$temp"' EXIT

    # Publica o arquivo vazio sem substituir um caminho criado em paralelo.
    if ! ${pkgs.coreutils}/bin/ln -T -- "$temp" "$zshrc"; then
      [[ -e "$zshrc" || -L "$zshrc" ]]
    fi
  '';
in
{
  # Os recursos do shell ficam disponíveis mesmo com o tema opcional desativado.
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    ohMyZsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
    };
  };

  # Só troca o shell da conta escolhida. UID e diretório pessoal vêm da máquina.
  users.users = lib.optionalAttrs (username != null) {
    ${username}.shell = pkgs.zsh;
  };

  system.activationScripts.personalZshrc = lib.mkIf (username != null) {
    deps = [ "users" "etc" ];
    text = ''
      ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg username} -- \
        ${pkgs.bash}/bin/bash -c ${lib.escapeShellArg initZshrc} -- \
        ${lib.escapeShellArg config.users.users.${username}.home}
    '';
  };
}
