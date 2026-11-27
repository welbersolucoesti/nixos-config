# Cinnamon

[Projeto](../../README.md) · [Índice](../README.md)

O perfil oferece a sessão X11, com LightDM e Slick Greeter em grafite. O módulo remove a entrada Wayland do Cinnamon e rejeita KDE Plasma, XFCE, SDDM e GDM habilitados na configuração da máquina. Consulte o [módulo do perfil](../../core/desktops/cinnamon.nix).

## Sessão e aparência

- A sessão usa Mint-Y-Dark-Aqua, ícones `Papirus-XApp-Dark` e cursor Bibata de tamanho 24. O tema de ícones da sessão herda de Papirus-Dark. O Slick Greeter usa seus próprios ícones Mint-Y-Aqua e fundo grafite. O portal XApp publica a preferência por modo escuro.
- O painel superior permanente de 38 px lógicos coloca o menu de aplicativos e a lista de janelas à esquerda, o relógio ao centro e os indicadores e controles de áreas à direita. O floco do NixOS é configurado no próprio applet do menu.
- O painel inferior de 42 px centraliza o applet de tarefas agrupadas e se recolhe conforme a janela em foco. Os fixados iniciais são Chrome, IntelliJ IDEA, Visual Studio Code, DBeaver e Nemo. Chrome e Nemo são as associações oferecidas para links e pastas.
- A sessão usa duas áreas fixas, `Work 1` e `Work 2`, sem navegação circular. O touchpad recebe rolagem natural. O Noir desativa o salvamento de sessão do Cinnamon e mantém o autostart XDG. Uma entrada pessoal com o mesmo nome pode substituir a do Bitwarden.
- O [papel de parede compartilhado](../configuration.md#preferências) é definido no fundo da sessão. A aparência da tela de login é configurada à parte.

O Noir bloqueia em dconf várias chaves de layout, aparência e teclado. Alguns applets guardam preferências da conta em JSON, independentemente dessas chaves.

## NumLock

O Slick Greeter liga o NumLock ao abrir. Antes de iniciar a sessão, o LightDM executa `numlockx on` e registra eventual falha em `journalctl -b -t noir-cinnamon-numlock`, sem impedir o login. Na sessão, a lembrança do estado anterior fica desabilitada. A tecla continua disponível e o comportamento do LED depende do dispositivo.

## Terminal e atalhos

`Super+N` abre o Noir no GNOME Terminal. No login, o perfil acrescenta a entrada do Noir à lista de atalhos personalizados quando ela está ausente, preservando as demais entradas. `Super+L` chama o bloqueador nativo, junto de `Ctrl+Alt+L` e `XF86ScreenSaver`. O perfil desabilita o atalho do Looking Glass e deixa vazia a combinação padrão para abrir o applet de notificações.

As novas janelas do GNOME Terminal abrem sem barra de menus e o padrão do perfil do terminal oculta a barra de rolagem. A roda do mouse e `Shift+Page Up` e `Shift+Page Down` continuam disponíveis para consultar o histórico. A barra de menus é configurada para o aplicativo e a rolagem, por perfil do terminal.

## Diagnóstico do layout e validação gráfica

Em uma conta de teste, compare as chaves gerenciadas pelo [módulo de sessão](../../core/desktops/cinnamon/session.nix) com os JSON pessoais dos applets. O menu e a lista de tarefas do layout Noir usam as instâncias `menu@cinnamon.org/1000.json` e `grouped-window-list@cinnamon.org/1013.json`. Os arquivos podem estar em `${XDG_CONFIG_HOME:-$HOME/.config}/cinnamon/spices/` ou, em contas antigas, em `~/.cinnamon/configs/`. Preserve esses arquivos antes de qualquer ajuste. Um reset de dconf pela conta não altera as chaves bloqueadas pelo perfil.

Em uma VM ou instalação de teste, confira o greeter, o NumLock, os dois painéis, o bloqueio, a bandeja e os atalhos. Teste escala e múltiplos monitores, ocultação do painel inferior, a posição do relógio, o autostart do Bitwarden e a ausência de janelas restauradas. Compare uma conta nova com uma que já possua preferências dos applets.

[GNOME](gnome.md) · [XFCE](xfce.md)
