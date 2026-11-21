{ config, lib, ... }:

{
  imports = [
    ./xfce/appearance.nix
    ./xfce/bluetooth.nix
    ./xfce/compositor.nix
    ./xfce/login.nix
    ./xfce/mugshot.nix
    ./xfce/panel.nix
    ./xfce/shortcuts.nix
    ./xfce/thunar.nix
  ];

  # O perfil seleciona a sessão X11 e deixa áudio, rede e energia a cargo da máquina e do NixOS.
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.xfce.enable = true;

    assertions = [
      {
        assertion = !config.services.desktopManager.plasma6.enable;
        message = "O perfil XFCE requer que o Plasma esteja desabilitado nos módulos da máquina.";
      }
      {
        assertion = !config.services.displayManager.sddm.enable;
        message = "O perfil XFCE usa LightDM. Remova a ativação do SDDM dos módulos da máquina.";
      }
    ];
  };
}
