{ lib, file, wallpaperDirectory }:

let
  choices = if builtins.pathExists file then builtins.fromJSON (builtins.readFile file) else { };
  # O JSON contém dados. Os marcadores internos do sistema de módulos são
  # reservados, inclusive dentro de valores que deveriam ser escalares.
  plain = value:
    if builtins.isAttrs value then
      !(value ? _module || value ? _type) && lib.all plain (builtins.attrValues value)
    else if builtins.isList value then lib.all plain value
    else true;
  wallpaperFiles = builtins.readDir wallpaperDirectory;
  inherit (lib) mkOption mkEnableOption types;
  evaluated = lib.evalModules {
    modules = [
      {
        options = {
          desktop = mkOption {
            type = types.nullOr (types.enum [ "kde" "gnome" "cinnamon" "xfce" ]);
            default = null;
          };
          wallpaper = mkOption {
            type = types.addCheck types.str (name: (wallpaperFiles.${name} or null) == "regular");
            default = "nixos-001.png";
          };
          optionals = mkOption {
            type = types.submodule {
              options = {
                cron = mkEnableOption "o agendamento diário de tarefas privadas";
                virtualization = mkEnableOption "as ferramentas de virtualização e contêineres";
                codex = mkEnableOption "o Codex CLI gerenciado pelo Noir";
              };
            };
            default = { };
          };
          zsh = mkOption {
            type = types.submodule {
              options.theme = mkOption {
                type = types.nullOr (types.strMatching "([a-zA-Z0-9_][a-zA-Z0-9_.-]*/)*[a-zA-Z0-9_][a-zA-Z0-9_.-]*");
                default = "bira";
              };
            };
            default = { };
          };
        };
      }
      { config = choices; }
    ];
  };
in
assert lib.assertMsg (builtins.isAttrs choices) "settings.json deve conter um objeto JSON.";
assert lib.assertMsg (plain choices) "settings.json contém propriedades reservadas pelo Nix.";
builtins.deepSeq evaluated.config { inherit choices; values = evaluated.config; }
