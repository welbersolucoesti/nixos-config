{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) username;
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
}
