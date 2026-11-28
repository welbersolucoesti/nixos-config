{ config, lib, pkgs, ... }:

let
  inherit (pkgs) kdePackages qt6;
  usersKcm = pkgs.runCommand "noir-lxqt-users-kcm" {
    nativeBuildInputs = [ qt6.wrapQtAppsHook ];
    buildInputs = with kdePackages; [
      plasma-workspace kcmutils kirigami kirigami-addons qqc2-desktop-style
    ] ++ [ qt6.qtbase qt6.qtdeclarative qt6.qtwayland ];
  } ''
    mkdir -p "$out/bin" "$out/share/applications"
    test -f "${kdePackages.plasma-workspace}/${qt6.qtbase.qtPluginPrefix}/plasma/kcms/systemsettings/kcm_users.so"
    makeQtWrapper "${lib.getExe' kdePackages.kcmutils "kcmshell6"}" "$out/bin/noir-lxqt-users" \
      --set QT_QUICK_CONTROLS_STYLE org.kde.desktop \
      --add-flags kcm_users
    cat > "$out/share/applications/noir-lxqt-users.desktop" <<DESKTOP
    [Desktop Entry]
    Type=Application
    Name=Usuários e impressões digitais
    Icon=preferences-system-users
    Exec=$out/bin/noir-lxqt-users
    OnlyShowIn=LXQt;
    Categories=Settings;DesktopSettings;LXQt;
    DESKTOP
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "lxqt") {
    services.accounts-daemon.enable = true;

    environment.systemPackages = [
      kdePackages.plasma-workspace
      pkgs.lxqt.lxqt-policykit
      usersKcm
    ];

    security.pam.services = {
      # Mantém os demais módulos de login e desativa a tentativa serial apenas no SDDM.
      sddm.rules.auth = lib.mkForce (lib.mapAttrs (name: rule: {
        inherit (rule) order control modulePath args;
        enable = rule.enable && name != "fprintd";
      }) config.security.pam.services.login.rules.auth);
      kde = {
        fprintAuth = false;
        p11Auth = false;
      };
      kde-fingerprint = {
        inherit (config.services.fprintd) enable;
        fprintAuth = true;
        unixAuth = false;
        p11Auth = false;
      };
    };
  };
}
