{ config, lib, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Padrão para novas instâncias do Whisker. O NixOS fornece o ícone em hicolor.
    environment.etc."xdg/xfce4/whiskermenu/defaults.rc".text = ''
      button-icon=nix-snowflake
    '';
  };
}
