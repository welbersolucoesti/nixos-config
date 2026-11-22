{ config, lib, pkgs, ... }:

let
  audioAvailable =
    (config.services.pulseaudio.enable || config.services.pipewire.pulse.enable)
    && !builtins.any (
      package: lib.getName package == lib.getName pkgs.xfce4-pulseaudio-plugin
    ) config.environment.xfce.excludePackages;
  mixerAvailable = !builtins.any (
    package: lib.getName package == lib.getName pkgs.pavucontrol
  ) config.environment.xfce.excludePackages;

  defaults = {
    panels = {
      path = "/panels";
      properties = [
        [ "dark-mode" "bool" "true" ]
      ];
    };
    panel = {
      path = "/panels/panel-1";
      properties = [
        [ "icon-size" "uint" "22" ]
      ];
    };
    tray = {
      path = "/plugins/plugin-5";
      properties = [
        [ "icon-size" "int" "0" ] # Segue o tamanho dos ícones do painel.
        [ "single-row" "bool" "true" ]
        [ "square-icons" "bool" "true" ]
        [ "symbolic-icons" "bool" "true" ]
      ];
    };
    clock = {
      path = "/plugins/plugin-6";
      preserveIfSet = [
        "digital-format" "digital-date-format" "digital-time-font" "digital-date-font"
      ];
      properties = [
        [ "mode" "uint" "2" ] # Digital.
        [ "digital-layout" "uint" "3" ] # Somente a hora.
        [ "digital-time-format" "string" "%H:%M" ]
        [ "tooltip-format" "string" "%A, %d/%m/%Y" ]
      ];
    };
    actions = {
      path = "/plugins/plugin-7";
      preserveIfSet = [ ];
      properties = [
        [ "appearance" "uint" "1" ] # Menu de sessão.
        [ "button-title" "uint" "3" ] # Título personalizado.
        [ "custom-title" "string" "⏻" ]
      ];
    };
  };

  renderProperties = group: lib.concatMapStringsSep "\n      " (
    property:
    let
      name = builtins.elemAt property 0;
      type = builtins.elemAt property 1;
      value = builtins.elemAt property 2;
    in
    ''<property name="${name}" type="${type}" value="${lib.escapeXML value}"/>''
  ) group.properties;

  migratePanel = pkgs.writeShellScript "xfce-noir-panel-migrate" ''
    query() {
      ${pkgs.xfconf}/bin/xfconf-query -c xfce4-panel "$@"
    }

    get() {
      query -p "$1" 2>/dev/null
    }

    get_array() {
      local value
      value=$(get "$1") || return 1
      printf '%s\n' "''${value#*$'\n\n'}"
    }

    set_default() {
      get "$1" >/dev/null || query -p "$1" -n -t "$2" -s "$3"
    }

    has_other_value() {
      local current
      current=$(get "$1") && [ "$current" != "$2" ]
    }

    # O modelo novo fica a cargo do migrador nativo do painel. Aqui só entra
    # o painel único com a mesma ordem e os mesmos plugins do modelo anterior.
    marker=/noir/panel-defaults-version
    get "$marker" >/dev/null && exit 0
    [ "$(get_array /panels)" = 1 ] || exit 0
    ids=$(get_array /panels/panel-1/plugin-ids) || exit 0
    case "$ids" in
      $'1\n2\n3\n4\n5\n6\n7'|$'1\n2\n3\n4\n5\n8\n6\n7') ;;
      *) exit 0 ;;
    esac

    id=0
    for plugin in whiskermenu docklike separator pager systray clock actions; do
      ((id += 1))
      [ "$(get "/plugins/plugin-$id")" = "$plugin" ] || exit 0
    done
    if [[ "$ids" == *$'\n8\n'* ]]; then
      [ "$(get /plugins/plugin-8)" = pulseaudio ] || exit 0
    fi
    existing=$(get /plugins/plugin-9)
    [ -z "$existing" ] || [ "$existing" = showdesktop ] || exit 0

    ${lib.concatMapStringsSep "\n    " (group:
      let
        properties = map (property: {
          path = "${group.path}/${builtins.elemAt property 0}";
          type = builtins.elemAt property 1;
          value = builtins.elemAt property 2;
        }) group.properties;
        assignments = lib.concatMapStringsSep "\n" (
          { path, type, value }: "set_default ${lib.escapeShellArgs [ path type value ]} || exit 1"
        ) properties;
        conflicts =
          map (name: "get ${lib.escapeShellArg "${group.path}/${name}"} >/dev/null") group.preserveIfSet
          ++ map ({ path, value, ... }: "has_other_value ${lib.escapeShellArgs [ path value ]}") properties;
      in
      if group ? preserveIfSet then ''
        if ! { ${lib.concatStringsSep " || " conflicts}; }; then
          ${assignments}
        fi
      '' else assignments
    ) (builtins.attrValues defaults)}

    set_default /plugins/plugin-9 string showdesktop || exit 1
    args=()
    while IFS= read -r id; do
      args+=(-t int -s "$id")
    done <<< "$ids"
    query -p /panels/panel-1/plugin-ids -a "''${args[@]}" -t int -s 9 || exit 1
    query -p "$marker" -n -t uint -s 1
  '';

  volumePlugin = ''
    <property name="plugin-8" type="string" value="pulseaudio">
      ${lib.optionalString mixerAvailable ''
        <property name="mixer-command" type="string" value="pavucontrol --tab=3"/>
      ''}
    </property>'';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Os itens ficam disponíveis no painel. Clipman requer escolha explícita pois guarda histórico.
    environment.systemPackages = with pkgs; [
      xfce4-whiskermenu-plugin
      xfce4-clipman-plugin
      xfce4-docklike-plugin
    ];

    # O migrador do painel usa o modelo somente quando o xfconf ainda não tem /panels.
    environment.etc."xdg/xfce4/panel/default.xml".text = lib.replaceStrings
      ([ "<!-- volume-id -->" "<!-- volume-plugin -->" ]
        ++ map (name: "<!-- ${name}-defaults -->") (builtins.attrNames defaults))
      ([
        (lib.optionalString audioAvailable ''<value type="int" value="8"/>'')
        (lib.optionalString audioAvailable volumePlugin)
      ] ++ map renderProperties (builtins.attrValues defaults))
      (builtins.readFile ./panel-default.xml);

    services.xserver.displayManager.sessionCommands = ''
      if [ "''${XDG_SESSION_DESKTOP:-}" = xfce ]; then
        ${migratePanel} || :
      fi
    '';
  };
}
