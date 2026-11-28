{ config, ... }:

let
  inherit (config) personalConfig;
in
{
  imports = [
    ./core/config/options.nix
    ./config/local.nix
    ./applications.nix
    (import ./core/config/settings.nix ./settings.json)
    ./core/system/packages.nix
    ./core/services/fprintd.nix
    ./core/services/polkit.nix
    ./core/services/bluetooth.nix
    ./core/system/zram.nix
    ./core/services/keyd.nix
    ./core/system/maintenance.nix
    ./core/services/postgresql.nix
    ./core/applications/noir.nix
    ./core/system/fonts.nix
    ./core/optional/cron.nix
    ./core/optional/virtualization.nix
    ./core/optional/codex.nix
    ./core/optional/zsh-theme.nix
    ./core/desktops/kde.nix
    ./core/desktops/gnome.nix
    ./core/desktops/cinnamon.nix
  ];

  assertions = [
    {
      assertion = personalConfig.username != null
        && personalConfig.git.userName != null
        && personalConfig.git.userEmail != null;
      message = "Complete personalConfig.username, personalConfig.git.userName e personalConfig.git.userEmail em config/local.nix.";
    }
  ];
}
