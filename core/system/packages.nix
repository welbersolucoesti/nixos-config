{ lib, ... }:

{
  # A política se aplica a toda a máquina e permite os aplicativos proprietários do perfil.
  nixpkgs.config.allowUnfree = lib.mkForce true;

}
