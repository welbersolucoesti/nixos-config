{ config, lib, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "kde") {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    assertions = [
      {
        assertion = !config.services.xserver.desktopManager.xfce.enable;
        message = "O perfil KDE requer que o XFCE esteja desabilitado nos módulos da máquina.";
      }
      {
        assertion = !config.services.xserver.displayManager.lightdm.enable;
        message = "O perfil KDE usa SDDM. Remova a ativação do LightDM dos módulos da máquina.";
      }
    ];
  };
}
