{ config, lib, pkgs, ... }:

let
  inherit (config.personalConfig) wallpaper;
  image = baseNameOf wallpaper;
  imageDirectory = "share/backgrounds/xfce";
  restore = pkgs.writeShellScript "noir-xfce-wallpaper" ''
    set -eu
    query() { ${lib.getExe' pkgs.xfconf "xfconf-query"} -c xfce4-desktop "$@"; }

    properties=$(query -l)
    set_property() {
      local property=$1 type=$2 value=$3 current
      if current=$(query -p "$property" 2>/dev/null); then
        if [[ $current != "$value" ]]; then query -p "$property" -s "$value"; fi
      else
        query -p "$property" -n -t "$type" -s "$value"
      fi
    }
    while IFS= read -r property; do
      # Um monitor/workspace pode ter somente o estilo ou a rotação registrados.
      if [[ $property =~ ^(/backdrop/screen[0-9]+/monitor[^/]+(/workspace[0-9]+)?)/(last-image|image-path|image-style|backdrop-cycle-enable|rgba[12]|color-style)$ ]]; then
        base="''${BASH_REMATCH[1]}"
        if [[ $property == */image-path ]]; then
          set_property "$property" string ${wallpaper}
        fi
        set_property "$base/last-image" string ${wallpaper}
        set_property "$base/backdrop-cycle-enable" bool false
        if [[ $(query -p "$base/image-style" 2>/dev/null || true) == 0 ]]; then
          set_property "$base/image-style" int 5
        fi
      fi
    done <<< "$properties"
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Reconcilia propriedades conhecidas antes do xfdesktop. Monitores novos
    # e o bloqueador também recebem o fallback nativo do pacote.
    services.xserver.displayManager.sessionCommands = ''
      if [ "''${XDG_SESSION_DESKTOP:-}" = xfce ] && [ "''${XDG_SESSION_TYPE:-}" = x11 ]; then
        ${restore} || printf '%s\n' 'Noir: não foi possível aplicar o wallpaper do XFCE.' >&2
      fi
    '';

    nixpkgs.overlays = [
      (_: prev: {
        xfdesktop = prev.xfdesktop.overrideAttrs (old: {
          configureFlags = (old.configureFlags or [ ]) ++ [
            "--with-default-backdrop-filename=/run/current-system/sw/${imageDirectory}/${image}"
          ];
          postInstall = (old.postInstall or "") + ''
            ln -s ${wallpaper} "$out/${imageDirectory}/${image}"
          '';
        });
        xfce4-screensaver = prev.xfce4-screensaver.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/xfce-bg.c \
              --replace-fail '#define XFCE_BG_FALLBACK_IMG "xfce-x.svg"' '#define XFCE_BG_FALLBACK_IMG "${image}"'
          '';
        });
      })
    ];
    environment.pathsToLink = [ "/${imageDirectory}" ];
  };
}
