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
      pkgs.tela-icon-theme # Mantém disponível o tema anterior para quem o selecionou explicitamente.
    ];

    # Aplicativos que seguem o esquema de cores do desktop, como os que usam libadwaita.
    programs.dconf.profiles.user.databases = lib.mkAfter [
      { settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"; }
    ];

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
          <property name="workspace_count" type="int" value="2"/>
          <property name="use_compositing" type="bool" value="false" unlocked="root"/>
          <!-- Aplica as margens também a contas com valores locais gravados. -->
          <property name="margin_top" type="int" value="12" unlocked="root"/>
          <property name="margin_right" type="int" value="12" unlocked="root"/>
          <property name="margin_bottom" type="int" value="12" unlocked="root"/>
          <property name="margin_left" type="int" value="12" unlocked="root"/>
        </property>
      </channel>
    '';
  };
}
