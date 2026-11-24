{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) desktop;
  # O módulo gráfico do NixOS fornece este nome em hicolor.
  icon = "nix-snowflake";
  updateWhisker = pkgs.writeShellScript "xfce-whisker-icon" ''
    query() {
      ${pkgs.xfconf}/bin/xfconf-query -c xfce4-panel "$@"
    }

    properties=$(query -l) || exit 1
    while IFS= read -r property; do
      [[ "$property" =~ ^/plugins/plugin-([0-9]+)$ ]] || continue
      id="''${BASH_REMATCH[1]}"
      [ "$(query -p "$property")" = whiskermenu ] || continue

      # O Whisker migra o .rc antigo depois de carregar o xfconf.
      legacy="''${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/panel/whiskermenu-$id.rc"
      if [ -f "$legacy" ]; then
        sed=${pkgs.gnused}/bin/sed
        legacyIcon=$("$sed" -n '/^[[:space:]]*\[/,$!s/^[[:space:]]*button-icon[[:space:]]*=/button-icon=/p' "$legacy")
        if [ -n "$legacyIcon" ] && [ "$legacyIcon" != "button-icon=${icon}" ]; then
          "$sed" -i --follow-symlinks \
            '/^[[:space:]]*\[/,$!s/^\([[:space:]]*button-icon[[:space:]]*=\).*$/\1${icon}/' "$legacy"
        fi
      fi

      if [ "$(query -p "$property/button-icon" 2>/dev/null)" != "${icon}" ]; then
        query -p "$property/button-icon" -n -t string -s "${icon}"
      fi
    done <<< "$properties"
  '';
in
{
  config = lib.mkIf (desktop == "xfce") {
    # Padrão para novas instâncias do Whisker.
    environment.etc."xdg/xfce4/whiskermenu/defaults.rc".text = ''
      button-icon=${icon}
    '';
    # O wrapper roda com a conta do usuário antes de iniciar o painel do XFCE.
    services.xserver.displayManager.sessionCommands = ''
      if [ "''${XDG_SESSION_DESKTOP:-}" = xfce ]; then
        ${updateWhisker}
      fi
    '';
  };
}
