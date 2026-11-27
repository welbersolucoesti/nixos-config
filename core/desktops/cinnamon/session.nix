{ config, lib, pkgs, ... }:

let
  wallpaperUri = "file://${config.personalConfig.wallpaper}";
  restoreList = import ../restore-gsettings-list.nix { inherit lib pkgs; };
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
      # Contador interno. A Cinnamon usa esse valor para alocar novas instâncias.
      next-applet-id=1014

      [org.cinnamon.desktop.keybindings]
      custom-list=['${shortcutId}']

      [org.gnome.Terminal.Legacy.Settings]
      default-show-menubar=false

      [org.gnome.Terminal.Legacy.Profile]
      scrollbar-policy='never'
    '';

    programs.dconf.profiles.user.databases = [
      {
        lockAll = true;
        settings = {
          "org/cinnamon" = {
            panels-enabled = [ "1:0:bottom" "2:0:top" ];
            panels-height = [ "1:42" "2:38" ];
            panels-autohide = [ "1:intel" "2:false" ];
            enabled-applets = applets;
            favorite-apps = [
              "google-chrome.desktop" "cinnamon-settings.desktop" "nemo.desktop"
              "idea.desktop" "dbeaver.desktop" "code.desktop" "postman.desktop"
            ];
            desktop-effects-map = "fly";
            desktop-effects-minimize = "traditional";
          };
          "org/cinnamon/theme".name = "Mint-Y-Dark-Aqua";
          "org/cinnamon/desktop/interface" = {
            gtk-theme = "Mint-Y-Dark-Aqua";
            icon-theme = "Papirus-XApp-Dark";
            cursor-theme = "Bibata-Modern-Classic";
            cursor-size = lib.gvariant.mkInt32 24;
            clock-show-date = false;
          };
          "org/x/apps/portal".color-scheme = "prefer-dark";
          "org/cinnamon/desktop/background" = {
            picture-uri = wallpaperUri;
            picture-options = "zoom";
          };
          "org/cinnamon/desktop/background/slideshow".slideshow-enabled = false;
          "org/nemo/desktop".show-desktop-icons = false;
          "org/cinnamon/desktop/wm/preferences" = {
            num-workspaces = lib.gvariant.mkInt32 2;
            workspace-names = [ "Work 1" "Work 2" ];
          };
          "org/cinnamon/muffin" = {
            dynamic-workspaces = false;
            workspace-cycle = false;
          };
          "org/cinnamon/desktop/peripherals/keyboard".remember-numlock-state = false;
          "org/cinnamon/desktop/peripherals/touchpad".natural-scroll = true;
          "org/cinnamon/desktop/keybindings".looking-glass-keybinding =
            lib.gvariant.mkEmptyArray lib.gvariant.type.string;
          "org/cinnamon/desktop/keybindings/media-keys".screensaver = [ "<Super>l" "<Control><Alt>l" "XF86ScreenSaver" ];
          "org/cinnamon/cinnamon-session".auto-save-session = false;
          "org/gnome/terminal/legacy".default-show-menubar = false;
          "org/cinnamon/desktop/keybindings/custom-keybindings/${shortcutId}" = {
            name = "Noir";
            binding = [ "<Super>n" ];
            command = terminalCommand;
          };
        };
      }
    ];

    programs.gnome-terminal.enable = true;

    environment.systemPackages = [
      pkgs.papirus-icon-theme
      (pkgs.callPackage ./papirus-xapp-dark.nix { })
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
      "xdg/autostart/noir-preferences.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Preferências do Noir
        Exec=${restoreList} org.cinnamon.desktop.keybindings custom-list ${shortcutId}
        OnlyShowIn=X-Cinnamon;
        NoDisplay=true
      '';

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

  };
}
