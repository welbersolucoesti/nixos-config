{ config, lib, pkgs, ... }:

let
  upstream = "${pkgs.lxqt.lxqt-themes}/share/lxqt/themes/system";
  noirTheme = pkgs.linkFarm "lxqt-theme-noir" {
    "share/lxqt/themes/noir/lxqt-panel.qss" = ./noir-panel.qss;
    "share/lxqt/themes/noir/mainmenu.svg" =
      "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    "share/lxqt/themes/noir/spacer-plugin" = "${upstream}/spacer-plugin";
  };

  # O Blueman publica nomes próprios mesmo no modo simbólico.
  bluetoothIcons = {
    blueman-disabled = "network-bluetooth-inactive-symbolic";
    blueman-tray = "network-bluetooth-symbolic";
    blueman-active = "network-bluetooth-activated-symbolic";
  };
  iconRoot = "share/icons/noir-breeze-dark";
  noirIcons = pkgs.linkFarm "noir-lxqt-panel-icons" (
    {
      "${iconRoot}/index.theme" = pkgs.writeText "noir-breeze-dark-index.theme" ''
        [Icon Theme]
        Name=Noir Breeze Dark
        Inherits=breeze-dark
        Directories=status

        [status]
        Size=22
        Type=Scalable
        MinSize=12
        MaxSize=64
        Context=Status
      '';
    }
    // lib.foldlAttrs (
      links: name: icon:
      let
        source = "${pkgs.kdePackages.breeze-icons}/share/icons/breeze-dark/status/22/${icon}.svg";
      in
      links // {
        "${iconRoot}/status/${name}.svg" = source;
        "${iconRoot}/status/${name}-symbolic.svg" = source;
      }
    ) { } bluetoothIcons
  );
in
{
  config = lib.mkIf (config.personalConfig.desktop == "lxqt") {
    environment.systemPackages = [ noirTheme noirIcons ];
    # Opção nativa. Uma escolha pessoal de iconType continua tendo precedência.
    environment.etc."xdg/lxqt/lxqt-powermanagement.conf".text = ''
      [General]
      useThemeIcons=true
    '';
  };
}
