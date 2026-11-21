{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) desktop;
  # O módulo gráfico do NixOS já instala nixos-icons. O Tela-dark herda hicolor.
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
      # O Whisker lê isto antes das preferências pessoais de cada botão.
      environment.etc."xdg/xfce4/whiskermenu/defaults.rc".text = ''
        button-icon=${icon}
      '';
    })
  ];
}
