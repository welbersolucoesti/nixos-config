file:
{ lib, ... }:

let
  wallpaperDirectory = ../wallpapers;
  inherit (import ./preferences.nix { inherit lib file wallpaperDirectory; }) values;
  inherit (lib) mkOption types;
  readOnly = type: mkOption { inherit type; readOnly = true; internal = true; };
  extension = builtins.match ".*(\\.[a-zA-Z0-9]+)" values.wallpaper;
in
{
  options.personalConfig = {
    desktop = readOnly (types.nullOr (types.enum [ "kde" "gnome" "cinnamon" "lxqt" ]));
    wallpaper = readOnly types.path;
    cron.enable = readOnly types.bool;
    virtualization.enable = readOnly types.bool;
    codex.enable = readOnly types.bool;
    zsh.theme = readOnly (types.nullOr types.nonEmptyStr);
  };

  config.personalConfig = {
    inherit (values) desktop zsh;
    wallpaper = builtins.path {
      path = wallpaperDirectory + "/${values.wallpaper}";
      name = "noir-wallpaper" + lib.optionalString (extension != null) (builtins.head extension);
    };
    cron.enable = values.optionals.cron;
    virtualization.enable = values.optionals.virtualization;
    codex.enable = values.optionals.codex;
  };
}
