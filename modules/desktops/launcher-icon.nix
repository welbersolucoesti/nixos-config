{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) desktop;
  # O Tela-dark oferece este nome e o módulo gráfico do NixOS o fornece em hicolor.
  icon = "nix-snowflake";
  kickoffScript = pkgs.writeText "noir-kickoff-icon.js" ''
    const desktopPanels = panels();
    for (const panel of desktopPanels) {
      for (const widget of panel.widgets()) {
        if (widget.type !== "org.kde.plasma.kickoff") {
          continue;
        }

        widget.currentConfigGroup = ["General"];
        const currentIcon = widget.readConfig("icon", "start-here-kde-symbolic");
        if (currentIcon === "start-here-kde-symbolic" || currentIcon === "start-here-kde") {
          widget.writeConfig("icon", "${icon}");
        }
      }
    }
    if (desktopPanels.length > 0) {
      print("ready");
    }
  '';
  updateKickoff = pkgs.writeShellScript "noir-kickoff-icon" ''
    script=$(<"${kickoffScript}")
    for attempt in {1..10}; do
      result=$(${lib.getExe' pkgs.kdePackages.qttools "qdbus"} org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript "$script") || exit 1
      [ "$result" = ready ] && exit 0
      ${pkgs.coreutils}/bin/sleep 1
    done
  '';
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
  config = lib.mkMerge [
    (lib.mkIf (desktop == "kde") {
      systemd.user.services.noir-kickoff-icon = {
        description = "Ícone NixOS no Kickoff";
        wantedBy = [ "plasma-workspace.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "plasma-plasmashell.service" ];
        serviceConfig = {
          Type = "exec";
          ExecStart = updateKickoff;
        };
      };
    })
    (lib.mkIf (desktop == "xfce") {
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
    })
  ];
}
