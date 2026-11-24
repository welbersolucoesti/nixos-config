{ config, lib, pkgs, ... }:

let
  plank = pkgs.plank.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./plank-default-launchers.patch ];
  });
  startPlank = pkgs.writeShellScript "xfce-noir-plank" ''
    [ "''${XDG_SESSION_TYPE:-}" = x11 ] && [ -n "''${DISPLAY:-}" ] || exit 0
    # O perfil inicial carrega o Docklike antes do autostart.
    layout=$(${lib.getExe' pkgs.xfconf "xfconf-query"} -c xfce4-panel -p /noir/docklike-layout 2>/dev/null)
    [ "$layout" != true ] || exit 0
    exec ${lib.getExe plank}
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    environment.systemPackages = [ plank ];
    services.dbus.packages = [ pkgs.bamf ];
    systemd.packages = [ pkgs.bamf ];

    environment.etc."xdg/autostart/plank.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Plank
      Exec=${startPlank}
      OnlyShowIn=XFCE;
    '';

    # Padrões sem bloqueio, abaixo do banco pessoal na ordem do dconf.
    programs.dconf.profiles.user.databases = lib.mkAfter [
      {
        settings."net/launchpad/plank/docks/dock1" = {
          position = "bottom";
          alignment = "center";
          hide-mode = "intelligent";
          icon-size = lib.gvariant.mkInt32 36;
          theme = "Default";
        };
      }
    ];
  };
}
