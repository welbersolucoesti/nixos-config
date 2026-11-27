{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # O LightDM roda setupCommands no servidor X antes de iniciar o greeter.
    services.xserver.displayManager.setupCommands = lib.mkAfter ''
      ${pkgs.numlockx}/bin/numlockx on || true
    '';

    # O xfsettingsd restaura este valor ao iniciar e ao detectar outro teclado.
    # O bloqueio impede que o último estado gravado substitua o padrão.
    environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/keyboards.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="keyboards" version="1.0">
        <property name="Default" type="empty">
          <property name="RestoreNumlock" type="bool" value="true" unlocked="root"/>
          <property name="Numlock" type="bool" value="true" unlocked="root"/>
        </property>
      </channel>
    '';
  };
}
