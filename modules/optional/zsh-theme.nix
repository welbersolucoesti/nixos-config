{ config, ... }:

{
  config.programs.zsh.ohMyZsh.theme =
    if config.personalConfig.zsh.theme == null then "" else config.personalConfig.zsh.theme;
}
