{ config, lib, ... }:

{
  # Usa a integração NixOS do cliente gráfico para administrar máquinas do libvirt.
  config = lib.mkIf config.personalConfig.virtualization.enable {
    programs.virt-manager.enable = true;
  };
}
