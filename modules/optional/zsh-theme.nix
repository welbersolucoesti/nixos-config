{ config, lib, ... }:

{
  options.personalConfig.zsh.theme = lib.mkOption {
    type = lib.types.nullOr lib.types.nonEmptyStr;
    default = "bira";
    description = "Tema do Oh My Zsh. Use null para desativar o tema.";
  };

  config.programs.zsh.ohMyZsh.theme =
    if config.personalConfig.zsh.theme == null then "" else config.personalConfig.zsh.theme;
}
