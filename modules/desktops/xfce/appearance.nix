{ config, lib, pkgs, ... }:

let
  theme = "Orchis-Dark";
  xfconf = "xdg/xfce4/xfconf/xfce-perchannel-xml";
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    environment.systemPackages = with pkgs; [
      orchis-theme
      tela-icon-theme
      bibata-cursors
    ];

    # Thunar, painel e menus herdam a aparência GTK da sessão.
    environment.etc."${xfconf}/xsettings.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xsettings" version="1.0">
        <property name="Net" type="empty">
          <property name="ThemeName" type="string" value="${theme}"/>
          <property name="IconThemeName" type="string" value="Tela-dark"/>
        </property>
        <property name="Gtk" type="empty">
          <property name="CursorThemeName" type="string" value="Bibata-Modern-Ice"/>
          <property name="CursorThemeSize" type="int" value="24"/>
        </property>
      </channel>
    '';

    environment.etc."${xfconf}/xfwm4.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfwm4" version="1.0">
        <property name="general" type="empty">
          <property name="theme" type="string" value="${theme}"/>
        </property>
      </channel>
    '';
  };
}
