{ root, file, attr ? "values", field ? "", value ? "" }:

let
  inherit (import <nixpkgs> { }) lib;
  inherit (import ./preferences.nix {
    inherit lib file;
    wallpaperDirectory = builtins.toPath root + "/core/wallpapers";
  }) choices values;
  optionalChanges = lib.filterAttrs (name: enabled: values.optionals.${name} != enabled)
    (builtins.fromJSON value);
in
if field == "" then {
  inherit choices values;
  desktop = if values.desktop == null then "machine" else values.desktop;
  states = builtins.concatStringsSep " " (map (enabled: if enabled then "on" else "off") [
    values.optionals.cron
    values.optionals.virtualization
    values.optionals.codex
  ]);
}.${attr} else if field == "optionals" then
  if optionalChanges == { } then choices else
    choices // { optionals = (choices.optionals or { }) // optionalChanges; }
else if field == "theme" then
  choices // { zsh = (choices.zsh or { }) // { theme = if value == "" then null else value; }; }
else if value == "" then
  builtins.removeAttrs choices [ field ]
else
  choices // { ${field} = if field == "desktop" && value == "null" then null else value; }
