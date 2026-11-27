{ pkgs, ... }:

{
  # Cliente de bancos de dados. Conexões e credenciais ficam no perfil do usuário.
  environment.systemPackages = [ pkgs.dbeaver-bin ];
}
