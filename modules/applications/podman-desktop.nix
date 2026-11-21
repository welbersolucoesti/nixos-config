{ config, lib, pkgs, ... }:

{
  # Interface gráfica para inspecionar imagens e contêineres Podman.
  config = lib.mkIf config.personalConfig.virtualization.enable {
    environment.systemPackages = [ pkgs.podman-desktop ];
  };
}
