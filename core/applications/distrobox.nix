{ config, lib, pkgs, ... }:

{
  # Usa o Podman para criar ambientes de desenvolvimento integrados à sessão.
  config = lib.mkIf config.personalConfig.virtualization.enable {
    environment.systemPackages = [ pkgs.distrobox ];
  };
}
