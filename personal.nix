{ config, ... }:

let
  inherit (config) personalConfig;
in
{
  imports = [
    ./config/options.nix
    ./config/local.nix
    (import ./config/noir-optionals.nix ./config/optionals.json)
    ./modules/applications/firefox.nix
    # A ordem destes imports mantém a precedência anterior na lista de pacotes do sistema.
    ./modules/applications/temurin.nix
    ./modules/applications/onlyoffice.nix
    ./modules/applications/postman.nix
    ./modules/applications/vscode.nix
    ./modules/applications/dbeaver.nix
    ./modules/applications/intellij.nix
    ./modules/applications/bitwarden.nix
    ./modules/applications/chrome.nix
    ./modules/system/packages.nix
    ./modules/services/fprintd.nix
    ./modules/services/polkit.nix
    ./modules/services/bluetooth.nix
    ./modules/system/zram.nix
    ./modules/services/keyd.nix
    ./modules/system/maintenance.nix
    ./modules/services/postgresql.nix
    ./modules/applications/zsh.nix
    ./modules/applications/terminal.nix
    ./modules/applications/noir.nix
    ./modules/applications/vim.nix
    ./modules/system/fonts.nix
    ./modules/optional/cron.nix
    ./modules/optional/virtualization.nix
    ./modules/optional/codex.nix
    ./modules/optional/zsh-theme.nix
    ./modules/desktops/numlock.nix
    ./modules/desktops/launcher-icon.nix
    ./modules/desktops/kde.nix
    ./modules/desktops/xfce.nix
    ./modules/desktops/cinnamon.nix
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
