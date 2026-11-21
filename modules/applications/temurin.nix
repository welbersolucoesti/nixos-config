{ pkgs, ... }:

{
  # JDK 25 global para compilar e executar Java na linha de comando.
  environment.systemPackages = [ pkgs.temurin-bin-25 ];
}
