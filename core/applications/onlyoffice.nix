{ pkgs, ... }:

let
  # O QSettings consulta os padrões do sistema depois das preferências pessoais.
  defaults = pkgs.writeText "DesktopEditors.conf" ''
    [General]
    locale=pt-BR
    UITheme=theme-night
  '';

  onlyoffice = pkgs.onlyoffice-desktopeditors.override {
    buildFHSEnv = args: pkgs.buildFHSEnv (args // {
      # O ambiente FHS do pacote tem um /etc próprio.
      extraBwrapArgs = (args.extraBwrapArgs or [ ]) ++ [
        "--ro-bind ${defaults} /etc/xdg/onlyoffice/DesktopEditors.conf"
      ];
    });
  };
in
{
  environment.systemPackages = [ onlyoffice ];
}
