# Configuração declarativa dos notebooks NixOS

Este repositório reúne os aplicativos, serviços e perfis gráficos **KDE Plasma** e **XFCE** dos notebooks do David. Usa módulos tradicionais do NixOS, sem Flakes ou Home Manager.

Para usar o projeto, você precisa de um **NixOS já instalado**, uma conta Linux normal declarada na configuração da máquina e acesso a `sudo` para publicar os arquivos. Clone o projeto, publique a cópia de implantação e depois ajuste os imports da máquina. Para instalar o NixOS do zero, siga o [manual do NixOS](https://nixos.org/manual/nixos/stable/#ch-installation).

## Preparar o sistema pelo terminal

Você pode usar um terminal gráfico ou o console de texto (TTY). Se a rede já estiver funcionando, vá direto para a etapa do Git.

Para conectar ao Wi-Fi quando o NetworkManager gerencia a conexão, troque `NOME_DA_REDE` pelo nome da rede que aparece na lista. A opção `--ask` pede a senha sem registrá-la no histórico do terminal. [Referência do nmcli](https://networkmanager.dev/docs/api/latest/nmcli.html)

```bash
nmcli device status
nmcli device wifi list
nmcli --ask device wifi connect "NOME_DA_REDE"
ping -c 3 nixos.org
```

Se o NetworkManager estiver indisponível, use uma conexão por cabo ou consulte o manual oficial. Preserve os ajustes de rede da máquina e guarde credenciais fora do Git e dos arquivos Nix, que podem ser copiados para o Nix Store. [Manual de redes do NixOS](https://nixos.org/manual/nixos/stable/#sec-networking)

Se o Git ainda estiver indisponível, abra uma sessão temporária com o comando abaixo. [Referência do nix-shell](https://nix.dev/manual/nix/latest/command-ref/nix-shell.html)

```bash
nix-shell -p git
```

Com o Git disponível, baixe o repositório e entre na pasta:

```bash
git clone https://github.com/welbersolucoesti/nixos-config.git
cd nixos-config
```

O instalador precisa encontrar o Nixpkgs, que fornece os pacotes e módulos do sistema. O primeiro comando mostra o caminho que o Nix encontra na sua sessão. Se falhar, confira o canal configurado ou o `NIX_PATH` antes de continuar. O segundo mostra a versão.

```bash
nix-instantiate --find-file nixpkgs
nix-instantiate --eval --strict -E '(import <nixpkgs> {}).lib.version'
```

O projeto usa a revisão do Nixpkgs disponível na máquina para os perfis e pacotes padrão. As versões desses pacotes podem variar entre instalações. O Codex CLI opcional tem uma revisão própria, fixada no repositório. Se um pacote ou opção estiver disponível na avaliação, mas faltar na hora de aplicar, confira qual revisão cada ambiente está usando. Se a máquina usa canais, compare as listas de `nix-channel --list` e `sudo nix-channel --list`.

## Instalar ou atualizar

O GitHub é a fonte de verdade. A pasta obtida com `git clone` é o **checkout de desenvolvimento**, onde você usa Git e mantém suas alterações. `/etc/nixos/nixos-config/` é a **cópia implantada**, que o NixOS importa e o instalador atualiza com os arquivos versionados. `config/local.nix` e `config/optionals.json` ficam fora do Git em ambas as cópias. Após a primeira instalação, a identidade, o desktop e o tema continuam no `local.nix` implantado. Use o Noir para os opcionais.

Execute o configurador pela conta Linux que receberá a identidade Git. A autenticação administrativa acontece após a confirmação da publicação no destino padrão.

```bash
bash config.sh
```

O configurador Noir usa Dialog no console TTY e nos terminais do KDE e do XFCE, a partir de 40 colunas por 12 linhas. A tela inicial mostra a branch ou o commit local quando disponível. Use as setas nos menus e para percorrer os campos de identidade Git. Tab muda o foco entre o formulário e os botões, Enter aciona a opção em foco e Esc cancela a etapa. Nas confirmações, a opção inicial é **Não**. Durante um comando em andamento, use Ctrl+C para interromper. As telas de revisão mostram os detalhes do fast-forward e da publicação. Use **Registros** no resultado para consultar os diagnósticos da execução. [Manual do Dialog](https://invisible-island.net/dialog/manpage/dialog.html)

Em um terminal interativo, `./config.sh` usa o Dialog do `PATH` ou carrega o executável automaticamente com `nix-shell -p dialog`. Se o carregamento falhar, execute `./config.sh --plain` para usar o modo texto. Fora de um terminal interativo, o configurador também usa o modo texto. `bash install.sh` continua disponível com Gum e aceita `--plain` e `--destination`.

Depois de selecionar **Instalar ou atualizar**, o assistente pede confirmação para consultar o remoto, aplicar o fast-forward quando houver atualizações e publicar a cópia. Na publicação protegida, o Dialog abre um campo oculto e entrega a senha ao `sudo` somente se ele pedir autenticação para aquele comando. A implantação chega por um descritor separado, lido com as permissões da conta que a preparou. Se sua configuração de PAM usar uma pergunta de autenticação personalizada, use `--plain`. Prepare as credenciais do remoto antes de iniciar a sincronização no Dialog.

1. Na primeira instalação, preencha **Conta Linux** e **Identidade Git**. Confira os dados no resumo antes de publicar. Nas atualizações, o instalador reutiliza a identidade da cópia implantada.
2. O instalador executa `git fetch` para o remoto configurado na branch e apresenta os commits e arquivos alterados. Se você autorizar, `git merge --ff-only` avança o checkout até o commit apresentado usando o objeto já buscado. Recusar encerra a instalação e devolve o controle ao menu principal. Alterações não commitadas, commits apenas locais e branches divergentes exigem que você resolva o estado do checkout.
3. Na primeira instalação, se o checkout ainda estiver sem `config/local.nix`, escolha KDE ou XFCE para preencher o modelo versionado. Se já houver um arquivo, a identidade precisa coincidir exatamente com a informada. O instalador confere os tipos das opções locais e os campos obrigatórios. O `dry-build` manual avalia a configuração completa da máquina, incluindo as asserções do NixOS.
4. Confirme o destino. O instalador publica os arquivos regulares versionados, o módulo local e as escolhas salvas pelo Noir, quando houver. Ao substituir uma implantação, guarda a cópia anterior em `/etc/nixos/nixos-config.previous`. A troca atômica de diretórios usa `mv --exchange --no-copy` do GNU Coreutils e exige suporte do sistema de arquivos. Guarde ajustes avulsos fora da pasta de implantação para preservá-los por mais de uma atualização.
5. Na primeira instalação, o instalador configura o Git global pela conta selecionada depois da publicação.
6. Após uma publicação bem-sucedida no destino padrão, o Noir oferece **Validar agora (dry-build)**, **Voltar ao menu principal** e **Sair**. A validação abre na mesma sessão. Se a publicação for cancelada ou falhar, o Noir retorna ao menu principal após mostrar o resultado.

Para ensaiar, acrescente `--destination /CAMINHO/DESTINO`. Use um diretório separado do checkout, fora de `/etc/nixos`, com um diretório pai gravável. A primeira instalação do ensaio também configura o Git global. Para preservar suas preferências durante o ensaio, use uma conta Linux de teste.

### Verificar e aplicar

Depois de publicar, abra `/etc/nixos/configuration.nix` com `sudoedit` e adicione `./nixos-config/personal.nix` à lista de imports. Remova imports anteriores do projeto, incluindo imports diretos de `local.nix` e de módulos avulsos. Se o módulo da máquina usava um redirecionamento de imports para a implantação antiga, remova também a declaração que fazia esse redirecionamento. Preserve os imports de hardware e os demais ajustes da máquina, incluindo a conta Linux, a inicialização, a rede e `system.stateVersion`.

```nix
imports = [
  ./hardware-configuration.nix
  ./nixos-config/personal.nix
];
```

- Para usar **XFCE**, remova as declarações da máquina que ativam KDE Plasma (`services.desktopManager.plasma6.enable`) ou SDDM (`services.displayManager.sddm.enable`).
- Para usar **KDE**, remova as que ativam XFCE (`services.xserver.desktopManager.xfce.enable`) ou LightDM (`services.xserver.displayManager.lightdm.enable`).

O menu principal oferece **Instalar ou atualizar** e, para o destino padrão, **Gerenciar sistema**. O Dialog também oferece **Gerenciar opcionais**, inclusive antes da primeira instalação. Em **Gerenciar sistema**, escolha **Validar configuração (dry-build)** ou **Aplicar configuração (switch)**. No Dialog, Esc volta ao menu principal e, a partir dele, encerra o Noir. No Gum, use **Cancelar**. No modo texto, digite `q`.

**Validar configuração (dry-build)** avalia `/etc/nixos/configuration.nix` e a cópia publicada em `/etc/nixos/nixos-config`. Execute pela sua conta normal. Alterações ainda no checkout precisam ser publicadas antes de aparecer nessa validação. O equivalente no terminal é `nixos-rebuild dry-build`. Depois do resultado, é possível voltar a **Gerenciar sistema** ou sair. Se a validação passou, também é possível iniciar o fluxo de aplicação.

A publicação protegida inicial deixa `config/local.nix` sob controle do root e concede leitura ao UID que publicou, por ACL. Atualizações preservam as permissões do arquivo implantado. Se uma implantação antiga deixou esse arquivo em modo `0600`, sem ACL, o administrador pode conceder somente a leitura à conta que vai validar. Execute pela própria conta autorizada a ler a configuração:

```bash
sudo setfacl -m "u:$(id -u):r--" -- /etc/nixos/nixos-config/config/local.nix
```

**Aplicar configuração (switch)** exige um terminal interativo e inicia um dry-build automaticamente. Se a validação falhar, o Noir exibe o erro e encerra a operação. Se passar, o Noir pergunta **Aplicar configuração agora?**. **Sim** prossegue para a ativação, enquanto **Não** ou **Esc** cancela. A aplicação valida novamente após uma validação avulsa porque a configuração pode ter mudado entre as operações. O Dialog abre um campo oculto se o `sudo` pedir a senha da conta. Em Gum ou `--plain`, a autenticação ocorre no terminal. Use `--plain` se o PAM apresentar perguntas personalizadas, exigir mais de uma resposta ou usar outros tipos de autenticação que dependam do terminal. O switch pode reiniciar serviços e afetar a sessão gráfica. Após o resultado, é possível voltar ao menu principal ou sair. Somente o proprietário da máquina pode aprovar a ativação ou realizar o equivalente manual depois de validar a configuração.

```bash
sudo nixos-rebuild switch
```

Os rebuilds do Noir compartilham uma trava com a publicação protegida. Use **Registros** no Dialog ou abra o caminho indicado no resumo para consultar a saída. Os registros de rebuild ficam em `$XDG_STATE_HOME/noir/rebuilds` ou, por padrão, em `~/.local/state/noir/rebuilds`. Em caso de falha no switch, confira o registro e consulte [Diagnóstico e recuperação](#diagnóstico-e-recuperação) antes de tentar novamente.

Confira a sessão gráfica e os serviços depois da ativação. Repita a instalação e a validação para atualizar a cópia implantada.

## Configuração local

`personal.nix` já importa `config/local.nix`. Para mudar as escolhas da estação, use `sudoedit /etc/nixos/nixos-config/config/local.nix`. Veja a estrutura em [config/local.example.nix](config/local.example.nix).

`personalConfig.desktop` aceita `"kde"`, `"xfce"` ou `null` para delegar o desktop à configuração da máquina. `personalConfig.username` deve identificar uma conta normal já declarada na máquina. Os campos de autoria registram as escolhas locais. Se o instalador indicar que o arquivo está incompleto ou incompatível, corrija-o no caminho indicado antes de repetir a instalação. Se uma implantação mais antiga guardava as escolhas em `/etc/nixos/nixos-config/local.nix`, guarde o original e transfira as opções para `/etc/nixos/nixos-config/config/local.nix` conforme o modelo.

O tema padrão do Oh My Zsh é `"bira"`. Em `zsh.theme`, você pode indicar outro tema disponível. Com `null`, os plugins, o autocompletar, as sugestões e o destaque de sintaxe continuam disponíveis. Depois de editar, siga [Verificar e aplicar](#verificar-e-aplicar). Se trocar de ambiente gráfico, revise também a sessão padrão, o login automático e as declarações gráficas da máquina.

### Gerenciar opcionais

Abra **Gerenciar opcionais** no Dialog, antes ou depois da primeira instalação. Você pode salvar as escolhas antes de informar a identidade da máquina. Use Espaço para marcar ou desmarcar **CRON**, **Virtualization** e **Codex CLI**. Escolha **Revisar**, confira as mudanças e confirme o salvamento. O Noir valida o candidato em Nix e faz a troca atômica de `config/optionals.json` no checkout. Cancelar ou falhar na validação conserva as escolhas anteriores.

Reabra o menu para ver as escolhas salvas. **Instalar ou atualizar** publica a seleção do checkout quando disponível e reaproveita o arquivo implantado quando o checkout ainda não tem escolhas. Após publicar, o **dry-build** avalia a configuração completa da máquina.

Em um clone novo, os três opcionais começam desmarcados. Instalações antigas mantêm os valores comuns de `personalConfig.cron.enable` e `personalConfig.virtualization.enable` de `local.nix` até a primeira alteração salva pelo menu. A partir daí, o Noir registra as três opções juntas, inclusive quando todas ficam desmarcadas.

## Perfis gráficos

| Perfil | Sessão | Gerenciador de login |
| --- | --- | --- |
| KDE | Plasma 6 com layout inicial Noir. Selecione Plasma Wayland no login. | SDDM |
| XFCE | XFCE em X11 | LightDM |

O Plasma abre uma sessão vazia a cada login. A configuração do sistema fixa apenas `General/loginMode` no `ksmserverrc`, inclusive para contas que já restauravam sessões. Aplicativos configurados para iniciar automaticamente continuam abrindo.

A rolagem natural é o padrão para touchpads compatíveis. Em Wayland, o KWin lê o padrão por tipo de dispositivo no `kcminputrc`. No XFCE em X11, o Xorg aplica a opção do libinput aos dispositivos classificados como touchpad. Preferências de rolagem já gravadas para um dispositivo têm precedência nos dois perfis. Mouses externos conservam sua configuração de rolagem.

No XFCE, o LightDM executa `numlockx on` antes de abrir a tela de login X11. Na sessão, o `xfsettingsd` lê os valores `Numlock` e `RestoreNumlock` do canal `keyboards`, que o perfil fixa como verdadeiros. A tecla NumLock continua disponível durante a sessão. O estado físico do LED e o efeito sobre teclados sem bloco numérico dedicado dependem do hardware e do mapa XKB. No Plasma, a opção nativa também funciona em Wayland e uma configuração de NumLock já gravada pela conta tem precedência.

Kickoff e Whisker usam o nome de ícone `nix-snowflake` para o floco oficial do NixOS. No Plasma, o layout inicial define o ícone do Kickoff. Novas instâncias do Whisker recebem o ícone por padrão. No XFCE, o ícone escolhido nas instâncias existentes é preservado. [Arte oficial do NixOS](https://github.com/NixOS/nixos-artwork)

### KDE Plasma Noir

Ao criar o layout de uma conta, o Plasma usa o script do tema global `Breeze Dark (Noir)`. A variante reutiliza os padrões de aparência do Breeze Dark oficial e define ColdRipple como fundo. Contas com layout salvo conservam seus painéis, widgets e a escolha de papel de parede. Uma conta com layout parcial salvo também mantém seu estado. Os padrões em `/etc/xdg` valem para preferências ainda sem escolha local. A política de sessão vazia descrita acima continua obrigatória.

- O painel superior é flutuante, sempre visível, tem 38 px lógicos, ocupa a largura disponível e usa opacidade adaptativa. Na ordem, contém Kickoff, separador de margens, lista de janelas, espaçador, relógio sem data, espaçador, bandeja do sistema, seletor de áreas de trabalho e Mostrar área de trabalho.
- O painel inferior é flutuante e translúcido, tem 42 px lógicos, ajusta-se ao conteúdo e se recolhe quando uma janela o sobrepõe. Os fixados no gerenciador de tarefas são navegador preferido, IntelliJ IDEA, Visual Studio Code, DBeaver e Dolphin.
- O Kickoff usa o KActivities para inicializar os favoritos, na ordem, com navegador preferido, Configurações do Sistema, Dolphin, IntelliJ IDEA, DBeaver, Visual Studio Code e Postman. O Chrome é o navegador padrão do perfil e pode ser trocado em Configurações do Sistema.
- O tema global usa os padrões do Breeze Dark, incluindo o esquema de cores e os ícones escuros. O estilo Qt é Breeze, o estilo do Plasma é `default` e o cursor Breeze tem tamanho 24. O perfil fornece preferência escura para GTK.
- O KWin tem duas áreas em uma linha, `Work 1` e `Work 2`, sem navegação circular. Glide e Lâmpada Mágica começam habilitados. Scale e Squash começam desabilitados.
- O Bitwarden tem uma entrada de início automático para KDE. Uma entrada pessoal com o mesmo nome prevalece. Para desabilitar o padrão, a especificação XDG prevê um arquivo `~/.config/autostart/bitwarden.desktop` com `Hidden=true` em `[Desktop Entry]`.

A bandeja usa a seleção nativa de plugins da revisão instalada do Plasma. Rede, áudio, Bluetooth, impressão e controles de energia dependem dos serviços habilitados e do hardware disponível. O perfil preserva os atalhos nativos do KWin e o atalho `Meta+N` do Noir.

#### Papel de parede

Com `personalConfig.kde.wallpaperSource = null`, o padrão é **ColdRipple** no desktop inicial e na tela de bloqueio. O pacote `plasma-workspace-wallpapers` fornece o recurso à instalação e o Plasma seleciona a variante adequada à resolução. O endereço usado pela sessão permanece estável entre gerações do NixOS.

Para usar uma imagem própria, disponibilize um PNG legível pela conta configurada antes da publicação. Por exemplo, use `/var/lib/noir/wallpapers/kde.png` e adicione esta opção a `config/local.nix`.

```nix
personalConfig.kde.wallpaperSource = "/var/lib/noir/wallpapers/kde.png";
```

O módulo expõe o recurso em `/etc/noir/kde-wallpaper.png`. Um caminho inexistente ou que aponte para um diretório é rejeitado na avaliação do sistema. Na aplicação feita pelo proprietário, o sistema verifica o conteúdo com as permissões da conta configurada. Se o PNG estiver inválido ou ilegível, informa o problema e usa ColdRipple. O PNG personalizado fica no local indicado e precisa ser restaurado nas instalações que o utilizarem.

A interface do desktop e a do bloqueio permitem escolher outras imagens. Uma escolha que aponte para o endereço do sistema acompanha o recurso definido no perfil. Uma imagem escolhida em outro endereço permanece como preferência da conta.

#### Validação em uma conta nova

Para testar alterações locais antes de versioná-las, aponte a configuração da instalação de teste para o `personal.nix` do checkout completo. O Noir publica os arquivos versionados.

Em uma instalação de validação autorizada com o perfil KDE, entre no Plasma Wayland em uma conta descartável com `wallpaperSource = null`. Confira o ColdRipple no desktop e no bloqueio, os dois painéis, os favoritos, o navegador, a bandeja e o `Meta+N`. Confira as duas áreas de trabalho e minimize uma janela para verificar a Lâmpada Mágica. Em seguida, escolha outro papel de parede pela interface, mova um widget, remova um favorito e reabra a sessão. Confira se as mudanças permanecem, se o Bitwarden inicia uma vez e se as janelas anteriores ficam fechadas. Para testar o PNG personalizado, configure outro recurso e repita a primeira entrada em uma segunda conta descartável.

### XFCE Noir

O XFCE usa `Orchis-Dark` no GTK e no Xfwm4, `Papirus-Dark` para ícones e Breeze 24 para o cursor. Bibata e Tela continuam disponíveis para quem os escolheu. O dconf oferece a preferência por modo escuro a aplicativos que a respeitam, como os baseados em libadwaita. A sessão oferece o tema de plataforma GTK aos aplicativos Qt 5 e Qt 6 quando a conta ainda não definiu outro. Aplicativos com tema próprio podem usar suas preferências.

O fundo padrão do desktop e do bloqueador nativo é `xfce-cp-dark.svg`, do pacote xfdesktop. Imagens escolhidas em **Configurações → Área de trabalho** conservam suas opções por monitor e área de trabalho. Os ícones da área de trabalho ficam ocultos por padrão. O LightDM usa o GTK Greeter em grafite, com relógio de 24 horas, seleção de sessão, acessibilidade e ações de energia conforme disponíveis. [Arte do xfdesktop 4.20.2](https://raw.githubusercontent.com/xfce-mirror/xfdesktop/xfdesktop-4.20.2/backgrounds/README.md)

#### Painéis iniciais

- **Superior, linha de 38 px.** Ocupa a largura disponível e fica sempre visível. O relógio de 24 horas, sem data, fica entre o Whisker e o menu de janelas, com separadores fixos. Um espaçador mantém a bandeja, o seletor de áreas de trabalho, Mostrar área de trabalho e as ações de sessão à direita. Volume e bateria aparecem quando seus componentes estão habilitados.
- **Inferior, 42 px.** Painel Docklike experimental, centrado e ajustado ao conteúdo, com fundo grafite translúcido. Recolhe quando a janela em foco o sobrepõe. A ordem inicial é navegador preferido, IntelliJ IDEA, Visual Studio Code, DBeaver e Thunar. O Docklike associa janelas a IDs de aplicativos. Se você trocar de navegador depois de criado o painel, desafixe o antigo e fixe o novo para agrupar suas janelas no lançador correspondente.
- **Whisker e áreas.** A ordem inicial dos favoritos é navegador preferido, Configurações do XFCE, Thunar, IntelliJ IDEA, DBeaver, Visual Studio Code e Postman. As duas áreas iniciais se chamam `Work 1` e `Work 2`, numa linha, com navegação sem retorno circular.

O Xfwm4 usa as reservas nativas dos painéis para calcular a área útil. O Noir retirou a política de margens fixas. Margens que a conta salvou continuam editáveis. O Picom mantém a composição X11 com XRender e VSync. Os painéis usam a geometria do XFCE e as janelas seguem os efeitos nativos do ambiente. [Preferências de painel](https://docs.xfce.org/xfce/xfce4-panel/preferences) · [Docklike Taskbar](https://docs.xfce.org/panel-plugins/xfce4-docklike-plugin/start)

#### Contas existentes e preferências

O modelo inicial é importado em contas sem estado de painel ou Plank. O Noir deixa painéis gravados, parcialmente configurados ou vazios a cargo do XFCE. Foram retiradas as migrações recorrentes do Noir e a regravação do ícone do Whisker. Contas que já usam Plank mantêm o autostart e seus lançadores. O autostart do Plank do Noir é ignorado nas contas que receberam o modelo Docklike.

O Google Chrome é o padrão dos links, arquivos HTML e do auxiliar WebBrowser do XFCE. Ajuste esses vínculos em **Aplicativos preferidos**. O Bitwarden tem uma entrada de autostart. Para desativá-la, use **Sessão e inicialização → Início automático de aplicativos** ou crie `~/.config/autostart/bitwarden.desktop` com `Hidden=true` em `[Desktop Entry]`. O XFCE conserva seu gerenciamento nativo de sessões salvas. [Aplicativos preferidos](https://docs.xfce.org/xfce/xfce4-settings/preferred-apps) · [Autostart XDG](https://specifications.freedesktop.org/autostart/latest/)

A tecla Super esquerda abre o Whisker quando usada sozinha. O atalho usa `Shift+Alt+F11` internamente. `Super+L` chama `xflock4`, que usa o bloqueador da sessão, normalmente `xfce4-screensaver`. Combinações já atribuídas têm precedência. [Atalhos do XFCE](https://github.com/xfce-mirror/libxfce4ui/blob/master/libxfce4kbd-private/xfce4-keyboard-shortcuts.xml)

| Componente | Uso |
| --- | --- |
| Blueman | Pareie, conecte e desconecte dispositivos Bluetooth pelo menu ou pela bandeja. |
| Áudio | Ajuste volume, microfone e saída. No painel inicial, **Mixer de áudio** abre o Pavucontrol na aba **Dispositivos de saída**, se disponível. |
| Bateria | Passe o cursor sobre o ícone para consultar a carga. O percentual ao lado do ícone fica oculto por padrão e pode ser habilitado nas propriedades. |
| Mugshot | Edite o perfil pessoal conforme as permissões da conta e do AccountsService. |
| Clipman | Adicione-o ao painel para guardar histórico da área de transferência. |
| Thunar com Xarchiver | Compacte e extraia arquivos pelo menu de contexto. |

A bandeja prefere ícones simbólicos e segue os 22 px de ícone do painel inicial. No XFCE 4.20.7, uma bandeja horizontal exibe o grupo XEmbed antes do grupo StatusNotifier. A ordem de rede e Bluetooth depende de como os applets se registram. [Bandeja do XFCE](https://docs.xfce.org/xfce/xfce4-panel/systray) · [Código da bandeja 4.20.7](https://raw.githubusercontent.com/xfce-mirror/xfce4-panel/xfce4-panel-4.20.7/plugins/systray/sn-plugin.c)

#### Validação do XFCE Noir

Em uma instalação de teste, use uma conta nova e uma conta que já tenha painel e Plank. Confira o wallpaper no desktop e no bloqueio em mais de um monitor. Maximize e abra uma janela em tela cheia para verificar a área útil, o recolhimento e a transparência. Troque o navegador, confirme o comportamento do Docklike e teste o autostart do Bitwarden com e sem opt-out. Em seguida, personalize painel, favoritos, atalhos e wallpaper e confira a persistência após entrar novamente. A homologação do Docklike depende desses testes gráficos.

### Terminais

Os padrões de ambos os terminais ficam em `modules/applications/terminal.nix`. Menus, ferramentas e barra de rolagem começam ocultos. As abas aparecem quando há mais de uma, e o terminal mantém o título da janela, a seleção de texto, a rolagem e os atalhos. As preferências pessoais têm precedência.

O comando `noir` abre o configurador executável em `~/nixos-config/config.sh` pela conta da sessão, inclusive com outro shell ou desktop. Com o perfil KDE ou XFCE selecionado, `Super+N` abre uma janela de Konsole ou XFCE Terminal, respectivamente. Se o Noir falhar, a janela espera Enter antes de fechar. No KDE, o KGlobalAccel carrega o atalho padrão do aplicativo **Noir**. No XFCE X11, o perfil registra a combinação livre em Xfconf. Atalhos personalizados já atribuídos têm precedência. Em um TTY ou com outro desktop escolhido pela máquina, execute `noir` no terminal ou configure o atalho no gerenciador da sessão. [Implementação do KGlobalAccel](https://github.com/KDE/kglobalacceld/blob/v6.6.6/src/globalshortcutsregistry.cpp)

- **KDE** usa Konsole com o perfil de sistema **Noir** quando a conta não tem outro perfil padrão. `Ctrl+Shift+M` alterna a barra de menus. [Manual do Konsole](https://docs.kde.org/stable_kf6/en/konsole/konsole/)
- **XFCE** usa XFCE Terminal com DejaVu Sans Mono 11, opacidade inicial de 90% e o atalho padrão `Ctrl+Alt+T`. O menu de contexto permite reexibir a barra de menus. Na sessão XFCE X11, o Xfwm4 gerencia as janelas e o Picom faz a composição com XRender e VSync.

## Aplicativos e serviços

```text
nixos-config/
├── config.sh          Entrada do configurador com Dialog
├── install.sh         Fluxo compartilhado e entrada compatível com Gum
├── lib/
│   ├── noir.dialogrc  Tema do configurador
│   ├── ui-dialog.sh   Widgets do Dialog
│   └── ui.sh          Interface comum, Gum e modo texto
├── personal.nix
├── config/
│   ├── local.example.nix
│   ├── noir-optionals.nix  Importa o arquivo de escolhas do Noir
│   └── options.nix
└── modules/
    ├── applications/  Navegadores, senhas, desenvolvimento, escritório, JDK, Zsh e terminal
    ├── desktops/      Perfis KDE e XFCE, com complementos do Noir em xfce/
    ├── optional/      Cron, virtualização, Codex CLI e tema do Zsh
    ├── services/      Bluetooth, fprintd, keyd, Polkit e PostgreSQL
    └── system/        Pacotes gerais, manutenção do Nix e ZRAM
```

`personal.nix` declara os imports explicitamente. `modules/optional/virtualization.nix` reúne os imports do conjunto opcional, incluindo seus aplicativos e os módulos de serviço libvirt e Podman. O instalador inclui os arquivos versionados, inclusive o modelo XML do painel. Ao adicionar um módulo, declare seu import na configuração.

| Recurso | Configuração |
| --- | --- |
| Navegadores | Google Chrome instalado. O módulo de Firefox do NixOS fica desabilitado. O projeto permite pacotes proprietários em todo o sistema, com prioridade sobre configurações comuns de outros módulos. |
| Desenvolvimento | IntelliJ IDEA, VS Code, DBeaver, Postman e Eclipse Temurin JDK 25. |
| Uso geral | Bitwarden, ONLYOFFICE Desktop Editors, Inkscape, GIMP, Fastfetch, Vim, wget, usbutils, Git, htop e pv. |
| Vim | NERDTree (`:NERDTreeToggle`), espaços com quatro colunas, wildmenu, numeração, pesquisa incremental, margem de cinco linhas, divisões à direita e abaixo e undo persistente em `$XDG_STATE_HOME/vim/undo` (padrão `~/.local/state/vim/undo`). |
| Fontes | JetBrainsMono Nerd Font e Microsoft Core Fonts para todas as contas. |
| Biometria | O fprintd é compartilhado entre os perfis e depende de um leitor compatível e de digitais cadastradas. |
| Bluetooth | O adaptador começa ligado, e o pareamento fica a cargo do usuário. |
| Terminal | A conta escolhida passa a usar Zsh, com Oh My Zsh e os plugins de Git e sudo. |
| Teclado | O keyd transforma `leftshift+leftmeta+f23` em reproduzir ou pausar. Em alguns notebooks, essa combinação é emitida pela tecla Copilot. A regra vale para todos os teclados gerenciados. Teste no seu teclado, pois o evento pode variar. |

As Microsoft Core Fonts são extraídas localmente dos instaladores originais com hash já declarados no Nixpkgs. O visualizador do Word e a fonte Tahoma ficam fora. A derivação inclui a EULA ao lado das fontes. Consulte a licença antes de usar as fontes e mantenha a saída extraída fora de caches públicos e imagens distribuídas. [EULA Microsoft Core Fonts](https://corefonts.sourceforge.net/eula.htm)

### Idioma e aparência do ONLYOFFICE

O Noir define **Português Brasileiro** (`pt-BR`) e **Escuro moderno** como padrões do ONLYOFFICE Desktop Editors no KDE e no XFCE. Para mudar o idioma ou o tema, abra **Configurações** na página inicial. O aplicativo salva suas escolhas em `$XDG_CONFIG_HOME/onlyoffice/DesktopEditors.conf` (por padrão, `~/.config/onlyoffice/DesktopEditors.conf`) e dá preferência a elas sobre os padrões do sistema. [Configurações do ONLYOFFICE](https://helpcenter.onlyoffice.com/pt-BR/desktop/getting-started)

### Impressões digitais

Na sessão gráfica da conta que vai usar o leitor, cadastre uma digital, consulte os cadastros e verifique a leitura.

```bash
fprintd-enroll -f right-index-finger
fprintd-list "$USER"
fprintd-verify
```

Para apagar todas as digitais cadastradas para essa conta no fprintd, use `fprintd-delete "$USER"`.

No perfil XFCE, `biometria` verifica se o fprintd detecta um leitor e inicia o cadastro na própria conta. Use `biometria -f left-index-finger` para selecionar outro dedo. Siga as instruções do fprintd e autentique-se se a sessão solicitar. Cadastre um dedo ainda livre para preservar o modelo já cadastrado para o mesmo dedo. [API do fprintd](https://fprint.freedesktop.org/fprintd-dev/Manager.html)

No XFCE, o LightDM GTK Greeter autentica a conta pela pilha PAM `lightdm`, que delega a autenticação à pilha `login` do NixOS. Selecione a conta e use o leitor assim que a leitura for solicitada. Se a autenticação terminar e o greeter continuar na tela, clique em **Entrar** ou pressione **Enter**. Se a digital falhar ou o tempo expirar, aguarde o campo de senha. [Código do LightDM GTK Greeter](https://github.com/Xubuntu/lightdm-gtk-greeter/blob/lightdm-gtk-greeter-2.0.9/src/lightdm-gtk-greeter.c)

O bloqueador padrão `xfce4-screensaver` e as ações do Polkit que pedem autenticação pelo agente da sessão também têm uma regra PAM para o leitor. Com o perfil XFCE selecionado, essas duas pilhas dão uma tentativa à digital, com prazo de 10 segundos para a leitura, e pedem a senha se a verificação falhar. A pilha `polkit-1` é usada pelo sistema para essas autenticações. A digital precisa pertencer à conta indicada no diálogo. [Manual de pam_fprintd](https://manpages.debian.org/unstable/libpam-fprintd/pam_fprintd.8.en.html)

A avaliação Nix confere as regras PAM. O teste com o leitor físico deve confirmar a digital e a alternativa por senha no login, no desbloqueio e em uma ação do Polkit que exija autenticação.

### Java

O pacote `temurin-bin-25` disponibiliza `java` e `javac` no terminal. Use `java -version` e `javac -version` para conferir qual versão o terminal encontra.

A instalação global deixa a escolha de `JAVA_HOME` e do JDK da IDE a cargo do usuário. Se uma ferramenta exigir `JAVA_HOME`, aponte a variável para o diretório do JDK escolhido. Na IDE, selecione o SDK de acordo com a versão de Java exigida pelo projeto.

### PostgreSQL

O PostgreSQL 18 atende conexões TCP da própria máquina em `localhost:5432`. As regras para IPv4 e IPv6 locais exigem SCRAM-SHA-256. O servidor também usa SCRAM-SHA-256 ao gravar senhas novas ou alteradas.

Com `-h localhost`, o `psql` usa TCP. Ao omitir o endereço, ele pode usar um **socket Unix**, que segue as regras `local` do arquivo efetivo de autenticação. Para conferir se esse acesso exige senha, execute `SHOW hba_file;` em uma sessão autorizada e leia as entradas `local` do arquivo indicado.

Crie os usuários e bancos de aplicação, guarde as senhas fora dos arquivos Nix e mantenha seus backups. A configuração é voltada ao desenvolvimento local. Revise a autenticação e o firewall antes de abrir o serviço à rede ou usá-lo em produção.

Use `pg_isready` para conferir se o serviço responde. Para testar o acesso, troque `USUARIO` e `BANCO` por um usuário e um banco já criados. O `psql` pede a senha ao conectar.

```bash
pg_isready -h localhost -p 5432
psql -h localhost -p 5432 -U USUARIO -d BANCO -W
```

### ZRAM

O ZRAM oferece uma área de swap comprimida em RAM com zstd. Os 50% definem o tamanho lógico do dispositivo, sem reservar metade da memória de uma vez. O conteúdo desaparece quando a máquina desliga. Para hibernar, configure separadamente uma área de swap em disco e a retomada do sistema a partir dela.

Depois de aplicar a configuração, `zramctl` mostra o dispositivo comprimido e `swapon --show` lista as áreas de swap ativas.

```bash
zramctl
swapon --show
```

### Manutenção do Nix

A coleta semanal pode remover gerações elegíveis com mais de 60 dias e liberar espaço ao apagar objetos do Nix Store que ficaram sem referências. Perfis e outras raízes do Nix mantêm vivos os objetos que ainda referenciam. Use `nix-generations` para ver quais gerações continuam disponíveis para voltar a uma configuração já construída. `nix-store --gc --print-dead` lista objetos elegíveis à coleta sem apagá-los.

A cópia de segurança recupera os arquivos Nix usados na próxima construção. As gerações do NixOS permitem iniciar um sistema já construído enquanto a geração estiver disponível. Veja [Diagnóstico e recuperação](#diagnóstico-e-recuperação).

Em `modules/system/maintenance.nix`, `nix-update` atualiza os canais de root. `nix-check` planeja a construção, `nix-system-build` constrói sem ativar e `nix-switch` aplica a configuração. `nix-diff` compara dois caminhos existentes, na ordem origem e destino. Por exemplo, para comparar a geração 10, se ainda existir, com o sistema em execução:

```bash
nix-diff /nix/var/nix/profiles/system-10-link /run/current-system
```

### Agendamento privado

Marque **CRON** no Noir para habilitar o agendamento `nixos-cron`, que roda diariamente às 03h no horário da máquina. Entre na conta selecionada na instalação e crie o script privado no diretório pessoal dessa conta:

```bash
cron_dir="$HOME/.local/share/nixos-cron"
script="$cron_dir/cron.sh"
mkdir -p -- "$cron_dir" &&
  chmod 700 -- "$cron_dir" &&
  (umask 077; touch -- "$script") &&
  chmod 600 -- "$script" &&
  vim -- "$script"
```

`touch` cria o arquivo quando está ausente e preserva o conteúdo de um script existente. O Bash lê o arquivo em cada execução, sem exigir permissão de execução nem copiar o script para o Nix Store. O serviço tem seu próprio `PATH`, com utilitários como `find`, `grep`, `sed` e `awk`. Se o script precisar de outros programas, declare-os no `path` do serviço.

Depois de habilitar o agendamento e aplicar a configuração, confira o próximo horário e os registros:

```bash
systemctl list-timers --all nixos-cron.timer
systemctl status nixos-cron.service
journalctl -u nixos-cron.service
```

O serviço termina ao concluir o script, então pode aparecer como inativo entre execuções. Se o arquivo estiver ausente, o serviço pula a execução. Se o notebook estiver desligado às 03h, o agendamento aguarda o próximo horário. Para rodar o script na hora, o proprietário pode usar `sudo systemctl start nixos-cron.service`. Mesmo nessa execução o script roda pela conta selecionada. Consulte o log para detectar falhas, pois o timer não envia alertas.

### Virtualização

Marque **Virtualization** no Noir para habilitar libvirt com QEMU/KVM, virt-manager e virt-viewer para máquinas virtuais, além de Podman, Podman Desktop, Distrobox e Kontainer para contêineres. Para usar a aceleração por hardware, verifique se o processador oferece suporte e se a virtualização está habilitada no firmware. Depois de aplicar a configuração, encerre a sessão e entre novamente para receber o grupo `libvirtd`, que dá à conta acesso à administração do libvirt. Para conferir:

```bash
ls -l /dev/kvm
id -nG
virsh -c qemu:///system list --all
podman --version
distrobox-list
```

- **Máquinas virtuais:** QEMU/KVM executa um sistema convidado completo, com kernel próprio. Crie a máquina no virt-manager e configure UEFI, TPM virtual ou rede por ponte conforme a necessidade.
- **Contêineres Distrobox:** compartilham o kernel da máquina e podem acessar seu diretório pessoal. Use-os para ambientes de desenvolvimento com software de confiança. O Podman executa os contêineres, o Podman Desktop administra imagens e contêineres, e o Kontainer gerencia ambientes Distrobox. [Implicações de segurança do Distrobox](https://distrobox.it/#security-implications)

A criação dos ambientes e a escolha das imagens ficam a cargo do usuário. Se o Podman Desktop não encontrar o Podman da sua conta, confira na sua sessão a conexão ao socket do Podman em modo sem privilégios (`rootless`).

### Codex CLI

Marque **Codex CLI** no Noir para adicionar `codex` ao ambiente do sistema. O módulo usa a revisão fixa em `modules/optional/codex-package.nix`, que resolve a versão 0.171.0. Na primeira avaliação com o opcional habilitado, o Nix obtém o tarball do GitHub com verificação de hash quando o conteúdo ainda não está no cache. O canal principal da máquina fornece os demais pacotes. Desmarcar o opcional e aplicar a configuração remove o executável gerenciado e preserva os arquivos pessoais em `~/.codex` ou `$CODEX_HOME` e as credenciais da conta. [Release do Codex CLI 0.171.0](https://github.com/openai/codex/releases/tag/rust-v0.171.0)

Para atualizar a versão, consulte `https://channels.nixos.org/nixpkgs-unstable/git-revision`, use o commit publicado no comando abaixo e atualize juntos a revisão e o hash em `codex-package.nix`.

```bash
nix-prefetch-url --unpack "https://codeload.github.com/NixOS/nixpkgs/tar.gz/COMMIT"
nix-instantiate --eval --strict -E '
  let
    pkgs = import <nixpkgs> {};
    codex = import ./modules/optional/codex-package.nix { inherit pkgs; };
  in { inherit (codex) version drvPath; }
'
```

Confira a versão resolvida, publique com o Codex CLI marcado e faça o dry-build. Depois de aplicar pelo fluxo normal, confira com `codex --version`.

## Identidade Git e falhas parciais

Depois da primeira publicação protegida, o instalador usa `git config --global` pela própria conta selecionada para definir o nome do autor (`user.name`), o e-mail (`user.email`) e o nome `main` para a primeira branch de novos repositórios (`init.defaultBranch`). O Git guarda essas preferências em `~/.gitconfig` ou, se esse arquivo estiver ausente, em um arquivo de configuração global XDG já existente, normalmente `~/.config/git/config`. Aliases, assinatura e demais preferências são preservados.

Antes de buscar atualizações na primeira instalação, o instalador confere o diretório pessoal da conta e os caminhos de configuração global. Use o caminho físico da conta em `HOME` e, se configurar `XDG_CONFIG_HOME`, mantenha-o dentro de `HOME`. Remova redirecionamentos como `GIT_CONFIG_GLOBAL` e resolva definições duplicadas ou incluídas das três chaves que o instalador grava.

Se a instalação for concluída e o Git falhar em seguida, a cópia do NixOS permanece implantada. Pela conta selecionada, verifique o valor e a origem das entradas de escopo `global`.

```bash
git config --includes --show-origin --show-scope --get-regexp '^(user\.(name|email)|init\.defaultbranch)$'
```

Confira as permissões de escrita do arquivo global. Se houver chaves duplicadas ou valores herdados de um arquivo incluído, ajuste essas definições no arquivo de origem. Depois, execute os comandos correspondentes aos ajustes pendentes, usando os dados da sua conta:

```bash
git config --global user.name "NOVO_NOME"
git config --global user.email "NOVO_EMAIL"
git config --global init.defaultBranch main
```

`config/local.nix` registra as escolhas. Depois da primeira publicação, altere a autoria diretamente no Git quando precisar. A configuração de um repositório específico tem precedência sobre a global.

## Diagnóstico e recuperação

Se o instalador indicar mudanças locais, use `git status` e `git diff` no checkout para revisar os arquivos. Em caso de divergência, `git log --oneline --left-right HEAD...@{upstream}` mostra os commits exclusivos de cada lado. Resolva o estado da branch antes de repetir a instalação.

Depois de uma troca bem-sucedida, `nixos-config.previous` guarda a cópia que estava em uso e substitui o backup mais antigo, se houver. Se a troca atômica falhar, a implantação e seu backup existente ficam intactos. Se falhar apenas a gravação do backup, a nova cópia fica em uso, a cópia que estava em uso fica no caminho temporário informado e qualquer backup existente é preservado. Use o caminho temporário informado para recuperar a cópia que estava em uso.

Para voltar à cópia anterior, confira se `/etc/nixos/nixos-config.previous/personal.nix` e `/etc/nixos/nixos-config.previous/config/local.nix` correspondem à configuração que você quer recuperar. Preserve edições locais feitas desde a publicação. Sem executar o instalador em paralelo, troque os diretórios e valide os imports da máquina:

```bash
sudo mv -T --exchange --no-copy -- /etc/nixos/nixos-config.previous /etc/nixos/nixos-config
nixos-rebuild dry-build
```

Se o backup veio da implantação anterior à mudança de layout, restaure também o import da máquina que correspondia àquela cópia. Para aplicar após a validação, siga [Verificar e aplicar](#verificar-e-aplicar). Para iniciar um sistema já construído, escolha uma geração disponível no menu de inicialização do NixOS.

## Cuidados com credenciais e permissões

Guarde senhas, tokens e chaves privadas em arquivos com acesso restrito, fora do Git e de `/nix/store`, e faça os serviços lerem esses arquivos em tempo de execução. Valores gravados em arquivos Nix, inclusive em `local.nix`, podem aparecer em texto claro nos arquivos gerados e ficar acessíveis a outros usuários da máquina pelo Nix Store. [Manual do Nix sobre segredos](https://nix.dev/manual/nix/2.34/store/secrets)

Mantenha os arquivos de configuração importados protegidos contra escrita por contas sem autorização. Antes de usar a configuração em outra máquina, revise os serviços habilitados e as interfaces de rede em que eles escutam.
