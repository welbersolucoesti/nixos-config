{ config, lib, pkgs, ... }:

let
  inherit (import ./theme.nix pkgs) theme iconTheme cursorTheme;
  xfconf = "xdg/xfce4/xfconf/xfce-perchannel-xml";
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    environment.systemPackages = [
      theme.package
      iconTheme.package
      cursorTheme.package
      pkgs.bibata-cursors # Continua disponível para quem já o escolheu.
      pkgs.tela-icon-theme # Mantém disponível o tema anterior para quem o selecionou explicitamente.
    ];

    # Aplicativos que seguem o esquema de cores do desktop, como os que usam libadwaita.
    programs.dconf.profiles.user.databases = lib.mkAfter [
      { lockAll = true; settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"; }
    ];

    # Thunar, painel e menus herdam a aparência GTK da sessão.
    environment.etc."${xfconf}/xsettings.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xsettings" version="1.0">
        <property name="Net" type="empty">
          <property name="ThemeName" type="string" value="${theme.name}" unlocked="root"/>
          <property name="IconThemeName" type="string" value="${iconTheme.name}" unlocked="root"/>
        </property>
        <property name="Gtk" type="empty">
          <property name="CursorThemeName" type="string" value="${cursorTheme.name}" unlocked="root"/>
          <property name="CursorThemeSize" type="int" value="${toString cursorTheme.size}" unlocked="root"/>
        </property>
      </channel>
    '';

    environment.etc."${xfconf}/xfce4-desktop.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfce4-desktop" version="1.0">
        <property name="desktop-icons" type="empty">
          <property name="style" type="int" value="0" unlocked="root"/>
        </property>
      </channel>
    '';

    environment.etc."${xfconf}/xfwm4.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfwm4" version="1.0">
        <property name="general" type="empty">
          <property name="theme" type="string" value="${theme.name}" unlocked="root"/>
          <property name="workspace_count" type="int" value="2" unlocked="root"/>
          <property name="workspace_names" type="array" unlocked="root">
            <value type="string" value="Work 1"/>
            <value type="string" value="Work 2"/>
          </property>
          <property name="wrap_cycle" type="bool" value="false" unlocked="root"/>
          <property name="wrap_layout" type="bool" value="false" unlocked="root"/>
          <property name="use_compositing" type="bool" value="false" unlocked="root"/>
        </property>
      </channel>
    '';
  };
}
