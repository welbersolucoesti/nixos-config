{ lib, ... }:

{
  imports = [
    ./modules/system/packages.nix
    ./modules/system/hardware.nix
    ./modules/system/maintenance.nix
    ./modules/system/postgresql.nix
    ./modules/personal.nix
    ./modules/desktops/kde.nix
    ./modules/desktops/xfce.nix
  ];

  options.personalConfig.desktop = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "kde" "xfce" ]);
    default = null;
    description = "Perfil de desktop. Por padrão, o desktop é definido pela configuração da máquina.";
  };
}
