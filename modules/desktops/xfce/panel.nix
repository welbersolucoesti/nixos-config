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
  batteryAvailable = config.powerManagement.enable && !builtins.any (
    package: lib.getName package == lib.getName pkgs.xfce4-power-manager
  ) config.environment.xfce.excludePackages;
  batteryPlugin = "power-manager-plugin";
  batteryId = 19;

  # O separador sem expansão tem largura nativa fixa. Estilo 0 é transparente e 1 é linha.
  rightSeparators = { "10" = "0"; "11" = "0"; "12" = "1"; "13" = "0"; };
  trailingSpacer = "14";
  leftSeparators = { "15" = "0"; "16" = "0"; "17" = "1"; "18" = "0"; };

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
        [ "position-locked" "bool" "true" ]
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

    matches_noir_panel() {
      local id=0 plugin
      [ "$(get "$panel/position")" = 'p=6;x=0;y=0' ] || return 1
      [ "$(get "$panel/length")" = 100 ] || return 1
      [ "$(get "$panel/size")" = 36 ] || return 1
      has_other_value "$panel/mode" 0 && return 1
      [ "$(get /plugins/plugin-3/expand)" = true ] || return 1
      [ "$(get /plugins/plugin-3/style)" = 0 ] || return 1
      for plugin in whiskermenu docklike separator pager systray clock actions; do
        ((id += 1))
        [ "$(get "/plugins/plugin-$id")" = "$plugin" ] || return 1
      done
    }

    add_trailing_space() {
      local spacer=/plugins/plugin-${trailingSpacer} id
      local args=()
      set_default "$spacer" string separator || return 1
      set_default "$spacer/style" uint 0 || return 1
      set_default "$spacer/expand" bool false || return 1
      for id in 1 2 3 4 5 "''${audio[@]}" 6 10 9 11 12 13 7 ${trailingSpacer}; do
        args+=(-t int -s "$id")
      done
      query -p "$panel/plugin-ids" -a "''${args[@]}" || return 1
      query -p "$marker" -t bool -s true
    }

    migrate_v3() (
    # O modelo novo fica a cargo do migrador nativo. O marcador v3 diferencia
    # uma migração em andamento de um painel que já nasceu com a nova ordem.
    marker=/noir/panel-layout-v3-complete
    state=$(get "$marker")
    [ "$state" = true ] && exit 0
    v2=$(get /noir/panel-layout-v2-complete)
    [ "$(get_array /panels)" = 1 ] || exit 0
    panel=/panels/panel-1
    ids=$(get_array "$panel/plugin-ids") || exit 0
    ids="''${ids//$'\n'/ }"
    audio=()
    if [[ "$ids" == '1 2 3 4 5 8 '* ]]; then
      [ "$(get /plugins/plugin-8)" = pulseaudio ] || exit 0
      audio=(8)
      ids="''${ids/5 8 /5 }"
    fi
    v2_layout=false
    case "$ids" in
      '1 2 3 4 5 6 7')
        [ "$v2" != true ] || exit 0
        # O marcador v1 indica que Mostrar área de trabalho foi removido depois.
        get /noir/panel-defaults-version >/dev/null && exit 0
        ;;
      '1 2 3 4 5 6 7 9')
        [ "$v2" != true ] || exit 0
        [ "$(get /plugins/plugin-9)" = showdesktop ] || exit 0
        ;;
      '1 2 3 4 5 6 10 9 11 12 13 7')
        v2_layout=true
        [ "$(get /plugins/plugin-9)" = showdesktop ] || exit 0
        ;;
      "1 2 3 4 5 6 10 9 11 12 13 7 ${trailingSpacer}")
        [ "$state" = false ] || exit 0
        query -p "$marker" -t bool -s true
        exit $?
        ;;
      *) exit 0 ;;
    esac

    matches_noir_panel || exit 0
    existing=$(get /plugins/plugin-9)
    [ -z "$existing" ] || [ "$existing" = showdesktop ] || exit 0

    for id in ${toString (builtins.attrNames rightSeparators)}; do
      if [ "$v2_layout" = true ]; then
        [ "$(get "/plugins/plugin-$id")" = separator ] || exit 0
      elif existing=$(get "/plugins/plugin-$id"); then
        { [ "$state" = false ] || [ "$v2" = false ]; } && [ "$existing" = separator ] || exit 0
      fi
    done
    if existing=$(get /plugins/plugin-${trailingSpacer}); then
      [ "$state" = false ] && [ "$existing" = separator ] || exit 0
    fi
    set_default "$marker" bool false || exit 1
    if [ "$v2_layout" = true ]; then
      add_trailing_space
      exit $?
    fi

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

    workspace=/general/workspace_count
    # Quatro era o padrão anterior do Xfwm4, inclusive quando já gravado na conta.
    if [ "$(${pkgs.xfconf}/bin/xfconf-query -c xfwm4 -p "$workspace" 2>/dev/null)" = 4 ]; then
      ${pkgs.xfconf}/bin/xfconf-query -c xfwm4 -p "$workspace" -t int -s 2 || exit 1
    fi

    set_default /plugins/plugin-9 string showdesktop || exit 1
    ${lib.concatStringsSep "\n    " (lib.mapAttrsToList (id: style: ''
      set_default /plugins/plugin-${id} string separator || exit 1
      set_default /plugins/plugin-${id}/style uint ${style} || exit 1
      set_default /plugins/plugin-${id}/expand bool false || exit 1
    '') rightSeparators)}

    add_trailing_space
    )

    # Reaproveita a migração anterior para contas que ainda estão em v1 ou v2.
    migrate_v3 || exit 1

    migrate_v4() (
    marker=/noir/panel-layout-v4-complete
    state=$(get "$marker")
    [ "$state" = true ] && exit 0
    [ "$(get_array /panels)" = 1 ] || exit 0
    panel=/panels/panel-1
    ids=$(get_array "$panel/plugin-ids") || exit 0
    ids="''${ids//$'\n'/ }"
    audio=()
    if [[ "$ids" == *' 5 8 6 '* ]]; then
      [ "$(get /plugins/plugin-8)" = pulseaudio ] || exit 0
      audio=(8)
      ids="''${ids/5 8 6/5 6}"
    fi
    case "$ids" in
      "1 2 3 4 5 6 10 9 11 12 13 7 ${trailingSpacer}") ;;
      "15 1 16 17 18 4 3 5 6 10 9 11 12 13 7 ${trailingSpacer}")
        [ "$state" = false ] || exit 0
        query -p "$marker" -t bool -s true
        exit $?
        ;;
      *) exit 0 ;;
    esac

    matches_noir_panel || exit 0
    [ "$(get /plugins/plugin-9)" = showdesktop ] || exit 0
    for id in ${toString (builtins.attrNames rightSeparators)} ${trailingSpacer}; do
      [ "$(get "/plugins/plugin-$id")" = separator ] || exit 0
    done
    for id in ${toString (builtins.attrNames leftSeparators)}; do
      if existing=$(get "/plugins/plugin-$id"); then
        [ "$state" = false ] && [ "$existing" = separator ] || exit 0
      fi
    done

    set_default "$marker" bool false || exit 1
    ${lib.concatStringsSep "\n    " (lib.mapAttrsToList (id: style: ''
      set_default /plugins/plugin-${id} string separator || exit 1
      set_default /plugins/plugin-${id}/style uint ${style} || exit 1
      set_default /plugins/plugin-${id}/expand bool false || exit 1
    '') leftSeparators)}

    # Só retira a instância Docklike da ordem do painel. Seus dados são preservados.
    args=()
    for id in 15 1 16 17 18 4 3 5 "''${audio[@]}" 6 10 9 11 12 13 7 ${trailingSpacer}; do
      args+=(-t int -s "$id")
    done
    query -p "$panel/plugin-ids" -a "''${args[@]}" || exit 1
    query -p "$marker" -t bool -s true
    )

    migrate_v4 || exit 1

    ${lib.optionalString batteryAvailable ''
      marker=/noir/panel-battery-configured
      [ "$(get "$marker")" = true ] && exit 0
      panels=$(get_array /panels) || exit 0
      [[ $'\n'"$panels"$'\n' == *$'\n1\n'* ]] || exit 0
      panel=/panels/panel-1
      case "$(get "$panel/position")" in
        p=2\;*|p=6\;*|p=9\;*|p=11\;*) ;;
        *) exit 0 ;;
      esac
      has_other_value "$panel/mode" 0 && exit 0
      ids=$(get_array "$panel/plugin-ids") || exit 0

      # Reserva também IDs de plugins inativos, que ainda podem ter preferências.
      properties=$(query -l) || exit 1
      declare -A used=()
      battery=
      while IFS= read -r property; do
        [[ "$property" =~ ^/plugins/plugin-([0-9]+)(/|$) ]] || continue
        id="''${BASH_REMATCH[1]}"
        used[$id]=1
        if [ "$property" = "/plugins/plugin-$id" ] && [ "$(get "$property")" = ${batteryPlugin} ]; then
          [ -z "$battery" ] || exit 0
          battery=$id
        fi
      done <<< "$properties"

      if [ -n "$battery" ]; then
        # A instância é única. Respeita uma escolha explícita por outro painel.
        for other in $panels; do
          [ "$other" != 1 ] || continue
          other_ids=$(get_array "/panels/panel-$other/plugin-ids") || continue
          [[ $'\n'"$other_ids"$'\n' != *$'\n'"$battery"$'\n'* ]] || exit 0
        done
      fi

      order=()
      volume=
      clock=
      previous=
      for id in $ids; do
        [ "$id" != "$battery" ] || continue
        used[$id]=1
        case "$(get "/plugins/plugin-$id")" in
          pulseaudio)
            [ -z "$volume" ] || exit 0
            volume=$id
            ;;
          clock)
            [ -z "$clock" ] || exit 0
            clock=$id
            before_clock=$previous
            ;;
        esac
        order+=("$id")
        previous=$id
      done
      [ -n "$clock" ] || exit 0
      # Com volume, a inserção preserva a ordem se os dois itens forem vizinhos.
      [ -z "$volume" ] || [ "$before_clock" = "$volume" ] || exit 0

      if [ -z "$battery" ]; then
        battery=${toString batteryId}
        while [[ -v used[$battery] ]]; do
          ((battery += 1))
        done
        query -p "/plugins/plugin-$battery" -n -t string -s ${batteryPlugin} || exit 1
      fi

      updated=()
      for id in "''${order[@]}"; do
        if [ "$id" = "$clock" ]; then
          updated+=("$battery")
        fi
        updated+=("$id")
      done
      if [ "$(printf '%s\n' "''${updated[@]}")" != "$ids" ]; then
        args=()
        for id in "''${updated[@]}"; do
          args+=(-t int -s "$id")
        done
        query -p "$panel/plugin-ids" -a "''${args[@]}" || exit 1
      fi
      set_default "$marker" bool true
    ''}
  '';

  separatorPlugins = lib.concatStrings (lib.mapAttrsToList (id: style: ''
    <property name="plugin-${id}" type="string" value="separator">
      <property name="style" type="uint" value="${style}"/>
      <property name="expand" type="bool" value="false"/>
    </property>
  '') (rightSeparators // { "${trailingSpacer}" = "0"; } // leftSeparators));

  volumePlugin = ''
    <property name="plugin-8" type="string" value="pulseaudio">
      ${lib.optionalString mixerAvailable ''
        <property name="mixer-command" type="string" value="pavucontrol --tab=3"/>
      ''}
    </property>'';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Mantém Docklike disponível para painéis personalizados e Clipman como item opcional.
    environment.systemPackages = with pkgs; [
      xfce4-whiskermenu-plugin
      xfce4-clipman-plugin
      xfce4-docklike-plugin
    ];

    # O migrador do painel usa o modelo somente quando o xfconf ainda não tem /panels.
    environment.etc."xdg/xfce4/panel/default.xml".text = lib.replaceStrings
      ([
        "<!-- volume-id -->" "<!-- volume-plugin -->" "<!-- fixed-separators -->"
        "<!-- battery-id -->" "<!-- battery-plugin -->" "<!-- battery-configured -->"
      ]
        ++ map (name: "<!-- ${name}-defaults -->") (builtins.attrNames defaults))
      ([
        (lib.optionalString audioAvailable ''<value type="int" value="8"/>'')
        (lib.optionalString audioAvailable volumePlugin)
        separatorPlugins
        (lib.optionalString batteryAvailable ''<value type="int" value="${toString batteryId}"/>'')
        (lib.optionalString batteryAvailable ''<property name="plugin-${toString batteryId}" type="string" value="${batteryPlugin}"/>'')
        (lib.optionalString batteryAvailable ''
          <property name="noir" type="empty">
            <property name="panel-battery-configured" type="bool" value="true"/>
          </property>
        '')
      ] ++ map renderProperties (builtins.attrValues defaults))
      (builtins.readFile ./panel-default.xml);

    services.xserver.displayManager.sessionCommands = ''
      if [ "''${XDG_SESSION_DESKTOP:-}" = xfce ]; then
        ${migratePanel} || :
      fi
    '';
  };
}
