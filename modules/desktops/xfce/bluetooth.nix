{ config, lib, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Inclui o gerenciador, o autostart do applet e a integração com o BlueZ.
    services.blueman.enable = true;
  };
}
