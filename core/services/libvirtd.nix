{ config, lib, ... }:

{
  config = lib.mkIf config.personalConfig.virtualization.enable {
    virtualisation.libvirtd.enable = true;

    # O grupo permite administrar recursos do libvirt. A associação vale só para a conta escolhida.
    users.users = lib.optionalAttrs (config.personalConfig.username != null) {
      ${config.personalConfig.username}.extraGroups = [ "libvirtd" ];
    };
  };
}
