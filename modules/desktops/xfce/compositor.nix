{ config, lib, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # O Xfwm4 já habilita sombras de janela e composição por padrão no X11.
    assertions = [
      {
        assertion = !config.services.picom.enable;
        message = "O perfil XFCE Noir usa o compositor do Xfwm4. Desabilite services.picom.enable.";
      }
    ];
  };
}
