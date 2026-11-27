# KDE Plasma

[Projeto](../../README.md) · [Índice](../README.md)

O perfil habilita KDE Plasma 6 com SDDM. Selecione a sessão Wayland no login quando disponível. O módulo rejeita XFCE e LightDM habilitados na configuração da máquina. Consulte o [módulo do perfil](../../core/desktops/kde.nix).

## Sessão e aparência

- **Breeze Dark (Noir)** usa a aparência Breeze Dark e o layout inicial do Noir. O painel superior flutuante tem 38 px lógicos, com Kickoff, lista de janelas, relógio, bandeja e seletor de áreas de trabalho. O painel inferior tem 42 px lógicos, ajusta-se ao conteúdo e se recolhe quando sobreposto.
- O painel inferior começa com navegador preferido, IntelliJ IDEA, Visual Studio Code, DBeaver e Dolphin. O Kickoff usa o floco do NixOS e inclui Configurações do Sistema e Postman nos favoritos iniciais.
- O KWin configura duas áreas em uma linha, `Work 1` e `Work 2`, sem navegação circular, e habilita Glide e Lâmpada Mágica. O perfil define rolagem natural para touchpads e NumLock ligado pelo KConfig. A bandeja usa os componentes disponíveis na revisão instalada e depende dos serviços e do hardware da máquina.
- O Plasma inicia uma sessão vazia a cada login. Aplicativos com autostart continuam disponíveis. O Bitwarden usa uma entrada XDG que pode ser substituída por uma entrada pessoal com o mesmo nome.
- O [papel de parede do Noir](../configuration.md#preferências) é usado pelo pacote do tema e pela tela de bloqueio. Um serviço de usuário reaplica a imagem da área de trabalho quando o `plasmashell` inicia. Layout do painel, imagem reaplicada e chaves fixadas por KConfig seguem mecanismos distintos.

## Terminal e atalho

`Meta+N` abre o Noir no Konsole. O perfil de sistema **Noir** é o padrão quando a conta ainda não escolheu outro perfil. A configuração inicial oculta as barras de menus, ferramentas e rolagem. A barra de abas aparece quando há mais de uma aba. O Konsole pode alternar a barra de menus com `Ctrl+Shift+M`.

## Validação gráfica

Em uma instalação de teste, confira o login Wayland, painéis, favoritos, bandeja, efeitos, atalho do Noir e as duas áreas de trabalho. Em uma conta de teste existente, confira quais alterações persistem após novo login, como widgets e favoritos, e verifique a reaplicação do wallpaper, a sessão vazia e o início único do Bitwarden.

[GNOME](gnome.md)
