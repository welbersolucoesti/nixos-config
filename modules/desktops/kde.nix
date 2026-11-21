{ config, lib, ... }:

{
  # O perfil mantém o Plasma com SDDM. As asserções sinalizam conflito com XFCE ou LightDM.
  config = lib.mkIf (config.personalConfig.desktop == "kde") {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    # O KConfig bloqueia somente a restauração da sessão, inclusive em contas existentes.
    environment.etc."xdg/ksmserverrc".text = ''
      [General]
      loginMode[$i]=emptySession
    '';

    environment.etc."xdg/kcminputrc".text = ''
      [Keyboard]
      NumLock=0

      [Libinput][Defaults][Touchpad]
      NaturalScroll=true
    '';

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
