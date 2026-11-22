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
      ${pkgs.xfconf}/bin/xfconf-query -c xfce4-keyboard-shortcuts "$@"
    }

    properties=$(query -l) || exit 1

    register_shortcut() {
      local key=$1 action=$2 existing previous
      local binding="^/(commands|xfwm4)/(default|custom)/<(super|meta|mod4)>$key$"
      while IFS= read -r existing; do
        [[ ''${existing,,} =~ $binding ]] || continue
        previous=$(query -p "$existing" 2>/dev/null) || previous=""
        # O padrão de bloqueio pode estar ausente da cópia customizada da conta.
        [[ $existing == '/commands/default/<Super>l' && $previous == xflock4 ]] && continue
        if [[ $previous != "$action" ]]; then
          printf 'Noir: Super+%s já está reservado no XFCE (%s).\n' "''${key^^}" "$existing" >&2
        fi
        return 0
      done <<< "$properties"
      query -p "/commands/custom/<Super>$key" -n -t string -s "$action"
    }

    register_shortcut n 'xfce4-terminal --disable-server --window --execute /run/current-system/sw/bin/noir-session'
    register_shortcut l xflock4

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

    # Atribui apenas uma propriedade livre e mantém as escolhas já gravadas.
    if ! query -p '${property}' >/dev/null 2>&1; then
      query -p '${property}' -n -t string -s '${popup}' || exit 1
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
      Name=Atalhos do Noir e do Whisker
      Exec=${startXcape}
      OnlyShowIn=XFCE;
      NoDisplay=true
    '';
  };
}
