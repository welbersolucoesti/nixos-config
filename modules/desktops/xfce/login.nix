{ config, lib, pkgs, ... }:

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
  };
}
