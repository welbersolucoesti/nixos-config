{ config, lib, pkgs, ... }:

let
  trigger = "<Shift><Alt>F11";
  property = "/commands/custom/${trigger}";
  popup = "xfce4-popup-whiskermenu";
  startXcape = pkgs.writeShellScript "xfce-whisker-super" ''
    [ "''${XDG_SESSION_TYPE:-}" = x11 ] || exit 0
    [ -n "''${XDG_RUNTIME_DIR:-}" ] && [ -n "''${DISPLAY:-}" ] || exit 0

    display="''${DISPLAY//\//_}"
    exec 9>"$XDG_RUNTIME_DIR/xfce-whisker-super-$display.lock"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0

    query() {
      ${pkgs.xfconf}/bin/xfconf-query -c xfce4-keyboard-shortcuts -p "$1" 2>/dev/null
    }

    # Se um desses atalhos já tiver outro uso no XFCE, preserve-o.
    for provider in commands xfwm4; do
      for group in default custom; do
        for key in Super_L '${trigger}' '<Alt><Shift>F11'; do
          if action=$(query "/$provider/$group/$key"); then
            [ "$provider/$key/$action" = 'commands/${trigger}/${popup}' ] || exit 0
          fi
        done
      done
    done

    # Atribui apenas uma propriedade livre e mantém as escolhas já gravadas.
    if ! query '${property}' >/dev/null; then
      ${pkgs.xfconf}/bin/xfconf-query -c xfce4-keyboard-shortcuts \
        -p '${property}' -n -t string -s '${popup}' || exit 1
    fi
    exec ${pkgs.xcape}/bin/xcape -f -e 'Super_L=Shift_L|Alt_L|F11'
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Xcape emite a combinação ao soltar Super isoladamente e preserva as
    # combinações com outras teclas.
    environment.etc."xdg/autostart/xfce-whisker-super.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Whisker Menu (Super)
      Exec=${startXcape}
      OnlyShowIn=XFCE;
      NoDisplay=true
    '';
  };
}
