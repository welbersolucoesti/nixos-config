{ pkgs, ... }:

{
  # Editor da estação. Extensões e preferências ficam a cargo do usuário.
  environment.systemPackages = [ pkgs.vscode ];
}
