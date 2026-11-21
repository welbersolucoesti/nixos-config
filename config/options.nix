{ config, lib, ... }:

let
  inherit (config.personalConfig) username;
in
{
  # O arquivo local fornece a identidade e as escolhas da estação.
  options.personalConfig = {
    desktop = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "kde" "xfce" ]);
      default = null;
      description = "Perfil de desktop. Por padrão, o desktop é definido pela configuração da máquina.";
    };

    cron.enable = lib.mkEnableOption "o agendamento diário de tarefas privadas";
    virtualization.enable = lib.mkEnableOption "as ferramentas de virtualização e contêineres";

    zsh.theme = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = "bira";
      description = "Tema do Oh My Zsh. Use null para desativar o tema.";
    };

    username = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[a-z_][a-z0-9_-]{0,31}");
      default = null;
      description = "Nome de uma conta normal já declarada na configuração da máquina.";
    };

    # A autoria é validada na avaliação. O instalador a aplica ao Git da conta na primeira publicação.
    git.userName = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[^[:cntrl:]<>]*[^[:space:][:cntrl:]<>][^[:cntrl:]<>]*");
      default = null;
      description = "Nome de autoria dos commits Git.";
    };

    git.userEmail = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[^[:space:][:cntrl:]<>@]+@[^[:space:][:cntrl:]<>@]+");
      default = null;
      description = "Endereço de autoria dos commits Git.";
    };
  };

  config.assertions = [
    {
      assertion = username != null || !(config.personalConfig.cron.enable || config.personalConfig.virtualization.enable);
      message = "Defina personalConfig.username para habilitar o agendamento ou a virtualização.";
    }
    {
      assertion = username == null || (config.users.users.${username}.isNormalUser or false);
      message = "personalConfig.username deve indicar uma conta normal existente em users.users na configuração da máquina.";
    }
  ];
}
