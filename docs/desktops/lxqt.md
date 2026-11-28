# LXQt

[Projeto](../../README.md) · [Índice](../README.md) · [Ambientes gráficos](../README.md#ambientes-gráficos)

## Visão geral

O perfil combina LXQt com KWin Wayland. O painel superior reúne navegação e indicadores, e o inferior acompanha aplicativos fixados e janelas abertas.

## Sessão gráfica

O Noir inicia **LXQt (Wayland)** pelo SDDM. O KWin gerencia janelas, atalhos, áreas de trabalho e bloqueio. O XWayland permite executar aplicativos X11 dentro da sessão. O perfil registra uma única sessão e usa o LXQt Panel e o PCManFM-Qt para o painel e a área de trabalho. O módulo completo do Plasma fica desabilitado. A sessão inicia os aplicativos de autostart e começa sem restaurar janelas. [Módulo do perfil](../../core/desktops/lxqt.nix)

## Aparência

O perfil aplica uma paleta escura a Qt e GTK. O KWin habilita Glide e Lâmpada Mágica. O PCManFM-Qt usa o [papel de parede selecionado](../configuration.md#preferências). O KScreenLocker recebe a mesma imagem quando o tema fornece o plugin de imagem. [Preferências da sessão LXQt](../../core/desktops/lxqt/session.nix) · [Efeitos do KWin](../../core/desktops/kwin-settings.nix)

## Painéis e navegação

| Componente | Padrão do Noir |
| --- | --- |
| Painel superior | 38 px lógicos, largura integral e reserva de espaço. Menu com o floco do NixOS, lista de janelas, relógio centralizado, bandeja, volume, mídias removíveis, seletor de áreas de trabalho e atalhos de sessão no menu. |
| Painel inferior | 42 px lógicos, centralizado e com largura ajustada aos componentes. Recolhe quando uma janela se sobrepõe à área do painel. |
| Lançadores inferiores | Chrome, IntelliJ IDEA, Visual Studio Code, DBeaver e PCManFM-Qt. O Quick Launch fixa os atalhos e a lista de tarefas agrupa as janelas abertas. Um aplicativo pode aparecer nos dois componentes. |
| Favoritos do menu | Chrome, Configurações do LXQt, PCManFM-Qt, IntelliJ IDEA, DBeaver, Visual Studio Code e Postman. |
| Áreas de trabalho | `Work 1` e `Work 2` em uma linha, com navegação sem ciclo. |

O Noir inclui um ajuste no LXQt Panel para atualizar o comprimento do painel inferior com o tamanho do conteúdo e centralizar o relógio quando há espaço entre as laterais. Em telas estreitas, o relógio volta ao fluxo normal dos componentes para evitar sobreposição. [Configuração e ajuste do painel](../../core/desktops/lxqt/)

## Integrações

A configuração da máquina continua responsável pelos dispositivos, pela rede e pela compatibilidade do vídeo com Wayland. Se a máquina usa NetworkManager, o Noir disponibiliza o applet de rede na bandeja. O perfil usa PipeWire e WirePlumber para áudio, Blueman para Bluetooth, UPower e o gerenciador de energia do LXQt. PCManFM-Qt, GVfs e UDisks2 cuidam dos arquivos e das mídias removíveis.

O KWin liga o NumLock e ativa rolagem natural para touchpads compatíveis. O Chrome é o navegador inicial. O Bitwarden inicia pelo autostart XDG, sujeito à precedência de uma entrada pessoal de mesmo nome. O portal LXQt atende à seleção de arquivos, o KDE atende à captura e ao compartilhamento de tela, e o GTK complementa a seleção de interfaces. [Configuração da sessão](../../core/desktops/lxqt/session.nix) · [Configuração dos portais](../../core/desktops/lxqt.nix)

O CopyQ oferece histórico com limite inicial de 20 itens. O serviço guarda as abas, anexos, histórico de ações e logs próprios no diretório de execução, removido quando o serviço encerra. As preferências e definições de comandos da conta continuam nos arquivos pessoais e podem alterar o limite ou exportar dados. Históricos gravados antes dessa configuração ficam onde foram salvos. O CopyQ reconhece o marcador MIME de senha do KDE quando o aplicativo de origem o fornece. Senhas copiadas do Bitwarden sem esse marcador podem entrar no histórico. [Ajuste de armazenamento](../../core/desktops/lxqt/copyq-runtime-history.patch) · [CopyQ 13.0.0](https://github.com/hluk/CopyQ/tree/v13.0.0)

## Terminal

O QTerminal começa com JetBrains Mono Nerd Font, esquema escuro, menu e rolagem ocultos, barra de abas visível quando há mais de uma aba e histórico de 10.000 linhas no terminal. O shell e o tema Zsh seguem as [preferências comuns](../configuration.md#preferências). [Configuração do terminal](../../core/desktops/lxqt/session.nix)

## Atalhos de teclado

| Atalho | Ação |
| --- | --- |
| `Super+N` | Abre o configurador Noir no QTerminal. |
| `Super+Esc` | Abre o Qps. |
| `Super+L` | Bloqueia a sessão pelo KScreenLocker. |
| `Ctrl+Alt+T` | Abre o QTerminal. |
| `Super` isolada | Abre ou alterna o menu de aplicativos ao soltar a tecla. |

O **Noir** também aparece no menu. [Atalhos do Noir](../../core/desktops/lxqt/session.nix)

## Autenticação e bloqueio

Abra **Usuários e impressões digitais** no menu de aplicativos ou no centro de configurações. A entrada carrega o módulo oficial KDE `kcm_users` em `kcmshell6`. O módulo usa AccountsService e fprintd via D-Bus. O Polkit pode pedir autenticação para gerenciar digitais. O botão de configuração aparece quando o KCM detecta um leitor. [Módulo de biometria](../../core/desktops/lxqt/biometrics.nix) · [KCM de usuários do KDE](https://github.com/KDE/plasma-workspace/tree/v6.6.6/kcms/users/src)

O SDDM pede senha. No bloqueio, o KScreenLocker executa a verificação da digital em uma conversa PAM separada da senha. A disponibilidade do cadastro e do desbloqueio biométrico depende do leitor e do suporte do fprintd. Autorização administrativa via Polkit segue a política da ação e a pilha PAM própria.

Na suspensão, o KScreenLocker recebe o aviso do logind, solicita o bloqueio imediato e libera a espera quando a sessão fica bloqueada. O padrão do Noir desativa a espera paralela da LXQt. Como a espera do logind tem limite, confira o ciclo de suspensão e retorno no equipamento, inclusive com tampa e monitor externo, conforme os [testes de validação gráfica](#validação-gráfica). [KScreenLocker 6.6.6](https://github.com/KDE/kscreenlocker/blob/v6.6.6/ksldapp.cpp) · [Gerenciador de sessão LXQt 2.4.0](https://github.com/lxqt/lxqt-session/blob/2.4.0/lxqt-session/src/lockscreenmanager.cpp)

## Preferências pessoais

Uma conta nova usa os padrões do Noir. Os INIs de LXQt, PCManFM-Qt e QTerminal aceitam preferências da conta. As chaves KConfig administradas do KWin e do bloqueador preservam os padrões de áreas de trabalho, entrada e bloqueio.

## Personalização do perfil

No fork, altere `panelSize` em [`panel.conf`](../../core/desktops/lxqt/panel.conf) para ajustar a altura inicial dos painéis. Uma conta que já ajustou o painel usa suas preferências pessoais. Consulte [Personalização](../customization.md#modificar-perfis-gráficos).

## Diagnóstico

| Sintoma | O que conferir |
| --- | --- |
| Sessão ausente ou falha no login | Verifique `systemctl status display-manager.service`, o valor publicado do desktop e eventuais módulos ou sessões gráficos concorrentes. |
| Layout ou atalhos diferentes | Compare com uma conta nova. Revise `~/.config/lxqt/panel.conf` e `~/.config/kglobalshortcutsrc` na conta de teste. |
| A página de digitais não abre ou o botão não aparece | Confirme que o KCM é descoberto, que AccountsService e fprintd estão acessíveis e que o leitor é compatível. Veja `journalctl -b -u fprintd.service` e o log da sessão. |
| Aplicativo não oferece compartilhamento | Confira `journalctl --user -b -u xdg-desktop-portal.service -u plasma-xdg-desktop-portal-kde.service` e verifique PipeWire. Teste novamente depois de encerrar e entrar na sessão. |

## Validação gráfica

1. **Entrada e sessão.** Em ambiente descartável, confira a única entrada LXQt no SDDM, login por senha, sessão Wayland e abertura de um aplicativo X11 via XWayland. Encerre a sessão e entre novamente. Verifique que as janelas anteriores não retornam, que o Bitwarden abre uma vez e que `plasmashell` está ausente.
2. **Biometria.** Com leitor compatível, abra o KCM pelo menu e pelo centro de configurações. Cadastre, liste, recadastre e exclua uma digital. Cancele um cadastro e tente de novo. Repita o fluxo com leitor ocupado, desconectado ou indisponível. Verifique as mensagens do agente Polkit e a autorização alternativa por senha.
3. **Bloqueio.** Teste Super+L, bloqueio por inatividade e suspensão pelo menu e pela tampa, quando disponíveis. Em múltiplos monitores, confira todas as saídas antes e depois de reconectar uma delas. Desbloqueie separadamente por digital e senha. Repita com digital incorreta, ausência de cadastro e leitor desconectado. Verifique que a senha continua disponível e que nenhuma janela fica acessível enquanto a sessão estiver bloqueada.
4. **Portais.** Abra um seletor de arquivos. Teste captura e compartilhamento de tela e de janela em aplicativos Wayland e XWayland. Encerre a sessão e repita para verificar nova ativação do backend.
5. **Identidade.** Confira os cinco atalhos, incluindo Super isolada e combinada, relógio, bandeja, áreas de trabalho e ordens iniciais. Abra várias janelas do mesmo aplicativo, confira o agrupamento e o ajuste da largura do painel ao abrir e fechar janelas, cubra sua área com uma janela e recupere-o pela borda. Confirme escala e geometria em múltiplos monitores. Confira fonte, abas e histórico do terminal.
6. **Integrações e desempenho.** Teste áudio, Bluetooth, rede, perfis de energia, suspensão e mídias removíveis. Com dados fictícios, confira o limite e a limpeza do histórico ao sair da sessão. Compare a memória e a resposta com KDE Plasma Noir usando as mesmas condições, aplicativos abertos e serviços.

Anterior: [Cinnamon](cinnamon.md) · [Índice dos perfis](../README.md#ambientes-gráficos)
