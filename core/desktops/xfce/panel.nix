{ config, lib, pkgs, ... }:

let
  excluded = package: lib.any (other: lib.getName other == lib.getName package)
    config.environment.xfce.excludePackages;
  volume = (config.services.pulseaudio.enable || config.services.pipewire.pulse.enable)
    && !excluded pkgs.xfce4-pulseaudio-plugin;
  battery = config.powerManagement.enable && !excluded pkgs.xfce4-power-manager;

  model = pkgs.writeTextDir "xfce4/panel/default.xml" (lib.replaceStrings
    [ "<!-- volume-id -->" "<!-- volume-plugin -->" "<!-- battery-id -->" "<!-- battery-plugin -->" ]
    [
      (lib.optionalString volume ''<value type="int" value="8"/>'')
      (lib.optionalString volume ''
        <property name="plugin-8" type="string" value="pulseaudio">
          ${lib.optionalString (!excluded pkgs.pavucontrol) ''
            <property name="mixer-command" type="string" value="pavucontrol --tab=3"/>
          ''}
        </property>'')
      (lib.optionalString battery ''<value type="int" value="19"/>'')
      (lib.optionalString battery ''<property name="plugin-19" type="string" value="power-manager-plugin"/>'')
    ]
    (builtins.readFile ./panel-default.xml));

  initialize = pkgs.writeShellScript "xfce-noir-initialize-panel" ''
    set -eu
    configHome="''${XDG_CONFIG_HOME:-$HOME/.config}"
    panelDirectory="$configHome/xfce4/panel"
    dockConfig="$panelDirectory/docklike-20.rc"

    [ -n "''${XDG_RUNTIME_DIR:-}" ] || exit 0
    exec 9>"$XDG_RUNTIME_DIR/noir-xfce-panel.lock"
    ${lib.getExe' pkgs.util-linux "flock"} 9

    xfconf=${lib.getExe' pkgs.xfconf "xfconf-query"}
    query() { "$xfconf" -c xfce4-panel "$@"; }

    if [ "$(query -p /noir/docklike-layout 2>/dev/null)" != true ]; then
      # Preserva até o estado parcial, vazio ou legado do próprio painel.
      for path in "$configHome/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" \
                  "$panelDirectory"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
          exit 0
        fi
      done

      channels=$("$xfconf" -l)
      if printf '%s\n' "$channels" | ${lib.getExe pkgs.gnugrep} -Eq '^[[:space:]]*xfce4-panel$'; then
        exit 0
      fi

      # Só esta chamada ao importador vê o modelo Noir. O painel mantém sua
      # inicialização nativa em contas com estado local.
      XDG_CONFIG_DIRS="${model}:''${XDG_CONFIG_DIRS:-/etc/xdg}" XFCE_PANEL_MIGRATE_DEFAULT=1 \
        ${pkgs.xfce4-panel}/lib/xfce4/panel/migrate
    fi

    [ "$(query -p /noir/docklike-layout 2>/dev/null)" = true ] || exit 1
    [ "$(query -p /noir/docklike-initialized 2>/dev/null)" != true ] || exit 0
    [ "$(query -p /plugins/plugin-20 2>/dev/null)" = docklike ] || exit 0

    if [ ! -e "$dockConfig" ] && [ ! -L "$dockConfig" ]; then
      # Um ID concreto permite que o Docklike agrupe a janela pelo StartupWMClass.
      browser=$(${lib.getExe' pkgs.xdg-utils "xdg-mime"} query default x-scheme-handler/https || :)
      case "$browser" in
        ""|xfce4-web-browser.desktop)
          helper=$(${lib.getExe' pkgs.xfce4-settings "xfce4-mime-helper"} --query=WebBrowser || :)
          if [ "$helper" = google-chrome ]; then
            browser=google-chrome.desktop
          else
            browser=xfce4-web-browser.desktop
          fi
          ;;
      esac
      if [[ ! "$browser" =~ ^[a-zA-Z0-9_.-]+\.desktop$ ]]; then
        browser=xfce4-web-browser.desktop
      fi

      umask 077
      ${lib.getExe' pkgs.coreutils "mkdir"} -p -- "$panelDirectory"
      temporary=$(${lib.getExe' pkgs.coreutils "mktemp"} -- "$panelDirectory/.noir-docklike.XXXXXXXX")
      trap '${lib.getExe' pkgs.coreutils "rm"} -f -- "$temporary"' EXIT
      # O Docklike indexa os IDs pelo nome do arquivo sem a extensão .desktop.
      printf '[user]\npinned=%s;idea;code;dbeaver;thunar;\n' "''${browser%.desktop}" > "$temporary"
      if ! ${lib.getExe' pkgs.coreutils "ln"} -T -- "$temporary" "$dockConfig"; then
        [ -e "$dockConfig" ] || [ -L "$dockConfig" ] || exit 1
      fi
    fi

    query -p /noir/docklike-initialized -n -t bool -s true
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    environment.systemPackages = with pkgs; [
      xfce4-whiskermenu-plugin
      xfce4-clipman-plugin
      xfce4-docklike-plugin
    ];

    environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" =
      lib.mkIf battery {
        text = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <channel name="xfce4-power-manager" version="1.0">
            <property name="xfce4-power-manager" type="empty">
              <property name="show-panel-label" type="int" value="0" unlocked="root"/>
            </property>
          </channel>
        '';
      };

    services.xserver.displayManager.sessionCommands = ''
      if [ "''${XDG_SESSION_DESKTOP:-}" = xfce ] && [ "''${XDG_SESSION_TYPE:-}" = x11 ]; then
        ${initialize} || printf '%s\n' 'Noir: a inicialização do painel XFCE não foi concluída.' >&2
      fi
    '';
  };
}
