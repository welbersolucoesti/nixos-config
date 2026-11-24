{ config, lib, pkgs, ... }:

{
  imports = [ ./cinnamon/session.nix ];

  config = lib.mkIf (config.personalConfig.desktop == "cinnamon") {
    services.xserver.enable = true;
    services.xserver.desktopManager.cinnamon.enable = true;
    services.displayManager.defaultSession = "cinnamon";
    services.xserver.displayManager.lightdm = {
      enable = true;
      background = "#202126";
      greeters.slick = {
        enable = true;
        theme.name = "Mint-Y-Dark-Aqua";
        iconTheme.name = "Mint-Y-Aqua";
        cursorTheme.size = 24;
        draw-user-backgrounds = false;
      };
    };

    # O bloqueador desta versão da Cinnamon está disponível em X11.
    nixpkgs.overlays = [
      (_: prev: {
        cinnamon = prev.cinnamon.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            for applet in menu grouped-window-list; do
              test -f "$out/share/cinnamon/applets/$applet@cinnamon.org/settings-schema.json"
            done
            install -m 644 ${./cinnamon/menu.json} \
              "$out/share/cinnamon/applets/menu@cinnamon.org/settings-override.json"
            install -m 644 ${./cinnamon/grouped-window-list.json} \
              "$out/share/cinnamon/applets/grouped-window-list@cinnamon.org/settings-override.json"
            rm "$out/share/wayland-sessions/cinnamon-wayland.desktop"
          '';
          passthru = old.passthru // {
            providedSessions = lib.remove "cinnamon-wayland" old.passthru.providedSessions;
          };
        });
      })
    ];

    environment.systemPackages = [ pkgs.nixos-icons ];

    assertions = [
      {
        assertion = !config.services.desktopManager.plasma6.enable
          && !config.services.xserver.desktopManager.xfce.enable;
        message = "O perfil Cinnamon requer que Plasma e XFCE estejam desabilitados nos módulos da máquina.";
      }
      {
        assertion = !config.services.displayManager.sddm.enable
          && !config.services.displayManager.gdm.enable;
        message = "O perfil Cinnamon usa LightDM. Remova a ativação de SDDM ou GDM dos módulos da máquina.";
      }
    ];
  };
}
