{ config, lib, ... }:

{
  # Runtime do conjunto opcional. Os contêineres são criados e iniciados à parte.
  config = lib.mkIf config.personalConfig.virtualization.enable {
    virtualisation.podman.enable = true;
  };
}
