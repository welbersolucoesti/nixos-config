{ lib, ... }:

{
  # Mantém a política de navegador da estação, inclusive perante defaults de outros módulos.
  programs.firefox.enable = lib.mkForce false;
}
