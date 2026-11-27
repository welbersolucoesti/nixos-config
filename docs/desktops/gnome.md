# GNOME

[Projeto](../../README.md) · [Índice](../README.md) · [Ambientes gráficos](../README.md#ambientes-gráficos)

## Visão geral

O perfil conserva a navegação do GNOME Shell e acrescenta um dock de acesso aos aplicativos, integração de bandeja e histórico da área de transferência.

## Sessão gráfica

O Noir configura GNOME em Wayland com GDM, o gerenciador de login, e sessão padrão `gnome`. As verificações do perfil rejeitam KDE Plasma, Cinnamon, XFCE, SDDM ou LightDM habilitados na configuração da máquina. [Módulo do perfil](../../core/desktops/gnome.nix)

## Aparência

O perfil pede modo escuro, usa realce azul e posiciona **Minimizar**, **Maximizar** e **Fechar** à direita nas janelas que respeitam o layout. O [papel de parede escolhido no Noir](../configuration.md#preferências) é usado na sessão e configurado para o bloqueio.

## Painéis e navegação

O GNOME Shell mantém a barra superior com relógio central e as animações nativas. A extensão Dash to Dock fornece um dock inferior centralizado, ajustado ao conteúdo e com ocultação inteligente. A Visão Geral de Atividades continua acessível pelo atalho nativo.

## Integrações

- **AppIndicator** integra indicadores de aplicativos à bandeja.
- **Clipboard Indicator** registra o histórico da área de transferência. A configuração restringe o cache e desabilita os atalhos globais da extensão. O item recém-copiado, favoritos e imagens ainda podem ser registrados.
- **Bitwarden** tem uma entrada de início automático que pode ser substituída por outra de mesmo nome na conta.
- **Chrome e Nautilus** são as associações oferecidas para links e pastas.

## Terminal

O lançador do Noir usa GNOME Terminal. A configuração gerenciada oculta as barras de menus e de rolagem do perfil inicial, mantendo o histórico acessível. O GNOME Console é um aplicativo distinto, acessível pelo atalho indicado abaixo.

## Atalhos de teclado

| Atalho | Ação | Observação |
| --- | --- | --- |
| `Super+N` | Abre o Noir no GNOME Terminal. | Noir. A entrada **Noir** também está no menu. |
| `Super+Esc` | Abre o GNOME System Monitor. | Noir. |
| `Ctrl+Alt+T` | Abre o GNOME Console. | Noir. |
| `Super+Shift+N` | Dá foco à notificação ativa. | Noir. |
| `Super+Alt+Esc` | Restaura atalhos inibidos no Wayland. | Noir. |
| `Super` | Abre a Visão Geral de Atividades. | Padrão nativo do GNOME Shell. |
| `Super+L` | Bloqueia a sessão. | Padrão nativo do GNOME Shell. |
| `Ctrl+Shift+T` | Abre uma aba no GNOME Terminal. | Padrão nativo do aplicativo. |

[Atalhos do Noir](../../core/desktops/gnome.nix) · [GNOME Shell](https://help.gnome.org/gnome-help/shell-keyboard-shortcuts.html) · [GNOME Terminal](https://help.gnome.org/gnome-terminal/adv-keyboard-shortcuts.html)

## Autenticação e bloqueio

Use o GDM para entrar na conta e o bloqueio nativo do GNOME durante a sessão. O GDM e a sessão recebem configurações para ligar o NumLock e lembrar seu estado. O indicador físico depende do dispositivo. O fprintd faz parte dos [serviços comuns](../applications.md#impressões-digitais). A disponibilidade de autenticação por impressão digital depende da instalação e do leitor.

## Preferências pessoais

| Tipo | Exemplo no perfil |
| --- | --- |
| Editável pela conta | Inclusão de outros atalhos personalizados. |
| Padrão inicial | Listas de extensões habilitadas e atalhos personalizados oferecidas pelo perfil. |
| Valor bloqueado | Chaves do dconf para aparência, atalhos gerenciados, parâmetros de extensões e visibilidade de barras no terminal. |
| Configuração reaplicada | No login, a rotina tenta habilitar as extensões gerenciadas e reinserir atalhos ausentes, preservando os outros atalhos pessoais. |

Consulte a [classificação das preferências](../configuration.md#preferências-da-sessão).

## Personalização do perfil

No fork, altere `intellihide` em [`gnome.nix`](../../core/desktops/gnome.nix) para mudar a ocultação do Dash to Dock. Se alterar a lista de extensões, confira também a rotina de início da sessão e os parâmetros que correspondem à extensão. Consulte [Personalização](../customization.md#modificar-perfis-gráficos).

## Diagnóstico

| Sintoma | O que conferir |
| --- | --- |
| O dock ou a bandeja está ausente. | Confira se a extensão consta como habilitada na sessão com `gnome-extensions list --enabled`. |
| A mudança de aparência aparece bloqueada. | Consulte as chaves administradas pelo [módulo do perfil](../../core/desktops/gnome.nix). |
| O atalho do Noir não abre. | Teste a entrada **Noir** no menu e confira o [lançador](../recovery.md#diagnóstico-por-sintomas). |

## Validação gráfica

1. **Conta nova.** Confira GDM, Wayland, dock, extensões, atalhos e o GNOME Terminal.
2. **Conta com preferências.** Confira a preservação de atalhos adicionais e a reaplicação dos itens gerenciados no login.
3. **Autenticação e ambiente.** Confira bloqueio, retorno à sessão, NumLock, áudio e área de transferência. O modo escuro do Chrome no primeiro login ainda depende de homologação.

Anterior: [KDE Plasma](kde.md) · [Índice dos perfis](../README.md#ambientes-gráficos) · Próximo: [Cinnamon](cinnamon.md)
