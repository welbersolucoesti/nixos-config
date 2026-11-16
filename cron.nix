# ==============================================================================
# Agendamento diário de tarefas privadas
# ==============================================================================
{ pkgs, ...}:

{
  # ----------------------------------------------------------------------------
  # Execução do script privado
  # ----------------------------------------------------------------------------

  systemd.services.david-cron = {
    description = "Executa o script privado de agendamento de david";

    # Ignora a execução se o script privado ainda não tiver sido criado.
    unitConfig.ConditionPathExists = "/home/david/.local/share/nixos-cron/cron.sh";

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

      # Executa sem privilégios de root; adapte o usuário e os caminhos juntos.
      User = "david";

      # O Bash lê o arquivo externo em tempo de execução, sem copiá-lo ao Nix Store.
      # Alterações no conteúdo do script privado não exigem rebuild.
      ExecStart = "${pkgs.bash}/bin/bash /home/david/.local/share/nixos-cron/cron.sh";
    };
  };


  # ----------------------------------------------------------------------------
  # Agendamento pelo systemd
  # ----------------------------------------------------------------------------

  systemd.timers.david-cron = {
    description = "Agenda o script privado de david diariamente às 03h00";

    # Habilita o timer junto aos demais timers do sistema.
    wantedBy = [ "timers.target" ];

    timerConfig = {
      # Executa diariamente às 03h00, no fuso horário local da máquina.
      OnCalendar = "*-*-* 03:00:00";

      # Não recupera execuções perdidas enquanto o computador estava desligado.
      Persistent = false;
    };
  };
}
