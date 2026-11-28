# Cinnamon

[Projeto](../../README.md) · [Índice](../README.md) · [Ambientes gráficos](../README.md#ambientes-gráficos)

## Visão geral

O perfil mantém os controles de sessão no painel superior e reúne tarefas em um painel inferior que pode se recolher. O menu de aplicativos e a lista de janelas continuam visíveis no painel superior.

## Sessão gráfica

O Noir configura Cinnamon em X11 com LightDM, o gerenciador de login, e Slick Greeter, a interface de entrada. O módulo retira a entrada Wayland do Cinnamon e rejeita KDE Plasma, SDDM ou GDM habilitados na configuração da máquina. O salvamento da sessão do Cinnamon fica desabilitado. [Módulo do perfil](../../core/desktops/cinnamon.nix)

## Aparência

A sessão usa Mint-Y-Dark-Aqua, ícones `Papirus-XApp-Dark`, derivados de Papirus-Dark, e cursor Bibata de tamanho 24. O Slick Greeter usa ícones Mint-Y-Aqua e fundo grafite. O [papel de parede escolhido no Noir](../configuration.md#preferências) é usado na sessão. A tela de login tem aparência própria.

## Painéis e navegação

| Componente | Comportamento |
| --- | --- |
| Painel superior | Permanente, com 38 px lógicos. Contém o menu com o floco do NixOS, a lista de janelas, o relógio central e os indicadores e controles de áreas. |
| Painel inferior | Com 42 px lógicos. Centraliza as tarefas agrupadas e se recolhe conforme a janela em foco. Os lançadores iniciais incluem Chrome, IntelliJ IDEA, Visual Studio Code, DBeaver e Nemo. |
| Áreas de trabalho | `Work 1` e `Work 2`, fixas e sem navegação circular. |

[Módulo de sessão](../../core/desktops/cinnamon/session.nix)

## Integrações

O portal XApp informa a preferência por modo escuro. Chrome e Nemo são as associações oferecidas para links e pastas. O Bitwarden tem uma entrada de início automático que pode ser substituída por outra de mesmo nome na conta. O touchpad recebe rolagem natural.

## Terminal

O lançador do Noir usa GNOME Terminal. O perfil configura a barra de menus para o aplicativo e a barra de rolagem para cada perfil do terminal. Novas janelas começam sem essas barras e o histórico continua acessível.

## Atalhos de teclado

| Atalho | Ação | Observação |
| --- | --- | --- |
| `Super+N` | Abre o Noir no GNOME Terminal. | Noir. A entrada **Noir** também está no menu. |
| `Super+L`, `Ctrl+Alt+L` ou `XF86ScreenSaver` | Abre o bloqueador nativo do Cinnamon. | Noir. A última entrada é o nome da tecla multimídia no código. |
| `Ctrl+Shift+T` | Abre uma aba no GNOME Terminal. | Padrão nativo do aplicativo. |
| `Shift+Page Up` ou `Shift+Page Down` | Percorre o histórico uma página por vez. | Atalhos nativos do GNOME Terminal. |

O Noir desabilita o atalho do Looking Glass e deixa vazia a combinação padrão para abrir o applet de notificações. [Atalhos do Noir](../../core/desktops/cinnamon/session.nix) · [Applet de notificações](../../core/desktops/cinnamon/notifications.json) · [GNOME Terminal](https://help.gnome.org/gnome-terminal/adv-keyboard-shortcuts.html)

## Autenticação e bloqueio

Use o Slick Greeter para entrar na conta. O atalho de bloqueio usa o bloqueador nativo. O Slick Greeter ativa o NumLock e o LightDM executa `numlockx on` antes da sessão. A lembrança do estado anterior fica desabilitada. O comportamento do indicador físico depende do dispositivo. O fprintd faz parte dos [serviços comuns](../applications.md#impressões-digitais).

## Preferências pessoais

| Tipo | Exemplo no perfil |
| --- | --- |
| Editável pela conta | Lançadores fixados e outros ajustes que os applets gravam em JSON. |
| Padrão inicial | Valores de menu, tarefas agrupadas e notificações, fornecidos pelos modelos dos applets. |
| Valor bloqueado | Altura e ocultação dos painéis, lista de applets e aparência administradas pelo dconf. |
| Configuração reaplicada | O gancho da sessão liga o NumLock e a rotina de início reinclui o atalho do Noir quando ele está ausente. |

Consulte a [classificação das preferências](../configuration.md#preferências-da-sessão).

## Personalização do perfil

No fork, altere `panels-height` em [`session.nix`](../../core/desktops/cinnamon/session.nix). O identificador `1` corresponde ao painel inferior. Ajustes dos JSON pessoais dos applets seguem outro caminho e ficam na conta. Consulte [Personalização](../customization.md#modificar-perfis-gráficos).

## Diagnóstico

| Sintoma | O que conferir |
| --- | --- |
| Menu ou tarefas exibem escolhas antigas. | Em conta de teste, compare o modelo com os JSON pessoais `menu@cinnamon.org/1000.json` e `grouped-window-list@cinnamon.org/1013.json`. |
| O NumLock não liga ao entrar. | Consulte `journalctl -b -t noir-cinnamon-numlock`. Uma falha no gancho permite que o login prossiga. |
| O atalho do Noir não abre. | Teste a entrada **Noir** no menu e confira o [lançador](../recovery.md#diagnóstico-por-sintomas). |

Os JSON pessoais podem estar em `${XDG_CONFIG_HOME:-$HOME/.config}/cinnamon/spices/` ou, em contas antigas, em `~/.cinnamon/configs/`. Preserve esses arquivos antes de ajustes. As chaves bloqueadas do dconf seguem o valor definido no perfil.

## Validação gráfica

1. **Conta nova.** Confira LightDM, Slick Greeter, X11, os dois painéis, a bandeja e os atalhos.
2. **Conta com preferências.** Confira os ajustes pessoais dos applets, uma única instância do Bitwarden no início e a ausência de restauração das janelas anteriores.
3. **Autenticação e ambiente.** Confira bloqueio, retorno à sessão, NumLock, escala e múltiplos monitores, incluindo relógio e ocultação do painel inferior.

Anterior: [GNOME](gnome.md) · [Índice dos perfis](../README.md#ambientes-gráficos)
