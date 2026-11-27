{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) defaultWallpaper;
  wallpaperSource = config.personalConfig.cinnamon.wallpaperSource;
  wallpaperOverride = "/run/noir-cinnamon-wallpaper";
  terminalCommand = "${lib.getExe pkgs.gnome-terminal} -- /run/current-system/sw/bin/noir-session";
  shortcutId = "custom1000";
  # IDs estáveis e distintos dos IDs normalmente criados por uma instalação padrão.
  applets = [
    "panel2:left:0:menu@cinnamon.org:1000"
    "panel2:left:1:separator@cinnamon.org:1001"
    "panel2:left:2:windows-quick-list@cinnamon.org:1002"
    "panel2:center:0:calendar@cinnamon.org:1003"
    "panel2:right:0:systray@cinnamon.org:1004"
    "panel2:right:1:xapp-status@cinnamon.org:1005"
    "panel2:right:2:notifications@cinnamon.org:1006"
    "panel2:right:3:printers@cinnamon.org:1007"
    "panel2:right:4:network@cinnamon.org:1008"
    "panel2:right:5:sound@cinnamon.org:1009"
    "panel2:right:6:power@cinnamon.org:1010"
    "panel2:right:7:workspace-switcher@cinnamon.org:1011"
    "panel2:right:8:show-desktop@cinnamon.org:1012"
    "panel1:center:0:grouped-window-list@cinnamon.org:1013"
  ];
in
{
  config = lib.mkIf (config.personalConfig.desktop == "cinnamon") {
    services.xserver.desktopManager.cinnamon.extraGSettingsOverrides = ''
      [org.cinnamon]
      # O painel 1 permanece embaixo, como no padrão da Cinnamon.
      panels-enabled=['1:0:bottom', '2:0:top']
      panels-height=['1:42', '2:38']
      panels-autohide=['1:intel', '2:false']
      enabled-applets=${builtins.toJSON applets}
      next-applet-id=1014
      favorite-apps=['google-chrome.desktop', 'cinnamon-settings.desktop', 'nemo.desktop', 'idea.desktop', 'dbeaver.desktop', 'code.desktop', 'postman.desktop']
      desktop-effects-map='fly'
      desktop-effects-minimize='traditional'

      [org.cinnamon.theme]
      name='Mint-Y-Dark-Aqua'

      [org.cinnamon.desktop.interface]
      gtk-theme='Mint-Y-Dark-Aqua'
      icon-theme='Mint-Y-Aqua'
      cursor-theme='Bibata-Modern-Classic'
      cursor-size=24
      clock-show-date=false

      [org.x.apps.portal]
      color-scheme='prefer-dark'

      [org.cinnamon.desktop.background]
      picture-uri='file:///etc/noir/cinnamon-wallpaper'
      picture-options='zoom'

      [org.nemo.desktop]
      show-desktop-icons=false

      [org.cinnamon.desktop.wm.preferences]
      num-workspaces=2
      workspace-names=['Work 1', 'Work 2']

      [org.cinnamon.muffin]
      dynamic-workspaces=false
      workspace-cycle=false

      [org.cinnamon.desktop.peripherals.keyboard]
      remember-numlock-state=false

      [org.cinnamon.desktop.peripherals.touchpad]
      natural-scroll=true

      [org.cinnamon.desktop.keybindings]
      custom-list=['${shortcutId}']
      looking-glass-keybinding=[]

      [org.cinnamon.desktop.keybindings.media-keys]
      screensaver=['<Super>l', '<Control><Alt>l', 'XF86ScreenSaver']

      [org.gnome.Terminal.Legacy.Settings]
      default-show-menubar=false

      [org.gnome.Terminal.Legacy.Profile]
      scrollbar-policy='never'
    '';

    programs.dconf.profiles.user.databases = [
      {
        settings = {
          "org/cinnamon/cinnamon-session".auto-save-session = false;
          "org/cinnamon/desktop/keybindings/custom-keybindings/${shortcutId}" = {
            name = "Noir";
            binding = [ "<Super>n" ];
            command = terminalCommand;
          };
        };
        locks = [ "/org/cinnamon/cinnamon-session/auto-save-session" ];
      }
    ];

    programs.gnome-terminal.enable = true;

    environment.systemPackages = [
      (pkgs.writeTextDir "share/applications/noir-configurator.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=Noir
        Icon=utilities-terminal
        OnlyShowIn=X-Cinnamon;
        Exec=${terminalCommand}
      '')
    ];

    environment.etc = {
      "noir/cinnamon-wallpaper".source = if wallpaperSource == null then defaultWallpaper else wallpaperOverride;

      "xdg/x-cinnamon-mimeapps.list".text = ''
        [Default Applications]
        x-scheme-handler/http=google-chrome.desktop;
        x-scheme-handler/https=google-chrome.desktop;
        text/html=google-chrome.desktop;
        inode/directory=nemo.desktop;
      '';

      "xdg/autostart/bitwarden.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Bitwarden
        Exec=bitwarden --autostart
        TryExec=bitwarden
        OnlyShowIn=X-Cinnamon;
      '';
    };

    # Verifica o arquivo somente na ativação, com leitura pela conta configurada.
    system.activationScripts.noir-cinnamon-wallpaper = lib.mkIf (wallpaperSource != null) {
      deps = [ "etc" "users" ];
      text = ''
        (
          source=${lib.escapeShellArg wallpaperSource}
          target=${lib.escapeShellArg "${defaultWallpaper}"}
          if [ -f "$source" ] && [ ! -L "$source" ] && \
            ${lib.getExe' pkgs.util-linux "runuser"} -u ${lib.escapeShellArg config.personalConfig.username} -- \
            ${lib.getExe' (lib.getDev pkgs.libpng) "pngfix"} -q -q "$source"; then
            target="$source"
          else
            printf '%s\n' 'Cinnamon Noir: fundo local indisponível ou PNG inválido. Usando o padrão do Noir.' >&2
          fi
          ${lib.getExe' pkgs.coreutils "ln"} -sfnT -- "$target" ${wallpaperOverride}
        )
      '';
    };
  };
}
