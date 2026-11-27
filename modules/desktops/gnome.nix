{ config, lib, pkgs, ... }:

let
  extensions = with pkgs.gnomeExtensions; [ dash-to-dock clipboard-indicator appindicator ];
  terminalCommand = "${lib.getExe pkgs.gnome-terminal} -- /run/current-system/sw/bin/noir-session";
  mediaKeys = "org/gnome/settings-daemon/plugins/media-keys";
  noirShortcut = "${mediaKeys}/custom-keybindings/noir";
  terminalSettings = "org/gnome/terminal/legacy";
  # UUID do perfil inicial definido no schema do GNOME Terminal.
  terminalProfile = "${terminalSettings}/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
  wallpaper = "noir/gnome-wallpaper.png";
  wallpaperUri = "file:///etc/${wallpaper}";
  keyboardSettings."org/gnome/desktop/peripherals/keyboard" = {
    remember-numlock-state = true;
    numlock-state = true;
  };
in
{
  config = lib.mkIf (config.personalConfig.desktop == "gnome") {
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;
    services.displayManager.defaultSession = "gnome";
    programs.gnome-terminal.enable = true;

    environment.systemPackages = extensions ++ [
      (pkgs.writeTextDir "share/applications/noir-configurator.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=Noir
        Icon=utilities-terminal
        OnlyShowIn=GNOME;
        Exec=${terminalCommand}
      '')
    ];

    programs.dconf.profiles.user.databases = [
      {
        settings = keyboardSettings // {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            accent-color = "blue";
          };
          "org/gnome/desktop/wm/preferences".button-layout = ":maximize,close";
          "org/gnome/desktop/background" = {
            picture-uri = wallpaperUri;
            picture-uri-dark = wallpaperUri;
            picture-options = "zoom";
          };
          "org/gnome/desktop/screensaver".picture-uri = wallpaperUri;
          "org/gnome/shell".enabled-extensions = map (extension: extension.extensionUuid) extensions;
          "org/gnome/shell/extensions/dash-to-dock" = {
            dock-position = "BOTTOM";
            extend-height = false;
            dock-fixed = false;
            intellihide = true;
          };
          "org/gnome/shell/extensions/clipboard-indicator" = {
            # Limita as gravações. A extensão ainda grava o item recém-copiado e imagens.
            cache-only-favorites = true;
            enable-keybindings = false;
          };
          "${mediaKeys}".custom-keybindings = [ "/${noirShortcut}/" ];
          "${noirShortcut}" = {
            name = "Noir";
            binding = "<Super>n";
            command = terminalCommand;
          };
          "${terminalSettings}".default-show-menubar = false;
          "${terminalProfile}".scrollbar-policy = "never";
        };
      }
    ];
    programs.dconf.profiles.gdm.databases = lib.mkBefore [ { settings = keyboardSettings; } ];

    environment.etc = {
      "${wallpaper}".source = config.personalConfig.defaultWallpaper;

      "xdg/gnome-mimeapps.list".text = ''
        [Default Applications]
        x-scheme-handler/http=google-chrome.desktop;
        x-scheme-handler/https=google-chrome.desktop;
        text/html=google-chrome.desktop;
        inode/directory=org.gnome.Nautilus.desktop;
      '';

      "xdg/autostart/bitwarden.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Bitwarden
        Exec=bitwarden --autostart
        TryExec=bitwarden
        OnlyShowIn=GNOME;
      '';
    };

    assertions = [
      {
        assertion = !config.services.desktopManager.plasma6.enable
          && !config.services.xserver.desktopManager.cinnamon.enable
          && !config.services.xserver.desktopManager.xfce.enable;
        message = "O perfil GNOME requer que KDE Plasma, Cinnamon e XFCE estejam desabilitados nos módulos da máquina.";
      }
      {
        assertion = !config.services.displayManager.sddm.enable
          && !config.services.xserver.displayManager.lightdm.enable;
        message = "O perfil GNOME usa GDM. Remova a ativação de SDDM ou LightDM dos módulos da máquina.";
      }
    ];
  };
}
