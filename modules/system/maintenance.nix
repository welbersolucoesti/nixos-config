{
  # Habilita a interface 'nix' moderna sem habilitar Flakes.
  nix.settings.experimental-features = [ "nix-command" ];

  # Executa a coleta de lixo semanalmente, removendo gerações elegíveis
  # com mais de 60 dias. Gerações removidas não podem ser usadas para rollback.
  # Não elimina objetos ainda referenciados por perfis ou raízes do Nix.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 60d";
  };

  # Define aliases globais para os shells dos usuários, incluindo o Zsh.
  environment.shellAliases = {
    # Atualiza os canais configurados para o usuário root.
    nix-update = "sudo nix-channel --update";

    # Executa um dry-build: avalia e planeja, sem compilação completa nem ativação.
    nix-check = "nixos-rebuild dry-build";

    # Constrói a configuração do sistema sem ativá-la.
    nix-system-build = "nixos-rebuild build";

    # Constrói e ativa a configuração; uso manual exclusivo do proprietário.
    nix-switch = "sudo nixos-rebuild switch";

    # Lista as gerações preservadas do sistema.
    nix-generations = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

    # Compara dois caminhos de gerações informados como argumentos, na ordem dada.
    nix-diff = "nix --extra-experimental-features 'nix-command' store diff-closures";
  };
}
