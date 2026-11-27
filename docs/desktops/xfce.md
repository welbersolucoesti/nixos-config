# XFCE

[Projeto](../../README.md) · [Índice](../README.md)

O perfil configura XFCE em X11 com LightDM e GTK Greeter. O [módulo do perfil](../../core/desktops/xfce.nix) rejeita KDE Plasma e SDDM habilitados na configuração da máquina. Áudio, rede e energia dependem dos serviços da máquina.

## Sessão e aparência

A sessão usa Orchis-Dark no GTK e no Xfwm4, Papirus-Dark nos ícones e cursor Breeze de tamanho 24. Bibata e Tela continuam disponíveis. O perfil publica a preferência escura e oferece integração GTK aos aplicativos Qt quando a conta ainda não definiu outro tema de plataforma. O Picom faz a composição em sessões XFCE X11, com XRender e VSync.

O [papel de parede compartilhado](../configuration.md#preferências) é usado como fallback do desktop e do bloqueador. No login X11, o Noir também atualiza as propriedades conhecidas de fundo para usar a imagem declarada e desabilita a troca automática nesses monitores e áreas de trabalho. Ajustes feitos na interface podem ser substituídos em um novo login.

O LightDM liga o NumLock antes do greeter. Na sessão, o perfil fixa os valores de NumLock e restauração no canal `keyboards`. A tecla continua disponível. O efeito no LED e a digitação dependem do dispositivo e do mapa XKB.

## Painéis iniciais

- **Superior de 38 px.** Inclui Whisker com o floco do NixOS, relógio de 24 horas, menu de janelas, bandeja, seletor de áreas e ações da sessão. Volume e bateria dependem dos componentes habilitados.
- **Inferior de 42 px.** O Docklike experimental é centralizado, recolhe quando a janela em foco o sobrepõe e começa com navegador preferido, IntelliJ IDEA, Visual Studio Code, DBeaver e Thunar. Se o navegador mudar após a criação do painel, ajuste o item fixado para agrupar suas janelas.
- **Áreas e bandeja.** As áreas iniciais são `Work 1` e `Work 2`, sem navegação circular. A ordem de rede e Bluetooth na bandeja depende de como os applets se registram.

O Noir importa o modelo para contas sem estado do painel. Um estado existente, inclusive parcial, é preservado. A entrada de autostart do Plank do Noir só inicia o Plank sem a marca do layout Docklike. O XFCE mantém seu gerenciamento de sessões salvas, e uma entrada pessoal de autostart pode substituir a do Bitwarden.

O perfil inclui integração com Blueman, preferências do Chrome para links e HTML e o auxiliar WebBrowser do XFCE. O painel pode incluir volume, Pavucontrol e bateria conforme os componentes disponíveis. Mugshot, Clipman e Thunar com Xarchiver integram o perfil.

## Terminal e atalhos

`Super+N` abre o Noir no XFCE Terminal. O terminal usa DejaVu Sans Mono 11, opacidade inicial de 90% e o atalho `Ctrl+Alt+T`. A configuração inicial oculta as barras de menus, ferramentas e rolagem. O menu de contexto permite reexibir a barra de menus. A tecla Super esquerda, usada sozinha, abre o Whisker por meio de `Shift+Alt+F11`. `Super+L` chama `xflock4`, que usa o bloqueador disponível na sessão.

## Biometria

Na própria conta, `biometria` verifica se o fprintd detecta um leitor e inicia o cadastro. Para selecionar outro dedo, use `biometria -f left-index-finger`. Consulte [Impressões digitais](../applications.md#impressões-digitais) para os comandos comuns.

O LightDM usa a pilha PAM de login do NixOS com fprintd. O bloqueador `xfce4-screensaver`, quando habilitado, e a pilha `polkit-1` recebem uma tentativa de digital com prazo de 10 segundos, antes da alternativa por senha. Confirme o comportamento em equipamento compatível, incluindo a passagem da digital para a senha no greeter.

## Validação gráfica

Use uma conta nova e outra com painel ou Plank existentes em uma instalação de teste. Confira painel, atalhos, NumLock, tela de bloqueio, wallpaper em mais de um monitor, maximização, tela cheia e autostart. Troque o navegador e observe o agrupamento no Docklike. A homologação do Docklike depende desses testes gráficos.

[Cinnamon](cinnamon.md)
