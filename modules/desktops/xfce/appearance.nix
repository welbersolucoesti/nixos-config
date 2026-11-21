{ config, lib, pkgs, ... }:

let
  inherit (import ./theme.nix pkgs) theme iconTheme cursorTheme;
  xfconf = "xdg/xfce4/xfconf/xfce-perchannel-xml";
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Normalmente o greeter GTK já disponibiliza os três pacotes.
    environment.systemPackages = lib.optionals
      (!config.services.xserver.displayManager.lightdm.greeters.gtk.enable)
      [ theme.package iconTheme.package cursorTheme.package ];

    # Thunar, painel e menus herdam a aparência GTK da sessão.
    environment.etc."${xfconf}/xsettings.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xsettings" version="1.0">
        <property name="Net" type="empty">
          <property name="ThemeName" type="string" value="${theme.name}"/>
          <property name="IconThemeName" type="string" value="${iconTheme.name}"/>
        </property>
        <property name="Gtk" type="empty">
          <property name="CursorThemeName" type="string" value="${cursorTheme.name}"/>
          <property name="CursorThemeSize" type="int" value="${toString cursorTheme.size}"/>
        </property>
      </channel>
    '';

    environment.etc."${xfconf}/xfwm4.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfwm4" version="1.0">
        <property name="general" type="empty">
          <property name="theme" type="string" value="${theme.name}"/>
        </property>
      </channel>
    '';
  };
}
