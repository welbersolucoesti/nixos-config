{ config, lib, pkgs, ... }:

let
  dock = pkgs.crystal-dock;
in
{
  options.noir.lxqt.crystalDock.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Reserva a borda inferior da LXQt para o Crystal Dock candidato.";
  };

  config = lib.mkIf (config.personalConfig.desktop == "lxqt" && config.noir.lxqt.crystalDock.enable) {
    assertions = [{
      assertion = dock.version == "2.16";
      message = "O preset LXQt Noir foi validado com Crystal Dock 2.16. Revise-o ao atualizar o pacote.";
    }];

    # O Dolphin integra a lista de lançadores do KDE Noir. O PCManFM-Qt segue como desktop.
    environment.systemPackages = [ dock pkgs.kdePackages.dolphin ];

    # O Crystal Dock copia o preset no primeiro uso e preserva configurações pessoais.
    # Arquivos regulares conservam a permissão de escrita quando copiados pelo usuário.
    environment.etc = {
      "xdg/crystal-dock/LXQt/appearance.conf" = {
        mode = "0644";
        text = ''
          [General]
          # Flat2D_Floating
          panelStyle=2
          minimumIconSize=34
          maximumIconSize=34
          spacingFactor=0.24
          floatingMargin=6
          backgroundColor2D=#ed202326
          activeIndicatorColor2D=#3daee9
          inactiveIndicatorColor2D=#a1a9b1
          bouncingLauncherIcon=false
          tooltipFontSize=10

          [TaskManager]
          groupTasksByApplication=true
          currentDesktopTasksOnly=false
          currentScreenTasksOnly=true
        '';
      };
      "xdg/crystal-dock/LXQt/panel_1.conf" = {
        mode = "0644";
        text = ''
          [General]
          # Bottom / IntelligentAutoHide
          position=1
          visibility=3
          screen=0
          showTaskManager=true
          showApplicationMenu=false
          showPager=false
          showTrash=false
          showWifiManager=false
          showVolumeControl=false
          showBatteryIndicator=false
          showKeyboardLayout=false
          showVersionChecker=false
          showClock=false
          launchers="google-chrome;idea;code;dbeaver;org.kde.dolphin"
        '';
      };
    };

    systemd.user.services.noir-lxqt-crystal-dock = {
      description = "Crystal Dock da sessão LXQt do Noir";
      wantedBy = [ "noir-lxqt-session.target" ];
      partOf = [ "noir-lxqt-session.target" ];
      serviceConfig = {
        Type = "exec";
        ExecStart = lib.getExe dock;
        Environment = "QT_QPA_PLATFORM=wayland";
      };
    };
  };
}
