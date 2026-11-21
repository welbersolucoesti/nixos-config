{ config, lib, pkgs, ... }:

let
  audioAvailable =
    (config.services.pulseaudio.enable || config.services.pipewire.pulse.enable)
    && !builtins.any (
      package: lib.getName package == lib.getName pkgs.xfce4-pulseaudio-plugin
    ) config.environment.xfce.excludePackages;
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Os itens ficam disponíveis no painel. Clipman requer escolha explícita pois guarda histórico.
    environment.systemPackages = with pkgs; [
      xfce4-whiskermenu-plugin
      xfce4-clipman-plugin
      xfce4-docklike-plugin
    ];

    # O migrador do painel usa o modelo somente quando o xfconf ainda não tem /panels.
    environment.etc."xdg/xfce4/panel/default.xml".text = lib.replaceStrings
      [ "<!-- volume-id -->" "<!-- volume-plugin -->" ]
      [
        (lib.optionalString audioAvailable ''<value type="int" value="8"/>'')
        (lib.optionalString audioAvailable ''<property name="plugin-8" type="string" value="pulseaudio"/>'')
      ]
      (builtins.readFile ./panel-default.xml);
  };
}
