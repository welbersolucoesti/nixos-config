{ config, lib, pkgs, ... }:

let
  inherit (pkgs) kdePackages lxqt;
  inherit (lib) getExe getExe';
  systemctl = getExe' config.systemd.package "systemctl";
  updateActivationEnvironment = getExe' pkgs.dbus "dbus-update-activation-environment";
  sessionTarget = "noir-lxqt-session.target";
  sessionEnvironment = [
    "DISPLAY" "XAUTHORITY" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP" "XDG_SESSION_TYPE"
    "XDG_DATA_DIRS" "XDG_CONFIG_DIRS" "XDG_MENU_PREFIX" "QT_PLUGIN_PATH" "QT_QPA_PLATFORMTHEME"
  ];
  breezePluginPath = "${kdePackages.breeze}/${pkgs.qt6.qtbase.qtPluginPrefix}";
  migratePreferences = pkgs.writeShellScript "noir-lxqt-migrate-preferences" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.diffutils pkgs.gnused ]}
    ${builtins.readFile ./lxqt/migrate-preferences.sh}
  '';
  lockerQml = "${kdePackages.plasma-workspace}/${pkgs.qt6.qtbase.qtQmlPrefix}";
  # O KWin passa WAYLAND_DISPLAY e os dados do XWayland ao processo da sessão.
  desktop = pkgs.writeShellScript "noir-lxqt-desktop" ''
    set -e
    : "''${WAYLAND_DISPLAY:?KWin não informou WAYLAND_DISPLAY}"
    ${updateActivationEnvironment} --systemd ${lib.escapeShellArgs sessionEnvironment}
    ${systemctl} --user start ${sessionTarget}
    # Uma solicitação D-Bus anterior ao compositor pode ter sido recusada.
    ${systemctl} --user start --no-block xdg-desktop-portal.service

    ${migratePreferences} || printf '%s\n' 'Não foi possível migrar todas as preferências locais do LXQt.' >&2

    # Inicializa antes de o PCManFM-Qt consultar os diretórios da conta.
    userDirs="''${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    if [[ ! -e $userDirs && ! -L $userDirs ]]; then
      ${getExe pkgs.xdg-user-dirs} || true
    fi
    exec ${getExe' lxqt.lxqt-session "lxqt-session"}
  '';
  launch = pkgs.writeShellScript "noir-lxqt-wayland" ''
    set -e
    export XDG_CURRENT_DESKTOP=LXQt:kwin_wayland XDG_SESSION_TYPE=wayland XDG_MENU_PREFIX=lxqt-
    export QT_QPA_PLATFORMTHEME=lxqt
    export QT_PLUGIN_PATH=${lxqt.lxqt-qtplugin}/${pkgs.qt6.qtbase.qtPluginPrefix}:${breezePluginPath}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}
    export XDG_CONFIG_DIRS="''${XDG_CONFIG_DIRS:-/etc/xdg}:/run/current-system/sw/etc/xdg:/run/current-system/sw/share"
    export PATH="${lib.makeBinPath [ kdePackages.kwin ]}:$PATH"

    # O barramento do usuário e seus portais são compartilhados entre logins da mesma conta.
    exec 9>"''${XDG_RUNTIME_DIR:?}/noir-lxqt-session.lock"
    ${getExe' pkgs.util-linux "flock"} --nonblock 9

    compositor=
    cleanup() {
      if [[ -n $compositor ]]; then
        kill "$compositor" 2>/dev/null || true
        wait "$compositor" 2>/dev/null || true
      fi
      ${systemctl} --user stop ${sessionTarget} || true
      # O D-Bus permite substituir valores, mas não removê-los.
      ${updateActivationEnvironment} ${lib.escapeShellArgs (map (name: "${name}=") sessionEnvironment)} || true
      ${systemctl} --user unset-environment ${lib.escapeShellArgs sessionEnvironment} || true
    }
    trap cleanup EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT

    # O greeter herda do KWin o tema do Plasma Desktop e os imports do Workspace.
    XDG_DATA_DIRS="${kdePackages.plasma-desktop}/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    NIXPKGS_QT6_QML_IMPORT_PATH="${lockerQml}''${NIXPKGS_QT6_QML_IMPORT_PATH:+:$NIXPKGS_QT6_QML_IMPORT_PATH}" \
      ${getExe' kdePackages.kwin "kwin_wayland_wrapper"} --xwayland --exit-with-session ${desktop} 9>&- &
    compositor=$!
    status=0
    wait "$compositor" || status=$?
    compositor=
    exit "$status"
  '';
  session = (pkgs.writeTextDir "share/wayland-sessions/lxqt-wayland.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=LXQt (Wayland)
    Comment=LXQt com KWin Wayland
    Exec=${launch}
    TryExec=${launch}
    DesktopNames=LXQt;
  '').overrideAttrs (_: { passthru.providedSessions = [ "lxqt-wayland" ]; });

  panel = lxqt.lxqt-panel.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./lxqt/panel-layout.patch
      ./lxqt/panel-favorites.patch
    ];
    postPatch = (old.postPatch or "") + ''
      # O Nixpkgs passa CMAKE_INSTALL_BINDIR como caminho absoluto.
      substituteInPlace autostart/lxqt-panel_wayland.desktop.in \
        --replace-fail '@CMAKE_INSTALL_PREFIX@/@CMAKE_INSTALL_BINDIR@' '@CMAKE_INSTALL_FULL_BINDIR@'
    '';
    postInstall = (old.postInstall or "") + ''
      # O wrapper prioriza seu próprio XDG_CONFIG_DIRS. O padrão vem de /etc/xdg.
      rm "$out/etc/xdg/lxqt/panel.conf"
    '';
  });
  kdePortal = "plasma-xdg-desktop-portal-kde";
  portalUnits = [
    "xdg-desktop-portal"
    "xdg-desktop-portal-gtk"
    "xdg-desktop-portal-lxqt"
    kdePortal
  ];
in
{
  imports = [
    ./lxqt/session.nix
    ./lxqt/biometrics.nix
  ];

  config = lib.mkIf (config.personalConfig.desktop == "lxqt") {
    services.displayManager = {
      defaultSession = "lxqt-wayland";
      sessionPackages = [ session ];
      sddm = {
        enable = true;
        autoNumlock = true;
        wayland = {
          enable = true;
          compositor = "kwin";
        };
      };
    };

    assertions = [
      {
        assertion = !config.services.desktopManager.plasma6.enable
          && !config.services.desktopManager.gnome.enable
          && !config.services.xserver.desktopManager.cinnamon.enable
          && !config.services.xserver.desktopManager.lxqt.enable
          && config.services.displayManager.sessionPackages == [ session ]
          && config.services.displayManager.defaultSession == "lxqt-wayland";
        message = "O perfil LXQt do Noir requer somente a sessão lxqt-wayland. Remova sessões e módulos de desktop concorrentes da configuração da máquina.";
      }
      {
        assertion = !config.services.displayManager.gdm.enable
          && !config.services.xserver.displayManager.lightdm.enable;
        message = "O perfil LXQt usa SDDM. Remova a ativação de GDM ou LightDM dos módulos da máquina.";
      }
    ];

    services = {
      gvfs.enable = lib.mkDefault true;
      udisks2.enable = lib.mkDefault true;
      upower.enable = lib.mkDefault true;
      power-profiles-daemon.enable = lib.mkDefault true;
      pipewire = {
        enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };
    };

    programs.xwayland.enable = true;

    environment.pathsToLink = [ "/share" ];
    environment.systemPackages = (with lxqt; [
      lxqt-session pcmanfm-qt qterminal qps
      lxqt-config lxqt-menu-data lxqt-notificationd lxqt-powermanagement lxqt-qtplugin
      lxqt-themes pavucontrol-qt qtxdg-tools
    ]) ++ (with kdePackages; [
      kwin kscreen kscreenlocker kactivitymanagerd breeze breeze-icons breeze-gtk
      spectacle
    ]) ++ [
      panel
      pkgs.nixos-icons
      pkgs.blueman
      (lib.getBin pkgs.qt6.qttools)
    ] ++ lib.optional config.networking.networkmanager.enable pkgs.networkmanagerapplet;

    xdg.portal = {
      lxqt.enable = true;
      extraPortals = [ kdePackages.xdg-desktop-portal-kde pkgs.xdg-desktop-portal-gtk ];
      config.lxqt = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Access" = [ "lxqt" "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "lxqt" "gtk" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "kde" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "kde" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "kde" ];
      };
    };

    systemd.user.targets.noir-lxqt-session = {
      description = "Sessão LXQt do Noir";
      bindsTo = [ "graphical-session.target" ];
      before = [ "graphical-session.target" ];
    };

    # Mantém a identidade LXQt. A seleção interna das interfaces de captura ocorre no backend KDE.
    systemd.user.services = lib.genAttrs portalUnits (name: {
      overrideStrategy = "asDropin";
      partOf = [ sessionTarget ];
      # Requisite impede a ativação D-Bus de inicializar a sessão por conta própria.
      requisite = [ sessionTarget ];
      after = [ sessionTarget "graphical-session.target" ];
      serviceConfig = lib.optionalAttrs (name == kdePortal) {
        Environment = "XDG_CURRENT_DESKTOP=KDE";
      };
    });
  };
}
