{ lib, pkgs, ... }:

{
  # Permite pacotes não livres, como o Google Chrome, com prioridade sobre
  # definições comuns de outros módulos.
  nixpkgs.config.allowUnfree = lib.mkForce true;

  # Desabilita o Firefox com prioridade sobre definições comuns de outros módulos.
  # O Google Chrome está incluído nos pacotes do sistema abaixo.
  programs.firefox.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [

    # Utilitários de linha de comando
    vim # Editor de texto no terminal.
    wget # Baixa arquivos pela linha de comando.
    usbutils # Lista e inspeciona dispositivos USB com o lsusb.
    git # Sistema de controle de versões.
    htop # Monitor interativo de processos e recursos do sistema.
    pv # Exibe o progresso de dados que passam por um pipe.

    # Aplicativos gráficos e ferramentas de desenvolvimento
    google-chrome # Navegador web.
    bitwarden-desktop # Gerenciador de senhas com interface gráfica.
    jetbrains.idea # IntelliJ IDEA para desenvolvimento em Java e Kotlin.
    dbeaver-bin # Cliente gráfico para bancos de dados.
    vscode # Editor de código extensível.
    postman # Envia requisições e testa APIs.
    wpsoffice # Suíte de escritório para documentos, planilhas e apresentações.

    # Java
    temurin-bin-25 # Eclipse Temurin JDK 25 para compilar e executar código Java.
  ];
}
