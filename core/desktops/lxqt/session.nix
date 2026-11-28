{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) wallpaper;
  inherit (pkgs) lxqt;
  inherit (lib) getExe getExe';
  copyq = pkgs.copyq.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./copyq-runtime-history.patch ];
  });
  kwinSettings = import ../kwin-settings.nix wallpaper;
  terminal = getExe' lxqt.qterminal "qterminal";
  noirEntry = ''
    [Desktop Entry]
    Type=Application
    Name=Noir
    Icon=utilities-terminal
    OnlyShowIn=LXQt;
    Exec=${terminal} -e /run/current-system/sw/bin/noir-session
    X-KDE-Shortcuts=Meta+N
  '';
  shortcut = name: exec: key: ''
    [Desktop Entry]
    Type=Application
    Name=${name}
    Exec=${exec}
    X-KDE-Shortcuts=${key}
  '';
  shortcutFiles = pkgs.linkFarm "noir-lxqt-shortcuts" {
    "share/applications/noir-configurator.desktop" = pkgs.writeText "noir-configurator.desktop" noirEntry;
    "share/kglobalaccel/noir-configurator.desktop" = pkgs.writeText "noir-configurator.desktop" noirEntry;
    "share/kglobalaccel/noir-lxqt-qps.desktop" = pkgs.writeText "noir-lxqt-qps.desktop"
      (shortcut "Monitor do sistema" (getExe' lxqt.qps "qps") "Meta+Esc");
    "share/kglobalaccel/noir-lxqt-terminal.desktop" = pkgs.writeText "noir-lxqt-terminal.desktop"
      (shortcut "Terminal" terminal "Ctrl+Alt+T");
    "share/kglobalaccel/noir-lxqt-menu.desktop" = pkgs.writeText "noir-lxqt-menu.desktop"
      (shortcut "Menu de aplicativos" "${getExe' lxqt.lxqt-wayland-session "lxqt-qdbus"} openmenu" "Meta");
  };

  # Formato de arrays do QSettings usado pelos dois plugins do painel.
  desktopArray = name: key: ids:
    lib.concatStringsSep "\n" (
      [ "${name}\\size=${toString (builtins.length ids)}" ]
      ++ lib.imap1 (i: id: "${name}\\${toString i}\\${key}=/run/current-system/sw/share/applications/${id}.desktop") ids
    );
  panel = lib.replaceStrings
    [ "@nixIcon@" "@favorites@" "@launchers@" ]
    [
      "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg"
      (desktopArray "favorites" "desktopFile" [
        "google-chrome" "lxqt-config" "pcmanfm-qt" "idea" "dbeaver" "code" "postman"
      ])
      (desktopArray "apps" "desktop" [
        "google-chrome" "idea" "code" "dbeaver" "pcmanfm-qt"
      ])
    ]
    (builtins.readFile ./panel.conf);
  gtkSettings = ''
    [Settings]
    gtk-theme-name=Breeze-Dark
    gtk-icon-theme-name=breeze-dark
    gtk-application-prefer-dark-theme=true
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "lxqt") {
    environment.systemPackages = [ shortcutFiles copyq ];
    programs.dconf.enable = true;
    programs.dconf.profiles.user.databases = [
      { lockAll = true; settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"; }
    ];

    environment.etc = {
      "xdg/kdeglobals".text = ''
        [General]
        ColorScheme[$i]=BreezeDark

        [Icons]
        Theme[$i]=breeze-dark

        [KDE]
        widgetStyle[$i]=Breeze
      '';
      "xdg/kwinrc".text = kwinSettings.desktops + "\n" + kwinSettings.plugins + "\n" + kwinSettings.windows;
      "xdg/kcminputrc".text = kwinSettings.input;
      "xdg/kscreenlockerrc".text = ''
        [Daemon]
        RequirePassword[$i]=true
        LockGrace[$i]=0
        LockOnResume[$i]=true

      '' + kwinSettings.locker;
      "xdg/gtk-3.0/settings.ini".text = gtkSettings;
      "xdg/gtk-4.0/settings.ini".text = gtkSettings;

      "xdg/lxqt/panel.conf".text = panel;
      "xdg/lxqt/session.conf".text = ''
        [General]
        compositor=kwin_wayland
        # O KScreenLocker coordena o bloqueio antes do repouso com o logind.
        lock_screen_before_power_actions=false
        cursor_theme=breeze_cursors
        cursor_size=24
      '';
      "xdg/lxqt/lxqt.conf".text = ''
        [General]
        theme=dark
        icon_theme=breeze-dark
        style=Breeze

        [Palette]
        window_color="#202226"
        window_text_color="#eff0f1"
        base_color="#17191c"
        text_color="#eff0f1"
        highlight_color="#3daee9"
        highlighted_text_color="#141619"
        link_color="#69bce8"
        link_visited_color="#b48ead"
        tooltip_base_color="#292c31"
        tooltip_text_color="#eff0f1"
      '';
      "xdg/pcmanfm-qt/lxqt/settings.conf".text = ''
        [Desktop]
        Wallpaper=${wallpaper}
        WallpaperMode=zoom
      '';
      "xdg/qterminal.org/qterminal.ini".text = ''
        [General]
        colorScheme=Linux
        fontFamily=JetBrainsMono Nerd Font
        fontSize=11
        MenuVisible=false
        ScrollbarPosition=0
        HideTabBarWithOneTab=true
        HistoryLimited=true
        HistoryLimitedTo=10000
      '';
      "xdg/lxqt-mimeapps.list".text = ''
        [Default Applications]
        x-scheme-handler/http=google-chrome.desktop;
        x-scheme-handler/https=google-chrome.desktop;
        text/html=google-chrome.desktop;
        inode/directory=pcmanfm-qt.desktop;
      '';
      "xdg/autostart/bitwarden.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Bitwarden
        Exec=bitwarden --autostart
        TryExec=bitwarden
        OnlyShowIn=LXQt;
      '';
      "xdg/autostart/nm-applet.desktop" = lib.mkIf config.networking.networkmanager.enable {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Rede
          Exec=${getExe' pkgs.networkmanagerapplet "nm-applet"} --indicator
          OnlyShowIn=LXQt;
          NoDisplay=true
          X-LXQt-Need-Tray=true
        '';
      };
    };

    systemd.user.services.noir-lxqt-clipboard = {
      description = "Histórico da área de transferência do LXQt";
      wantedBy = [ "noir-lxqt-session.target" ];
      partOf = [ "noir-lxqt-session.target" ];
      serviceConfig = {
        ExecStart = getExe copyq;
        RuntimeDirectory = "noir-lxqt-clipboard";
        RuntimeDirectoryMode = "0700";
        Environment = [
          "COPYQ_ITEM_DATA_PATH=%t/noir-lxqt-clipboard"
          "COPYQ_LOG_FILE=%t/noir-lxqt-clipboard/copyq.log"
        ];
      };
    };
    environment.etc."xdg/copyq/copyq.conf".text = ''
      [Options]
      maxitems=20
    '';
  };
}
