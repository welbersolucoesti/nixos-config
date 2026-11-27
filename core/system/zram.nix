{
  # O limite lógico de 50% não reserva RAM antecipadamente. Hibernação exige swap em disco.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
}
