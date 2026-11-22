{ config, lib, pkgs, ... }:

let
  loginctl = "${config.systemd.package}/bin/loginctl";
  isXfceX11 = pkgs.writeShellScript "picom-xfce-x11" ''
    [[ -n ''${XDG_SESSION_ID:-} && -n ''${DISPLAY:-} ]] || exit 1

    session_property() {
      ${loginctl} show-session "$XDG_SESSION_ID" --property="$1" --value
    }

    [[ "$(session_property Desktop)" == xfce &&
       "$(session_property Type)" == x11 &&
       "$(session_property Display)" == "''${DISPLAY%%.*}" ]]
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    services.picom = {
      enable = true;
      backend = "xrender";
      vSync = true;
      fade = false;
      shadow = false;
      activeOpacity = 1.0;
      inactiveOpacity = 1.0;
      wintypes = { };
      opacityRules = [ ];
    };

    # O LightDM importa a sessão e o display antes de iniciar graphical-session.target.
    systemd.user.services.picom.serviceConfig.ExecCondition = isXfceX11;
  };
}
