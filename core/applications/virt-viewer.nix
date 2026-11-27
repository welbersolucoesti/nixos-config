{ config, lib, pkgs, ... }:

{
  # Cliente de console para as máquinas virtuais do conjunto de virtualização.
  config = lib.mkIf config.personalConfig.virtualization.enable {
    environment.systemPackages = [ pkgs.virt-viewer ];
  };
}
