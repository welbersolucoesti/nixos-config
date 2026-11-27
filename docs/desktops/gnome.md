# GNOME

[Projeto](../../README.md) · [Índice](../README.md)

O perfil configura GNOME em Wayland com GDM e sessão padrão `gnome`. O [módulo](../../core/desktops/gnome.nix) rejeita KDE Plasma, Cinnamon, XFCE, SDDM e LightDM habilitados na configuração da máquina.

## Sessão e aparência

O GNOME Shell mantém o relógio central e as animações nativas. O perfil configura preferência por modo escuro, realce azul e botões **Minimizar**, **Maximizar** e **Fechar** à direita nas janelas que respeitam o layout. O [papel de parede compartilhado](../configuration.md#preferências) é aplicado ao fundo da sessão e configurado para o bloqueio. O GDM e a sessão recebem a configuração de NumLock ligado e de lembrança do estado. O comportamento do LED depende do dispositivo.

- **Dash to Dock** oferece dock inferior, centralizado e ajustado ao conteúdo, com ocultação inteligente.
- **Clipboard Indicator** fornece histórico de área de transferência. A configuração restringe o cache e desabilita os atalhos globais da extensão. Trate a área de transferência como dado sensível, pois a extensão ainda pode registrar o item recém-copiado, favoritos e imagens.
- **AppIndicator** fornece integração de bandeja. O Bitwarden tem uma entrada XDG de início automático que uma entrada pessoal de mesmo nome pode substituir.

O Noir bloqueia por dconf as chaves gerenciadas para aparência, teclas e configurações das extensões. As listas de extensões e atalhos personalizados têm tratamento separado. No login, o Noir acrescenta os itens gerenciados que estiverem ausentes e preserva os demais itens da conta. Chrome e Nautilus são as associações oferecidas para links e pastas.

## Terminal e atalhos

| Atalho | Ação |
| --- | --- |
| `Super+N` | Abre o Noir no GNOME Terminal. A entrada **Noir** também aparece no menu. |
| `Super+Esc` | Abre o GNOME System Monitor. |
| `Ctrl+Alt+T` | Abre o GNOME Console. |
| `Super+Shift+N` | Foca a notificação ativa. |
| `Super+Alt+Esc` | Restaura os atalhos inibidos no Wayland. |

O perfil inicial do GNOME Terminal oculta a barra de menus e a barra de rolagem, mantendo o histórico. `Ctrl+Shift+T` continua disponível para os aplicativos que usam a combinação em suas próprias ações de abas.

## Validação gráfica

Em uma VM ou instalação de teste, confira GDM, Wayland, dock, extensões e bandeja. Teste área de transferência, áudio, NumLock, bloqueio, atalhos e novos perfis do terminal. Em uma conta já personalizada, confira a preservação dos itens adicionais nas listas de extensões e atalhos. O modo escuro do Chrome no primeiro login ainda depende de homologação gráfica.

[KDE Plasma](kde.md) · [Cinnamon](cinnamon.md)
