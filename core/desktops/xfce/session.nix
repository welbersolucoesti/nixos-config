{ config, lib, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    environment.etc = {
      "xdg/xfce-mimeapps.list".text = ''
        [Default Applications]
        x-scheme-handler/http=google-chrome.desktop;
        x-scheme-handler/https=google-chrome.desktop;
        text/html=google-chrome.desktop;
      '';

      # O auxiliar WebBrowser também tem sua própria configuração editável.
      "xdg/xfce4/helpers.rc".text = ''
        WebBrowser=google-chrome
        MailReader=thunderbird
        TerminalEmulator=xfce4-terminal
        FileManager=thunar
      '';

      # Uma entrada pessoal com o mesmo nome tem precedência no autostart XDG.
      "xdg/autostart/bitwarden.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Bitwarden
        Exec=bitwarden --autostart
        TryExec=bitwarden
        OnlyShowIn=XFCE;
      '';
    };

    # Qt 5 e 6 fornecem o tema de plataforma GTK. Respeita configuração de sessão da conta.
    services.xserver.displayManager.sessionCommands = ''
      if [ "''${XDG_SESSION_DESKTOP:-}" = xfce ]; then
        : "''${QT_QPA_PLATFORMTHEME=gtk3}"
        export QT_QPA_PLATFORMTHEME
      fi
    '';
  };
}
