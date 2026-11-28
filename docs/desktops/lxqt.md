# LXQt

[Projeto](../../README.md) · [Índice](../README.md) · [Ambientes gráficos](../README.md#ambientes-gráficos)

## Visão geral

O perfil combina LXQt com KWin Wayland. O LXQt Panel reúne navegação e indicadores na parte superior. O Crystal Dock 2.16 é o candidato para reunir aplicativos fixados e janelas abertas na parte inferior.

## Sessão gráfica

O Noir inicia **LXQt (Wayland)** pelo SDDM. O KWin gerencia janelas, atalhos, áreas de trabalho e bloqueio. O XWayland permite executar aplicativos X11 dentro da sessão. O perfil registra uma única sessão. O PCManFM-Qt desenha a área de trabalho. O módulo completo do Plasma fica desabilitado. A sessão inicia os aplicativos de autostart e começa sem restaurar janelas. [Módulo do perfil](../../core/desktops/lxqt.nix)

## Aparência

O tema LXQt **Noir** usa o tema System com Breeze como referência. O QSS define superfícies escuras, seleção azul e contornos de foco visíveis no painel e no Fancy Menu. Os widgets usam Breeze, o GTK usa Breeze-Dark e a decoração do KWin segue a paleta Breeze Dark. O KWin habilita Glide e Lâmpada Mágica. O Chrome com decoração própria segue a disposição padrão dos botões do GTK, também disponibilizada pelo portal de configurações. O PCManFM-Qt usa o [papel de parede selecionado](../configuration.md#preferências). O KScreenLocker recebe a mesma imagem quando o tema fornece o plugin de imagem. [Tema Noir](../../core/desktops/lxqt/noir-panel.qss) · [Preferências da sessão](../../core/desktops/lxqt/session.nix) · [Efeitos do KWin](../../core/desktops/kwin-settings.nix)

O gerenciador de energia LXQt usa o ícone do tema como padrão. A bandeja aplica aos três estados do Blueman os desenhos do Breeze Dark, tanto para os nomes normais quanto para os simbólicos. Os demais ícones seguem a herança do tema, inclusive os recursos enviados pelos próprios aplicativos. [Configuração da aparência](../../core/desktops/lxqt/appearance.nix)

## Painéis e navegação

| Componente | Padrão do Noir |
| --- | --- |
| Painel superior | 38 px lógicos, largura integral e reserva de espaço. O fundo arredondado tem uma margem visual em QSS. A superfície Wayland continua encostada à borda. O painel contém Fancy Menu com o floco do NixOS, relógio, bandeja, volume, mídias removíveis, seletor de áreas de trabalho e botão para mostrar a área de trabalho. |
| Dock inferior | Crystal Dock 2.16 com estilo plano flutuante, fundo de referência de 42 px lógicos, alinhamento central, largura pelo conteúdo e ocultação inteligente. O gerenciador agrupa janelas e associa lançadores aos aplicativos reconhecidos. |
| Lançadores do dock | Chrome, IntelliJ IDEA, Visual Studio Code, DBeaver e Dolphin, nessa ordem. O PCManFM-Qt continua responsável pela área de trabalho e como gerenciador padrão. |
| Favoritos do menu | Chrome, Configurações do LXQt, PCManFM-Qt, IntelliJ IDEA, DBeaver, Visual Studio Code e Postman. |
| Áreas de trabalho | `Work 1` e `Work 2` em uma linha, com navegação sem ciclo. |

O relógio fica no centro geométrico quando há espaço entre os grupos laterais. Em telas estreitas, volta ao fluxo dos componentes para evitar sobreposição. A sessão inicia o Crystal Dock após importar o ambiente Wayland, e o alvo de sessão encerra o serviço no logout. O LXQt Panel reserva a borda inferior para o dock durante o modo candidato, inclusive ao carregar painéis pessoais ou conectar um monitor. [Ajuste do relógio](../../core/desktops/lxqt/panel-layout.patch) · [Reserva da borda inferior](../../core/desktops/lxqt/panel-reserve-bottom.patch) · [Módulo do dock](../../core/desktops/lxqt/crystal-dock.nix)

O Crystal Dock usa o protocolo KDE de gerenciamento de janelas. A correspondência depende dos identificadores que o KWin fornece para janelas Wayland e XWayland. A ocultação cobre janelas maximizadas, tela cheia e sobreposição quando o compositor fornece a geometria. O 2.16 pode clonar o primeiro dock no primeiro início com várias saídas. Depois, a conta pode associar docks a telas pelos controles do próprio aplicativo. [Documentação do Crystal Dock](https://github.com/dangvd/crystal-dock/wiki/Documentation)

## Integrações

A configuração da máquina continua responsável pelos dispositivos, pela rede e pela compatibilidade do vídeo com Wayland. Se a máquina usa NetworkManager, o Noir disponibiliza o applet de rede na bandeja. O perfil usa PipeWire e WirePlumber para áudio, Blueman para Bluetooth, UPower e o gerenciador de energia do LXQt. PCManFM-Qt, GVfs e UDisks2 cuidam dos arquivos e das mídias removíveis.

O KWin liga o NumLock e ativa rolagem natural para touchpads compatíveis. O Chrome é o navegador inicial. A opção de iniciar com a sessão, no próprio Bitwarden, controla a entrada pessoal de autostart. Quando a entrada usa um executável versionado do pacote Nix, o Noir atualiza o caminho no próximo login LXQt. [Migração de preferências](../../core/desktops/lxqt/migrate-preferences.sh)

O Noir libera os portais depois que o KWin fornece o ambiente gráfico. O roteamento dá prioridade ao LXQt para seleção de arquivos e solicitações de acesso. O KDE atende à captura, ao compartilhamento de tela e ao desktop remoto, e o GTK atende às configurações e às demais interfaces que fornece. [Configuração dos portais](../../core/desktops/lxqt.nix)

O mapa XKB do KWin parte de `services.xserver.xkb` da máquina. O KScreenLocker usa o teclado da sessão Wayland. O SDDM tem um compositor separado, configurado pelo NixOS para consultar o mapa de `locale1`. Antes de iniciar o PCManFM-Qt, a sessão chama `xdg-user-dirs-update` quando a conta ainda não tem `user-dirs.dirs`. O utilitário usa o idioma e os padrões XDG e mantém os diretórios já configurados pela conta. [Inicialização da sessão](../../core/desktops/lxqt.nix)

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
| `Print Screen` | Abre o Spectacle para capturar a tela pelo KWin Wayland. |

O **Noir** e o **Spectacle** também aparecem no menu. O Spectacle registra seu atalho padrão pelo KGlobalAccel. [Atalhos do Noir](../../core/desktops/lxqt/session.nix) · [Atalhos do Spectacle](https://docs.kde.org/stable_kf6/en/spectacle/spectacle/starting.html)

## Autenticação e bloqueio

Abra **Usuários e impressões digitais** no menu de aplicativos ou no centro de configurações. A entrada carrega o módulo oficial KDE `kcm_users` em `kcmshell6`. O módulo usa AccountsService e fprintd via D-Bus. O Polkit pode pedir autenticação para gerenciar digitais. O botão de configuração aparece quando o KCM detecta um leitor. [Módulo de biometria](../../core/desktops/lxqt/biometrics.nix) · [KCM de usuários do KDE](https://github.com/KDE/plasma-workspace/tree/v6.6.6/kcms/users/src)

O SDDM pede senha. No bloqueio, o KScreenLocker executa a verificação da digital em uma conversa PAM separada da senha. A disponibilidade do cadastro e do desbloqueio biométrico depende do leitor e do suporte do fprintd. Autorização administrativa via Polkit segue a política da ação e a pilha PAM própria.

Na suspensão, o KScreenLocker recebe o aviso do logind, solicita o bloqueio imediato e libera a espera quando a sessão fica bloqueada. O padrão do Noir desativa a espera paralela da LXQt. Como a espera do logind tem limite, confira o ciclo de suspensão e retorno no equipamento, inclusive com tampa e monitor externo, conforme os [testes de validação gráfica](#validação-gráfica). [KScreenLocker 6.6.6](https://github.com/KDE/kscreenlocker/blob/v6.6.6/ksldapp.cpp) · [Gerenciador de sessão LXQt 2.4.0](https://github.com/lxqt/lxqt-session/blob/2.4.0/lxqt-session/src/lockscreenmanager.cpp)

## Preferências pessoais

Uma conta nova usa os padrões do Noir. Os INIs de LXQt, PCManFM-Qt e QTerminal aceitam preferências da conta. As chaves KConfig administradas do KWin e do bloqueador preservam os padrões de áreas de trabalho, entrada e bloqueio.

O painel resolve os lançadores exportados pelo sistema pelo caminho da geração ativa. Favoritos da conta são atualizados na mesma ordem. O papel de parede padrão do PCManFM-Qt também tem um caminho estável. Ao iniciar a sessão, a migração substitui referências anteriores ao wallpaper gerenciado pelo Noir e preserva caminhos personalizados. [Resolução de lançadores](../../core/desktops/lxqt/panel-favorites.patch) · [Migração de preferências](../../core/desktops/lxqt/migrate-preferences.sh)

## Personalização do perfil

No fork, altere `panelSize` na seção `[top]` de [`panel.conf`](../../core/desktops/lxqt/panel.conf) para ajustar a altura inicial do painel. Temas, ícones e dimensões que a conta selecionou continuam tendo precedência. O Crystal Dock copia o preset no primeiro uso e guarda a configuração deste ambiente no subdiretório `LXQt`. Configurações pessoais em `$XDG_CONFIG_HOME/crystal-dock` ou no local legado `~/.crystal-dock-2` têm precedência. Consulte [Personalização](../customization.md#modificar-perfis-gráficos).

### Restaurar o painel inferior LXQt

Defina `noir.lxqt.crystalDock.enable = false;` na configuração NixOS da máquina. Após o proprietário aplicar a configuração e entrar novamente, o Noir volta a disponibilizar as seções originais do painel inferior, incluindo as preferências que a conta já tinha. As preferências do Crystal Dock ficam disponíveis para um teste posterior. No painel inferior LXQt, o Quick Launch e a barra de tarefas funcionam como plugins separados. [Opção de reversão](../../core/desktops/lxqt/crystal-dock.nix)

## Diagnóstico

| Sintoma | O que conferir |
| --- | --- |
| Sessão ausente ou falha no login | Verifique `systemctl status display-manager.service`, o valor publicado do desktop e eventuais módulos ou sessões gráficos concorrentes. |
| Painel ou atalhos diferentes | Compare com uma conta nova. Revise `~/.config/lxqt/panel.conf` e `~/.config/kglobalshortcutsrc` na conta de teste. |
| Dock ausente ou ícone de janela separado do lançador | Consulte `journalctl --user -b -u noir-lxqt-crystal-dock.service`. Confira o ID da entrada `.desktop`, a classe ou app ID da janela e a tela do dock. |
| Teclado diferente no login, na sessão ou no bloqueio | Compare `localectl status`, a configuração de `services.xserver.xkb`, o `kxkbrc` pessoal e a lista do KWin com `busctl --user call org.kde.KWin /Layouts org.kde.KeyboardLayouts getLayoutsList`. |
| A página de digitais não abre ou o botão não aparece | Confirme que o KCM é descoberto, que AccountsService e fprintd estão acessíveis e que o leitor é compatível. Veja `journalctl -b -u fprintd.service` e o log da sessão. |
| Aplicativo não oferece compartilhamento | Confira `journalctl --user -b -u xdg-desktop-portal.service -u plasma-xdg-desktop-portal-kde.service` e verifique PipeWire. Teste novamente depois de encerrar e entrar na sessão. |

## Validação gráfica

1. **Entrada e sessão.** Em ambiente descartável, confira a única entrada LXQt no SDDM, login por senha, sessão Wayland e abertura de um aplicativo X11 via XWayland. Confira as teclas específicas do mapa da máquina no login, na sessão e no bloqueio. Encerre a sessão e entre novamente. Verifique que as janelas anteriores não retornam, que o Bitwarden abre uma vez com a opção de autostart ativa e que `plasmashell` está ausente. Repita com a opção desativada. Em uma conta nova, confira os diretórios XDG no primeiro e no segundo login.
2. **Biometria.** Com leitor compatível, abra o KCM pelo menu e pelo centro de configurações. Cadastre, liste, recadastre e exclua uma digital. Cancele um cadastro e tente de novo. Repita o fluxo com leitor ocupado, desconectado ou indisponível. Verifique as mensagens do agente Polkit e a autorização alternativa por senha.
3. **Bloqueio.** Teste Super+L, bloqueio por inatividade e suspensão pelo menu e pela tampa, quando disponíveis. Em múltiplos monitores, confira todas as saídas antes e depois de reconectar uma delas. Desbloqueie separadamente por digital e senha. Repita com digital incorreta, ausência de cadastro e leitor desconectado. Verifique que a senha continua disponível e que nenhuma janela fica acessível enquanto a sessão estiver bloqueada.
4. **Portais.** Abra um seletor de arquivos. Teste captura e compartilhamento de tela e de janela em aplicativos Wayland e XWayland. Encerre a sessão e repita para verificar nova ativação do backend.
5. **Identidade.** Confira Super isolada, busca, favoritos, foco por teclado, relógio central e reserva de espaço. Verifique os três estados do Bluetooth, bateria carregando e descarregando, rede e mudo. Confira os ícones do VS Code e do IntelliJ antes e depois de abrir janelas Wayland e XWayland. Teste agrupamento, largura, ocultação, recuperação pela borda, escala fracionária, segundo monitor, segundo login e reversão para o painel anterior. Confirme uma instância do dock e o encerramento junto à sessão. Teste o Spectacle, o wallpaper, a decoração das janelas, fonte, abas e histórico do terminal.
6. **Integrações e desempenho.** Teste áudio, Bluetooth, rede, perfis de energia, suspensão e mídias removíveis. Com dados fictícios, confira o limite e a limpeza do histórico ao sair da sessão. Compare a memória e a resposta com KDE Plasma Noir usando as mesmas condições, aplicativos abertos e serviços.

Anterior: [Cinnamon](cinnamon.md) · [Índice dos perfis](../README.md#ambientes-gráficos)
