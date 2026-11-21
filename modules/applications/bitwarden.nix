{ pkgs, ... }:

{
  # Cliente de senhas. Contas e cofres são gerenciados pelo aplicativo.
  environment.systemPackages = [ pkgs.bitwarden-desktop ];
}
