{ config, lib, pkgs, ... }:

{
  # Interface Qt para os ambientes gerenciados pelo Distrobox.
  config = lib.mkIf config.personalConfig.virtualization.enable {
    environment.systemPackages = [ pkgs.kontainer ];
  };
}
