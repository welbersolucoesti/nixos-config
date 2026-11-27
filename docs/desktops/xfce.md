# XFCE

[Projeto](../../README.md) · [Índice](../README.md) · [Ambientes gráficos](../README.md#ambientes-gráficos)

## Visão geral

O perfil organiza aplicativos, janelas e controles de sessão com componentes do XFCE. O Docklike experimental fornece um painel de tarefas para as contas que recebem o modelo inicial.

## Sessão gráfica

O Noir configura XFCE em X11 com LightDM, o gerenciador de login, e GTK Greeter, a interface de entrada. O módulo rejeita KDE Plasma ou SDDM habilitados na configuração da máquina. O XFCE mantém seu gerenciamento de sessões salvas. O Picom compõe a sessão X11 com XRender e VSync. [Módulo do perfil](../../core/desktops/xfce.nix)

## Aparência

A sessão usa Orchis-Dark no GTK e no Xfwm4, Papirus-Dark nos ícones e cursor Breeze de tamanho 24. Bibata e Tela continuam disponíveis. O [papel de parede escolhido no Noir](../configuration.md#preferências) serve como imagem de reserva para a área de trabalho e o bloqueador.

## Painéis e navegação

| Componente | Comportamento |
| --- | --- |
| Painel superior | Com 38 px lógicos, Whisker com o floco do NixOS, relógio de 24 horas, menu de janelas, bandeja, seletor de áreas e ações da sessão. |
| Painel inferior | Com 42 px lógicos e Docklike experimental. É centralizado, recolhe quando a janela em foco o sobrepõe e começa com navegador preferido, IntelliJ IDEA, Visual Studio Code, DBeaver e Thunar. |
| Áreas de trabalho | `Work 1` e `Work 2`, sem navegação circular. |

O perfil preserva estados de painel já existentes, inclusive parciais. A entrada de início automático do Plank só o inicia quando a marca do layout Docklike está ausente. [Modelo de painel](../../core/desktops/xfce/panel-default.xml) · [Importação do modelo](../../core/desktops/xfce/panel.nix)

## Integrações

O perfil integra Blueman, Chrome para links e HTML, o auxiliar WebBrowser do XFCE, Mugshot, Clipman e Thunar com Xarchiver. O painel pode mostrar volume, Pavucontrol e bateria conforme os componentes disponíveis. Áudio, rede e energia dependem dos serviços da máquina. Aplicativos Qt recebem integração GTK se a conta ainda não tiver definido outro tema de plataforma. Uma entrada pessoal de início automático pode substituir a do Bitwarden.

## Terminal

O lançador do Noir usa XFCE Terminal. A configuração inicial usa DejaVu Sans Mono 11, opacidade de 90% e oculta menus, ferramentas e barra de rolagem. O menu de contexto permite reexibir a barra de menus.

## Atalhos de teclado

| Atalho | Ação | Observação |
| --- | --- | --- |
| `Super+N` | Abre o Noir no XFCE Terminal. | Noir. |
| `Super+L` | Chama o bloqueador disponível pelo `xflock4`. | Noir. Também é um padrão nativo do XFCE. |
| `Shift+Alt+F11` | Abre o menu Whisker. | Noir. Também é a combinação emitida pelo Xcape. |
| `Super esquerda` | Abre o menu Whisker ao soltar a tecla sozinha. | Noir. O Xcape depende de X11 e respeita atalhos já atribuídos. |
| `Ctrl+Alt+T` | Abre o emulador de terminal preferido. | Padrão nativo do XFCE. |

[Atalhos do Noir](../../core/desktops/xfce/shortcuts.nix) · [Atalhos padrão do XFCE](https://github.com/xfce-mirror/libxfce4ui/blob/master/libxfce4kbd-private/xfce4-keyboard-shortcuts.xml)

## Autenticação e bloqueio

O LightDM usa a configuração de autenticação PAM do NixOS com fprintd. Na própria conta, `biometria` detecta um leitor e inicia o cadastro. Para escolher outro dedo, use `biometria -f left-index-finger`. Consulte [Impressões digitais](../applications.md#impressões-digitais).

O perfil define como padrão uma tentativa por digital com prazo de 10 s, antes da senha, no bloqueador `xfce4-screensaver` quando habilitado e na pilha `polkit-1`. O LightDM liga o NumLock antes de abrir o GTK Greeter. O indicador físico e a digitação dependem do dispositivo e do mapa de teclado. [Configuração de login](../../core/desktops/xfce/login.nix) · [NumLock](../../core/desktops/numlock.nix)

## Preferências pessoais

| Tipo | Exemplo no perfil |
| --- | --- |
| Editável pela conta | Organização dos itens de um painel existente e navegador preferido. |
| Padrão inicial | O modelo com Docklike é importado para contas sem estado de painel. |
| Valor bloqueado | Propriedades de NumLock e restauração no canal `keyboards`. |
| Configuração reaplicada | No login X11, o perfil atualiza as propriedades conhecidas de fundo e desabilita a troca automática nesses monitores e áreas. |

Consulte a [classificação das preferências](../configuration.md#preferências-da-sessão).

## Personalização do perfil

No fork, altere `size` em `panel-1` no [`panel-default.xml`](../../core/desktops/xfce/panel-default.xml) para mudar a altura do painel superior inicial. Num painel existente, ajuste os itens pela sessão. Consulte [Personalização](../customization.md#modificar-perfis-gráficos).

## Diagnóstico

| Sintoma | O que conferir |
| --- | --- |
| O Docklike não aparece. | Verifique se a conta já tinha painel ou Plank. O modelo inicial preserva o estado do painel existente. |
| O navegador novo não agrupa janelas no Docklike. | Atualize o lançador fixado para o navegador escolhido. |
| A tecla Super isolada não abre o Whisker. | Confira a sessão X11 e se há outro vínculo para a tecla ou para `Shift+Alt+F11`. |
| O atalho do Noir não abre. | Confira o [caminho do checkout e o lançador](../recovery.md#diagnóstico-por-sintomas). |

## Validação gráfica

1. **Conta nova.** Confira LightDM, X11, painéis, bandeja, atalhos e lançamento do Noir.
2. **Conta com preferências.** Confira a preservação do painel ou Plank, a reaplicação do papel de parede e o agrupamento após trocar de navegador.
3. **Autenticação e ambiente.** Confira bloqueio, retorno à sessão, NumLock, maximização, tela cheia e múltiplos monitores. Em equipamento compatível, teste a digital e a alternativa por senha. A homologação do Docklike depende desses testes gráficos.

Anterior: [Cinnamon](cinnamon.md) · [Índice dos perfis](../README.md#ambientes-gráficos)
