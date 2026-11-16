# ==============================================================================
# Configurações pessoais e ambiente de desenvolvimento
# ==============================================================================
{ config, pkgs, lib, ...}:

{
  # ----------------------------------------------------------------------------
  # Política de pacotes e navegadores
  # ----------------------------------------------------------------------------

  # Permite pacotes não livres, como o Google Chrome, com prioridade sobre
  # definições comuns de outros módulos.
  nixpkgs.config.allowUnfree = lib.mkForce true;

  # Desabilita o Firefox com prioridade sobre definições comuns de outros módulos.
  # O Google Chrome está incluído nos pacotes do sistema abaixo.
  programs.firefox.enable = lib.mkForce false;


  # ----------------------------------------------------------------------------
  # Pacotes globais do sistema
  # ----------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [

    # Utilitários de linha de comando
    vim
    wget
    usbutils
    git
    htop

    # Aplicativos gráficos e ferramentas de desenvolvimento
    google-chrome
    bitwarden-desktop
    jetbrains.idea
    dbeaver-bin
    vscode

    # Java: Eclipse Temurin JDK 25
    temurin-bin-25
  ];


  # ----------------------------------------------------------------------------
  # Hardware, biometria e autorização
  # ----------------------------------------------------------------------------

  # Habilita o serviço de biometria; o cadastro das digitais é feito separadamente.
  services.fprintd.enable = true;
  # Habilita o Polkit para autorização de ações privilegiadas.
  security.polkit.enable = true;

  # Habilita o Bluetooth e liga o adaptador automaticamente na inicialização.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ----------------------------------------------------------------------------
  # Serviços e shell
  # ----------------------------------------------------------------------------

  # PostgreSQL 18 para desenvolvimento local, com acesso TCP restrito a localhost.
  services.postgresql = {

    enable = true;
    package = pkgs.postgresql_18;

    settings = {
      listen_addresses = "localhost";
      port = 5432;
      password_encryption = "scram-sha-256";
    };

    authentication = "
      host all all 127.0.0.1/32   scram-sha-256
      host all all ::1/128        scram-sha-256
    ";
  };

  # Zsh com autocompletar, sugestões automáticas e destaque de sintaxe.
  programs.zsh = {

    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    # Oh My Zsh com tema bira e plugins git e sudo.
    ohMyZsh = {
      enable = true;
      plugins = ["git" "sudo"];
      theme = "bira";
    };
  };

  # Define o shell do usuário david; adapte o nome ao reutilizar o módulo.
  users.users.david.shell = pkgs.zsh;


  # ---------------------------------------------------------------------------
  # Atalhos de terminal para manutenção do NixOS
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Git: identidade e branch inicial em /etc/gitconfig (escopo do sistema)
  # ---------------------------------------------------------------------------
  environment.etc."gitconfig".text = ''
    [user]
      name = David
      email = welbersolucoesti@gmail.com

    [init]
      defaultBranch = main
  '';


  # ----------------------------------------------------------------------------
  # Remapeamento de teclado
  # ----------------------------------------------------------------------------

  # Configura o keyd independentemente dos atalhos do ambiente gráfico.
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ]; # Aplica a regra aos teclados gerenciados pelo serviço.
        settings = {
          main = {
            # Mapeia LeftShift + LeftMeta + F23 para reproduzir/pausar mídia.
            # Confirme se a tecla Copilot do teclado emite essa combinação.
            "leftshift+leftmeta+f23" = "playpause";
          };
        };
      };
    };
  };

}
