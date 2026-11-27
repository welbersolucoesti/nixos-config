{
  # Valores ilustrativos. A conta precisa existir em users.users na configuração da máquina.
  # Use Gerenciar opcionais no Noir para escolher CRON, Virtualization e Codex CLI.
  personalConfig = {
    desktop = "kde"; # "kde", "gnome", "cinnamon", "xfce" ou null
    # null usa o fundo padrão do Noir. Para personalizar, indique um PNG local legível pela conta.
    # kde.wallpaperSource = "/var/lib/noir/wallpapers/kde.png";
    # cinnamon.wallpaperSource = "/var/lib/noir/wallpapers/cinnamon.png";
    username = "usuario";
    git = {
      userName = "Nome Exemplo";
      userEmail = "autor@example.invalid";
    };
  };
}
