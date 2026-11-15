# ==============================================================================
# Configurações Pessoais e Ambiente de Desenvolvimento
# ==============================================================================
{ config, pkgs, lib, ...}:

{
  # ----------------------------------------------------------------------------
  # Política de Pacotes e Navegadores
  # ----------------------------------------------------------------------------

  # Desabilita o Firefox padrão do sistema (usando Google Chrome como principal)
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

    # Linguagens e SDKs
    temurin-bin-25 # Java
  ];


  # ----------------------------------------------------------------------------
  # Hardware, Biometria e Segurança
  # ----------------------------------------------------------------------------

  # Suporte ao leitor de impressão digital (fprintd) e autenticação via Polkit
  services.fprintd.enable = true;
  security.polkit.enable = true;

  # Habilita o stack Bluetooth e liga o adaptador automáticamente no boot
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ----------------------------------------------------------------------------
  # Declaração e disponibilização de serviços
  # ----------------------------------------------------------------------------

  # PostgreSQL (Ambiente local e descartável) ----------------------------------
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

  # ZSH ------------------------------------------------------------------------
  programs.zsh = {

    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    # Habilita o Oh My Zsh
    ohMyZsh = {
      enable = true;
      plugins = ["git" "sudo"];
      theme = "bira";
    };
  };

  # Validar o nome do usuário definido no sistema
  users.users.david.shell = pkgs.zsh;


  # ----------------------------------------------------------------------------
  # Configurações diversas
  # ----------------------------------------------------------------------------

  # Remapeamento de teclado em baixo nível (Wayland + X11)
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            # Intercepta a combinação física da tecla Copilot (LeftShift + LeftMeta + F23)
            "leftshift+leftmeta+f23" = "playpause";
          };
        };
      };
    };
  };

}
