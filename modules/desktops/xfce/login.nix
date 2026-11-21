{ config, lib, pkgs, ... }:

let
  fingerprintSettings = {
    max-tries = lib.mkDefault 1;
    timeout = lib.mkDefault 10;
  };
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    services.xserver.displayManager.lightdm = {
      background = "#1c1d22";
      greeters.gtk = import ./theme.nix pkgs // {
        clock-format = "%H:%M";
        indicators = [ "~spacer" "~clock" "~spacer" "~session" "~a11y" "~power" ];
        extraConfig = ''
          user-background = false
        '';
      };
    };
    services.displayManager.defaultSession = lib.mkDefault "xfce";

    # O LightDM já usa a pilha login, que herda a biometria de services.fprintd.enable.
    # Limita a espera pela digital antes da senha nas duas pilhas abaixo.
    security.pam.services = {
      xfce4-screensaver.rules.auth.fprintd.settings =
        lib.mkIf config.services.xserver.desktopManager.xfce.enableScreensaver fingerprintSettings;
      polkit-1.rules.auth.fprintd.settings = fingerprintSettings;
    };
  };
}
