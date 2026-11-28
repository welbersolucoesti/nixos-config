{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) wallpaper;
  kwinSettings = import ../kwin-settings.nix wallpaper;
  wallpaperName = "Noir";
  wallpaperMetadata = pkgs.writeText "noir-wallpaper-metadata.json" (builtins.toJSON {
    KPackageStructure = "Wallpaper/Images";
    KPlugin = {
      Id = wallpaperName;
      Name = "Noir";
    };
  });
  theme = "org.noir.breezedark.desktop";
  themePath = "share/plasma/look-and-feel/${theme}";
  breezeDark = "${pkgs.kdePackages.plasma-workspace}/share/plasma/look-and-feel/org.kde.breezedark.desktop";
  themeMetadata = pkgs.writeText "noir-breeze-dark-metadata.json" (builtins.toJSON {
    KPackageStructure = "Plasma/LookAndFeel";
    KPlugin = {
      Id = theme;
      Name = "Breeze Dark (Noir)";
      Description = "Aparência Breeze Dark com o layout inicial do Noir";
      Authors = [ { Name = "KDE Visual Design Group"; } ];
    };
  });
  gtkSettings = ''
    [Settings]
    gtk-application-prefer-dark-theme=true
  '';
  # O identificador próprio evita que o wrapper do Plasma priorize o pacote original.
  themeWithLayout = pkgs.runCommand "noir-breeze-dark-layout" { } ''
    themeDir="$out/${themePath}"
    contents="$themeDir/contents"
    test -f "${breezeDark}/contents/defaults"
    mkdir -p "$contents/layouts"
    # O KPackage exige que os arquivos estejam dentro do diretório do tema.
    cp ${themeMetadata} "$themeDir/metadata.json"
    sed '/^\[Wallpaper\]$/,/^\[/ s/^Image=.*/Image=${wallpaperName}/' \
      "${breezeDark}/contents/defaults" > "$contents/defaults"
    grep -qx 'Image=${wallpaperName}' "$contents/defaults"
    cp -r "${breezeDark}/contents/previews" "$contents/previews"
    cp ${./layout.js} "$contents/layouts/org.kde.plasma.desktop-layout.js"

    # O plugin de imagem usa um pacote de wallpaper como padrão do tema.
    wallpaperDir="$out/share/wallpapers/${wallpaperName}"
    mkdir -p "$wallpaperDir/contents/images"
    cp ${wallpaperMetadata} "$wallpaperDir/metadata.json"
    cp ${wallpaper} "$wallpaperDir/contents/images/${baseNameOf wallpaper}"
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "kde") {
    environment.systemPackages = [ themeWithLayout ];

    systemd.user.services.noir-plasma-wallpaper = {
      description = "Aplicar o wallpaper do Noir ao Plasma";
      wantedBy = [ "plasma-plasmashell.service" ];
      after = [ "plasma-plasmashell.service" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe' pkgs.kdePackages.plasma-workspace "plasma-apply-wallpaperimage"} ${wallpaper}";
      };
    };

    environment.etc = {
      "xdg/kdeglobals".text = ''
        [General]
        ColorScheme[$i]=BreezeDark

        [Icons]
        Theme[$i]=breeze-dark

        [KDE]
        LookAndFeelPackage[$i]=${theme}
        widgetStyle[$i]=Breeze
      '';

      "xdg/plasmarc".text = ''
        [Theme]
        name[$i]=default
      '';

      "xdg/kwinrc".text = kwinSettings.desktops + "\n" + kwinSettings.plugins + "\n" + kwinSettings.windows;

      # O modelo do KDE usa essa lista ao importar os favoritos de um lançador novo.
      "xdg/kicker-extra-favoritesrc".text = ''
        [General]
        IgnoreDefaults=true
        Prepend=preferred://browser;systemsettings.desktop;org.kde.dolphin.desktop;idea.desktop;dbeaver.desktop;code.desktop;postman.desktop;
      '';

      "xdg/kde-mimeapps.list".text = ''
        [Default Applications]
        x-scheme-handler/http=google-chrome.desktop;
        x-scheme-handler/https=google-chrome.desktop;
        text/html=google-chrome.desktop;
      '';

      "xdg/gtk-3.0/settings.ini".text = gtkSettings;
      "xdg/gtk-4.0/settings.ini".text = gtkSettings;

      # Mesmo nome usado pelo Bitwarden para que a entrada pessoal tenha precedência.
      "xdg/autostart/bitwarden.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Bitwarden
        Exec=bitwarden --autostart
        TryExec=bitwarden
        OnlyShowIn=KDE;
      '';

      "xdg/kscreenlockerrc".text = kwinSettings.locker;

      "xdg/kglobalshortcutsrc".text = ''
        [noir-configurator.desktop]
        _launch[$i]=Meta+N,Meta+N,Noir
      '';
    };

    programs.dconf.profiles.user.databases = [
      { lockAll = true; settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"; }
    ];
  };
}
