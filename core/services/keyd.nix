{
  # O remapeamento funciona fora da sessão gráfica e vale para todos os teclados gerenciados.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        # Confirme com keyd monitor se a tecla do notebook emite essa combinação.
        "leftshift+leftmeta+f23" = "playpause";
      };
    };
  };
}
