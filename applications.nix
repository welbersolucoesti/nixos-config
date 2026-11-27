{ pkgs, ... }:

{
  imports = [
    ./core/applications/firefox.nix
    ./core/applications/temurin.nix
    ./core/applications/onlyoffice.nix
    ./core/applications/postman.nix
    ./core/applications/vscode.nix
    ./core/applications/dbeaver.nix
    ./core/applications/intellij.nix
    ./core/applications/bitwarden.nix
    ./core/applications/chrome.nix
    ./core/applications/zsh.nix
    ./core/applications/terminal.nix
    ./core/applications/vim.nix
  ];

  environment.systemPackages = with pkgs; [
    wget
    usbutils
    git
    htop
    pv
    inkscape
    gimp
    fastfetch
  ];
}
