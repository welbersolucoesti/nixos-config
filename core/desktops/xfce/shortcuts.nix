{ config, lib, pkgs, ... }:

let
  trigger = "<Shift><Alt>F11";
  popup = "xfce4-popup-whiskermenu";
  bindings = ''
    <property name="&lt;Super&gt;n" type="string" unlocked="root"
      value="xfce4-terminal --disable-server --window --execute /run/current-system/sw/bin/noir-session"/>
    <property name="&lt;Super&gt;l" type="string" unlocked="root" value="xflock4"/>
    <property name="&lt;Shift&gt;&lt;Alt&gt;F11" type="string" unlocked="root" value="${popup}"/>
  '';
  startXcape = pkgs.writeShellScript "xfce-whisker-super" ''
    [ "''${XDG_SESSION_TYPE:-}" = x11 ] || exit 0
    [ -n "''${XDG_RUNTIME_DIR:-}" ] && [ -n "''${DISPLAY:-}" ] || exit 0

    display="''${DISPLAY//\//_}"
    exec 9>"$XDG_RUNTIME_DIR/xfce-whisker-super-$display.lock"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0

    query() {
      ${pkgs.xfconf}/bin/xfconf-query -c xfce4-keyboard-shortcuts "$@"
    }

    # Se um desses atalhos já tiver outro uso no XFCE, preserve-o.
    for provider in commands xfwm4; do
      for group in default custom; do
        for key in Super_L '${trigger}' '<Alt><Shift>F11'; do
          if action=$(query -p "/$provider/$group/$key" 2>/dev/null); then
            [ "$provider/$key/$action" = 'commands/${trigger}/${popup}' ] || exit 0
          fi
        done
      done
    done

    exec ${pkgs.xcape}/bin/xcape -f -e 'Super_L=Shift_L|Alt_L|F11'
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfce4-keyboard-shortcuts" version="1.0">
        <property name="commands" type="empty">
          <property name="default" type="empty">
            ${bindings}
          </property>
          <property name="custom" type="empty">
            ${bindings}
          </property>
        </property>
      </channel>
    '';

    # Xcape emite a combinação ao soltar Super isoladamente e preserva as
    # combinações com outras teclas.
    environment.etc."xdg/autostart/xfce-whisker-super.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Atalhos do Noir e do Whisker
      Exec=${startXcape}
      OnlyShowIn=XFCE;
      NoDisplay=true
    '';
  };
}
