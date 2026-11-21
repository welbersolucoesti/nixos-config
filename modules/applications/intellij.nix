{ pkgs, ... }:

{
  # IDE para projetos Java e Kotlin. O JDK do terminal é mantido no módulo Temurin.
  environment.systemPackages = [ pkgs.jetbrains.idea ];
}
