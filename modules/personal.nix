{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) username;
in
{
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

  users.users = lib.optionalAttrs (username != null) {
    ${username}.shell = pkgs.zsh;
  };
}
