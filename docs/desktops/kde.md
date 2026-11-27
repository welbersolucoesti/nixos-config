# KDE Plasma

[Projeto](../../README.md) · [Índice](../README.md) · [Ambientes gráficos](../README.md#ambientes-gráficos)

## Visão geral

O perfil combina a aparência Breeze com dois painéis flutuantes. O superior reúne navegação e indicadores da sessão. O inferior agrupa aplicativos fixados e janelas.

## Sessão gráfica

O Noir habilita Plasma 6 e SDDM, o gerenciador de login. Selecione a sessão Wayland na tela de login quando estiver disponível. As verificações do perfil rejeitam XFCE ou LightDM habilitados na configuração da máquina. Por padrão do Noir, cada login inicia uma sessão vazia, com os aplicativos de início automático ainda disponíveis. [Módulo do perfil](../../core/desktops/kde.nix)

## Aparência

O tema **Breeze Dark (Noir)** usa Breeze Dark e fornece o modelo de layout do Noir. O KWin habilita Glide e Lâmpada Mágica. O [papel de parede escolhido no Noir](../configuration.md#preferências) é usado na área de trabalho e na tela de bloqueio. [Módulo de sessão](../../core/desktops/kde/session.nix)

## Painéis e navegação

| Componente | Comportamento |
| --- | --- |
| Painel superior | Flutuante, com 38 px lógicos, Kickoff com o floco do NixOS, lista de janelas, relógio, bandeja e seletor de áreas de trabalho. |
| Painel inferior | Flutuante, com 42 px lógicos. Ajusta-se ao conteúdo e se recolhe quando sobreposto. Os lançadores iniciais incluem o navegador preferido, IntelliJ IDEA, Visual Studio Code, DBeaver e Dolphin. |
| Áreas de trabalho | `Work 1` e `Work 2`, em uma linha e sem navegação circular. |

O perfil também oferece Configurações do Sistema e Postman nos favoritos iniciais do Kickoff. [Modelo de layout](../../core/desktops/kde/layout.js) · [Módulo de sessão](../../core/desktops/kde/session.nix)

## Integrações

O Bitwarden tem uma entrada de início automático que pode ser substituída por uma entrada pessoal de mesmo nome. A bandeja depende dos componentes, serviços e hardware disponíveis. O perfil define rolagem natural para touchpads e configura o NumLock ligado pelo KConfig.

## Terminal

O Konsole usa o perfil de sistema **Noir** se a conta ainda não tiver escolhido outro. Menus, ferramentas e barra de rolagem começam ocultos. A barra de abas aparece quando há mais de uma aba.

## Atalhos de teclado

O nome **Super** representa a tecla de sistema, geralmente identificada pelo logotipo do Windows. Para esta combinação, o Plasma e o código do perfil usam o nome **Meta**.

| Atalho | Ação | Observação |
| --- | --- | --- |
| `Super+N` | Abre o Noir no Konsole. | Noir. Registrado como `Meta+N` no Plasma. |
| `Ctrl+Shift+M` | Alterna a barra de menus. | Padrão nativo do Konsole. |
| `Ctrl+Shift+T` | Abre uma aba no Konsole. | Padrão nativo do Konsole. |

[Atalho do Noir](../../core/desktops/kde.nix) · [Manual do Konsole](https://docs.kde.org/stable_kf6/en/konsole/konsole/commandreference.html)

## Autenticação e bloqueio

Use o SDDM para entrar na conta e a ação de bloqueio do Plasma durante a sessão. O perfil configura o fundo do bloqueador. O fprintd faz parte dos [serviços comuns](../applications.md#impressões-digitais). O comportamento da autenticação depende da instalação e do equipamento.

## Preferências pessoais

| Tipo | Exemplo no perfil |
| --- | --- |
| Editável pela conta | Widgets e lançadores dos painéis existentes. |
| Padrão inicial | O modelo cria os dois painéis quando ainda não há painéis. |
| Valor bloqueado | O KConfig fixa o início de sessão vazia e a imagem do bloqueador. |
| Configuração reaplicada | Um serviço de usuário reaplica o papel de parede quando o `plasmashell` inicia. |

Consulte a [classificação das preferências](../configuration.md#preferências-da-sessão).

## Personalização do perfil

No fork, altere `top.height` em [`layout.js`](../../core/desktops/kde/layout.js) para ajustar a altura do painel superior inicial. Para validar o modelo, use uma conta sem painéis. Para um painel existente, use a edição da própria sessão. Consulte [Personalização](../customization.md#modificar-perfis-gráficos).

## Diagnóstico

| Sintoma | O que conferir |
| --- | --- |
| Os painéis já existentes não receberam o modelo. | A criação inicial depende da ausência de painéis. |
| O papel de parede volta após um novo login. | Confira o valor publicado e, na própria conta, consulte `journalctl --user -b -u noir-plasma-wallpaper.service`. |
| O atalho do Noir não abre. | Confira o [caminho do checkout e o lançador](../recovery.md#diagnóstico-por-sintomas). |

## Validação gráfica

1. **Conta nova.** Confira SDDM, sessão Wayland quando disponível, dois painéis, áreas de trabalho, efeitos e o atalho do Noir.
2. **Conta com preferências.** Confira a persistência de widgets, a reaplicação do papel de parede, a sessão vazia e uma única instância do Bitwarden no início.
3. **Autenticação e ambiente.** Confira bloqueio, retorno à sessão e bandeja com os serviços e o hardware de teste.

[Índice dos perfis](../README.md#ambientes-gráficos) · Próximo: [GNOME](gnome.md)
