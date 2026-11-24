{ config, lib, pkgs, ... }:

let
  wallpaperSource = config.personalConfig.kde.wallpaperSource;
  wallpapers = pkgs.kdePackages.plasma-workspace-wallpapers;
  coldRipple = "${wallpapers}/share/wallpapers/ColdRipple";
  wallpaperOverride = "/run/noir-kde-wallpaper";
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
    set -- "${coldRipple}"/contents/images/*
    if ! test -s "${coldRipple}/metadata.json" || ! test -s "$1"; then
      echo "KDE Noir: recurso ColdRipple indisponível em plasma-workspace-wallpapers." >&2
      exit 1
    fi
    mkdir -p "$contents/layouts"
    # O KPackage exige que os arquivos estejam dentro do diretório do tema.
    cp ${themeMetadata} "$themeDir/metadata.json"
    sed '/^\[Wallpaper\]$/,/^\[/ s/^Image=.*/Image=ColdRipple/' \
      "${breezeDark}/contents/defaults" > "$contents/defaults"
    grep -qx 'Image=ColdRipple' "$contents/defaults"
    cp -r "${breezeDark}/contents/previews" "$contents/previews"
    cp ${./layout.js} "$contents/layouts/org.kde.plasma.desktop-layout.js"
  '';
in
{
  options.personalConfig.kde.wallpaperSource = lib.mkOption {
    type = lib.types.nullOr (lib.types.strMatching "/[^[:cntrl:]]+");
    default = null;
    description = ''
      Caminho absoluto, como string, de um PNG local legível pela conta configurada.
      Use null para aplicar o ColdRipple fornecido pelo Plasma.
    '';
  };

  config = lib.mkIf (config.personalConfig.desktop == "kde") {
    environment.systemPackages = [ themeWithLayout wallpapers ];

    assertions = [
      {
        assertion = wallpaperSource == null || (
          builtins.pathExists wallpaperSource && !builtins.pathExists (wallpaperSource + "/.")
        );
        message = "personalConfig.kde.wallpaperSource deve apontar para um arquivo PNG existente e acessível, ou ser null para usar ColdRipple.";
      }
    ];

    # Valida o conteúdo local fora da construção, sem copiar a imagem para o store.
    system.activationScripts.noir-kde-wallpaper = lib.mkIf (wallpaperSource != null) {
      deps = [ "etc" ];
      text = ''
      (
        source=${lib.escapeShellArg wallpaperSource}
        target=${lib.escapeShellArg coldRipple}
        if [ -f "$source" ] && ${lib.getExe' pkgs.util-linux "runuser"} -u ${lib.escapeShellArg config.personalConfig.username} -- \
          ${lib.getExe' (lib.getDev pkgs.libpng) "pngfix"} -q -q "$source"; then
          target="$source"
        else
          printf '%s\n' 'KDE Noir: personalConfig.kde.wallpaperSource não é um PNG válido ou legível pela conta configurada. Usando ColdRipple.' >&2
        fi
        ${lib.getExe' pkgs.coreutils "ln"} -sfnT -- "$target" ${lib.escapeShellArg wallpaperOverride}
      )
      '';
    };

    environment.etc = {
      "xdg/kdeglobals".text = ''
        [General]
        ColorScheme=BreezeDark

        [Icons]
        Theme=breeze-dark

        [KDE]
        LookAndFeelPackage=${theme}
        widgetStyle=Breeze
      '';

      "xdg/plasmarc".text = ''
        [Theme]
        name=default
      '';

      "xdg/kwinrc".text = ''
        [Desktops]
        Number=2
        Rows=1
        Name_1=Work 1
        Name_2=Work 2

        [Plugins]
        glideEnabled=true
        magiclampEnabled=true
        scaleEnabled=false
        squashEnabled=false

        [Windows]
        RollOverDesktops=false
      '';

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

      "noir/kde-wallpaper.png".source = if wallpaperSource == null then coldRipple else wallpaperOverride;

      "xdg/kscreenlockerrc".text = ''
        [Greeter][Wallpaper][org.kde.image][General]
        Image=file:///etc/noir/kde-wallpaper.png
      '';
    };

    programs.dconf.profiles.user.databases = [
      { settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"; }
    ];
  };
}
