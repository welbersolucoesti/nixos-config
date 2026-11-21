{ config, lib, pkgs, utils, ... }:

let
  inherit (config.personalConfig) username;
  script = "${config.users.users.${username}.home}/.local/share/nixos-cron/cron.sh";
in
{
  config = lib.mkIf (config.personalConfig.cron.enable && username != null) {
    # ----------------------------------------------------------------------------
    # Execução do script privado
    # ----------------------------------------------------------------------------

    systemd.services.nixos-cron = {
      description = "Executa o script privado de agendamento";

      # Ignora a execução se o script privado ainda não tiver sido criado.
      unitConfig.ConditionPathExists = lib.replaceStrings [ "%" ] [ "%%" ] script;

      # Disponibiliza utilitários básicos sem depender do Zsh interativo.
      path = with pkgs; [
        coreutils
        findutils
        gnugrep
        gnused
        gawk
      ];

      serviceConfig = {
        # Executa a tarefa até sua conclusão, sem manter um serviço contínuo.
        Type = "oneshot";

        # Executa sem privilégios de root.
        User = username;

        # O Bash lê o arquivo externo em tempo de execução, sem copiá-lo ao Nix Store.
        # Alterações no conteúdo do script privado não exigem rebuild.
        ExecStart = utils.escapeSystemdExecArgs [ "${pkgs.bash}/bin/bash" script ];
      };
    };


    # ----------------------------------------------------------------------------
    # Agendamento pelo systemd
    # ----------------------------------------------------------------------------

    systemd.timers.nixos-cron = {
      description = "Agenda o script privado diariamente às 03h00";

      # Habilita o timer junto aos demais timers do sistema.
      wantedBy = [ "timers.target" ];

      timerConfig = {
        # Executa diariamente às 03h00, no fuso horário local da máquina.
        OnCalendar = "*-*-* 03:00:00";

        # Não recupera execuções perdidas enquanto o computador estava desligado.
        Persistent = false;
      };
    };
  };
}
