{ config, ... }:

{
  # O Oh My Zsh usa tema vazio quando a preferência local é null.
  config.programs.zsh.ohMyZsh.theme =
    if config.personalConfig.zsh.theme == null then "" else config.personalConfig.zsh.theme;
}
