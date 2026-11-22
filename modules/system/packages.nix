{ lib, pkgs, ... }:

{
  # A política se aplica a toda a máquina e permite os aplicativos proprietários do perfil.
  nixpkgs.config.allowUnfree = lib.mkForce true;

  # Ferramentas de uso geral sem ajustes declarativos próprios.
  environment.systemPackages = with pkgs; [ wget usbutils git htop pv inkscape gimp fastfetch ];
}
