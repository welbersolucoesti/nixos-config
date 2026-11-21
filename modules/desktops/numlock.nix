{ config, lib, pkgs, ... }:

{
  config = lib.mkMerge [
    (lib.mkIf (config.personalConfig.desktop == "xfce") {
      # O autostart roda na sessão X11, após o início dos serviços do XFCE.
      environment.etc."xdg/autostart/xfce-numlock.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=NumLock
        Exec=${pkgs.numlockx}/bin/numlockx on
        OnlyShowIn=XFCE;
        NoDisplay=true
      '';
    })
    (lib.mkIf (config.personalConfig.desktop == "kde") {
      # O Plasma aplica o padrão na sessão, inclusive em Wayland.
      environment.etc."xdg/kcminputrc".text = ''
        [Keyboard]
        NumLock=0
      '';
    })
  ];
}
