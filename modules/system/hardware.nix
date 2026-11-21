{
  # Habilita o serviço de biometria; o cadastro das digitais é feito separadamente.
  services.fprintd.enable = true;
  # Habilita o Polkit para autorização de ações privilegiadas.
  security.polkit.enable = true;

  # Habilita o Bluetooth e liga o adaptador automaticamente na inicialização.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Usa RAM comprimida como swap, sem criar partição ou arquivo swap no disco.
  # O limite lógico de 50% não reserva antecipadamente metade da RAM.
  # ZRAM não substitui swap em disco para hibernação.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

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
