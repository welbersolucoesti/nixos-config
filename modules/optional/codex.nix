{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.personalConfig.codex.enable {
    environment.systemPackages = [
      (import ./codex-package.nix { inherit pkgs; })
    ];
  };
}
