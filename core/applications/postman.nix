{ pkgs, ... }:

{
  # Cliente para testes de APIs. Credenciais de requisições ficam fora da configuração do sistema.
  environment.systemPackages = [ pkgs.postman ];
}
