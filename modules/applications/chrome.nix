{ pkgs, ... }:

{
  # Navegador da estação. O pacote depende da política de software proprietário.
  environment.systemPackages = [ pkgs.google-chrome ];
}
