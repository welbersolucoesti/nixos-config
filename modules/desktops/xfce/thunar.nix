{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # O módulo NixOS do Thunar expõe a extensão ao gerenciador de arquivos existente.
    programs.thunar.plugins = [ pkgs.thunar-archive-plugin ];

    # A extensão delega a compactação e extração a um gerenciador de arquivos compactados.
    environment.systemPackages = [ pkgs.xarchiver ];
  };
}
