{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Os itens ficam disponíveis no painel. Clipman requer escolha explícita pois guarda histórico.
    environment.systemPackages = with pkgs; [
      xfce4-whiskermenu-plugin
      xfce4-clipman-plugin
      xfce4-docklike-plugin
    ];

    # O migrador do painel usa o modelo somente quando o xfconf ainda não tem /panels.
    environment.etc."xdg/xfce4/panel/default.xml".source = ./panel-default.xml;
  };
}
