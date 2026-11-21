{ config, lib, ... }:

let
  localConfig = ./config/local.nix;
  hasLocalConfig = builtins.pathExists localConfig;
  inherit (config) personalConfig;
in
{
  imports = [
    ./config/options.nix
    ./modules/system/packages.nix
    ./modules/system/hardware.nix
    ./modules/system/maintenance.nix
    ./modules/system/postgresql.nix
    ./modules/personal.nix
    ./modules/optional/cron.nix
    ./modules/optional/virtualization.nix
    ./modules/optional/zsh-theme.nix
    ./modules/desktops/kde.nix
    ./modules/desktops/xfce.nix
  ] ++ lib.optional hasLocalConfig localConfig;

  assertions = lib.optional hasLocalConfig {
    assertion = personalConfig.username != null
      && personalConfig.git.userName != null
      && personalConfig.git.userEmail != null;
    message = "Complete personalConfig.username, personalConfig.git.userName e personalConfig.git.userEmail em config/local.nix.";
  };
}
