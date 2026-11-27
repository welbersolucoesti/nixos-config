{ config, lib, pkgs, ... }:

{
  imports = [ ./kde/session.nix ];

  # O perfil mantém o Plasma com SDDM. As asserções sinalizam conflito com XFCE ou LightDM.
  config = lib.mkIf (config.personalConfig.desktop == "kde") {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    # O KGlobalAccel carrega os atalhos configurados antes dos padrões de aplicativos.
    environment.systemPackages = [ (pkgs.writeTextDir "share/applications/noir-configurator.desktop" ''
      [Desktop Entry]
      Type=Application
      Name=Noir
      Icon=utilities-terminal
      OnlyShowIn=KDE;
      Exec=${lib.getExe pkgs.kdePackages.konsole} --separate -e /run/current-system/sw/bin/noir-session
      X-KDE-Shortcuts=Meta+N
    '') ];

    # O KConfig bloqueia somente a restauração da sessão, inclusive em contas existentes.
    environment.etc."xdg/ksmserverrc".text = ''
      [General]
      loginMode[$i]=emptySession
    '';

    environment.etc."xdg/kcminputrc".text = ''
      [Keyboard]
      NumLock[$i]=0

      [Mouse]
      cursorTheme[$i]=breeze_cursors
      cursorSize[$i]=24

      [Libinput][Defaults][Touchpad]
      NaturalScroll[$i]=true
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
