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

O projeto usa a revisão do Nixpkgs disponível na máquina. As versões dos pacotes podem variar entre instalações. Se um pacote ou opção estiver disponível na avaliação, mas faltar na hora de aplicar, confira qual revisão cada ambiente está usando. Se a máquina usa canais, compare as listas de `nix-channel --list` e `sudo nix-channel --list`.

## Instalar ou atualizar

O GitHub é a fonte de verdade. A pasta obtida com `git clone` é o **checkout de desenvolvimento**, onde você usa Git e mantém suas alterações. `/etc/nixos/nixos-config/` é a **cópia implantada**, que o NixOS importa e o instalador atualiza com os arquivos versionados. O arquivo `config/local.nix` fica fora do Git em ambas as cópias. Após a primeira instalação, edite as escolhas da máquina no arquivo implantado.

Execute pela conta Linux que receberá a identidade Git. Use `sudo` apenas quando solicitado na publicação.

```bash
bash install.sh
```

1. Na primeira instalação, informe a conta Linux, o nome e o e-mail de autoria. Confira o resumo e confirme. Nas atualizações, o instalador reutiliza a identidade da cópia implantada.
2. O instalador executa `git fetch` para o remoto configurado na branch e apresenta os commits e arquivos alterados. Se você autorizar, `git merge --ff-only` avança o checkout até o commit apresentado usando o objeto já buscado. Recusar encerra a instalação. Alterações não commitadas, commits apenas locais e branches divergentes exigem que você resolva o estado do checkout.
3. Na primeira instalação, se o checkout ainda estiver sem `config/local.nix`, escolha KDE ou XFCE para preencher o modelo versionado. Se já houver um arquivo, a identidade precisa coincidir exatamente com a informada. O instalador confere os tipos das opções locais e os campos obrigatórios. O `dry-build` manual avalia a configuração completa da máquina, incluindo as asserções do NixOS.
4. Confirme o destino. O instalador publica os arquivos regulares versionados e o módulo local, sem `.git`. Ao substituir uma implantação, guarda a cópia anterior em `/etc/nixos/nixos-config.previous`. A troca atômica de diretórios usa `mv --exchange --no-copy` do GNU Coreutils e exige suporte do sistema de arquivos. Guarde ajustes avulsos fora da pasta de implantação para preservá-los por mais de uma atualização.
5. Na primeira instalação, o instalador configura o Git global pela conta selecionada depois da publicação.

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

Valide os imports e o restante da configuração da máquina:

```bash
sudo nixos-rebuild dry-build
```

Se houver erro, corrija a configuração antes de continuar. Depois de conferir o resultado, somente o proprietário aplica manualmente a configuração:

```bash
sudo nixos-rebuild switch
```

Confira a sessão gráfica e os serviços depois da ativação. Repita a instalação e a validação para atualizar a cópia implantada.

## Configuração local

`personal.nix` já importa `config/local.nix`. Para mudar as escolhas da estação, use `sudoedit /etc/nixos/nixos-config/config/local.nix`. Veja a estrutura em [config/local.example.nix](config/local.example.nix).

`personalConfig.desktop` aceita `"kde"`, `"xfce"` ou `null` para delegar o desktop à configuração da máquina. `personalConfig.username` deve identificar uma conta normal já declarada na máquina. Os campos de autoria registram as escolhas locais. Se o instalador indicar que o arquivo está incompleto ou incompatível, corrija-o no caminho indicado antes de repetir a instalação. Se uma implantação mais antiga guardava as escolhas em `/etc/nixos/nixos-config/local.nix`, guarde o original e transfira as opções para `/etc/nixos/nixos-config/config/local.nix` conforme o modelo.

Cron e virtualização começam desativados. Para habilitá-los ou retirar o tema do Zsh, adicione as linhas desejadas **dentro do bloco `personalConfig = { ... };`**:

```nix
cron.enable = true;
virtualization.enable = true;
zsh.theme = null;
```

O tema padrão do Oh My Zsh é `"bira"`. Em `zsh.theme`, você pode indicar outro tema disponível. Com `null`, os plugins, o autocompletar, as sugestões e o destaque de sintaxe continuam disponíveis. Depois de editar, siga [Verificar e aplicar](#verificar-e-aplicar). Se trocar de ambiente gráfico, revise também a sessão padrão, o login automático e as declarações gráficas da máquina.

## Perfis gráficos

| Perfil | Sessão | Gerenciador de login |
| --- | --- | --- |
| KDE | KDE Plasma da configuração padrão do NixOS | SDDM |
| XFCE | XFCE em X11 | LightDM |

### Complementos do XFCE

Estes complementos fazem parte do perfil XFCE.

| Complemento | Função | Quando entra em uso |
| --- | --- | --- |
| Whisker Menu | Menu de aplicativos pesquisável | Presente no modelo inicial. Em painéis existentes, adicione manualmente. |
| Docklike | Barra de tarefas com ícones e janelas agrupadas | Presente no modelo inicial. Em painéis existentes, adicione manualmente. |
| Clipman | Histórico da área de transferência | Adicione manualmente se quiser guardar o histórico. |
| Thunar com Xarchiver | Compactação e extração no gerenciador de arquivos | Use o menu do botão direito. Se for solicitado um gerenciador de arquivos compactados, escolha Xarchiver. |

Na primeira abertura do painel, o XFCE pode carregar o modelo do projeto, que inclui menu, barra de tarefas, seletor de áreas de trabalho, bandeja, relógio e ações da sessão. Se você já tem um painel configurado ou se um complemento não aparecer, abra **Painel → Preferências do painel → Itens** para adicioná-lo. Confira o resultado em uma sessão XFCE depois de aplicar a configuração. [Preferências do painel](https://docs.xfce.org/xfce/xfce4-panel/preferences)

## Aplicativos e serviços

```text
nixos-config/
├── install.sh
├── personal.nix
├── config/
│   ├── local.example.nix
│   └── options.nix
└── modules/
    ├── applications/  Navegadores, senhas, desenvolvimento, escritório, JDK e Zsh
    ├── desktops/      Perfis KDE e XFCE, com painel e Thunar em xfce/
    ├── optional/      Cron, virtualização e tema do Zsh
    ├── services/      Bluetooth, fprintd, keyd, Polkit e PostgreSQL
    └── system/        Pacotes gerais, manutenção do Nix e ZRAM
```

`personal.nix` declara os imports explicitamente. `modules/optional/virtualization.nix` reúne os imports do conjunto opcional, incluindo seus aplicativos e os módulos de serviço libvirt e Podman. O instalador inclui os arquivos versionados, inclusive o modelo XML do painel. Ao adicionar um módulo, declare seu import na configuração.

| Recurso | Configuração |
| --- | --- |
| Navegadores | Google Chrome instalado. O módulo de Firefox do NixOS fica desabilitado. O projeto permite pacotes proprietários em todo o sistema, com prioridade sobre configurações comuns de outros módulos. |
| Desenvolvimento | IntelliJ IDEA, VS Code, DBeaver, Postman e Eclipse Temurin JDK 25. |
| Uso geral | Bitwarden, WPS Office, Vim, wget, usbutils, Git, htop e pv. |
| Biometria e Bluetooth | O serviço fprintd depende do leitor. Cadastre as digitais separadamente. O adaptador Bluetooth começa ligado, e o pareamento fica a cargo do usuário. |
| Terminal | A conta escolhida passa a usar Zsh, com Oh My Zsh e os plugins de Git e sudo. |
| Teclado | O keyd transforma `leftshift+leftmeta+f23` em reproduzir ou pausar. Em alguns notebooks, essa combinação é emitida pela tecla Copilot. A regra vale para todos os teclados gerenciados. Teste no seu teclado, pois o evento pode variar. |

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

Com `personalConfig.cron.enable = true`, o agendamento `nixos-cron` roda diariamente às 03h no horário da máquina. Entre na conta selecionada na instalação e crie o script privado no diretório pessoal dessa conta:

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

`personalConfig.virtualization.enable = true` habilita libvirt com QEMU/KVM, virt-manager e virt-viewer para máquinas virtuais, além de Podman, Podman Desktop, Distrobox e Kontainer para contêineres. Para usar a aceleração por hardware, verifique se o processador oferece suporte e se a virtualização está habilitada no firmware. Depois de aplicar a configuração, encerre a sessão e entre novamente para receber o grupo `libvirtd`, que dá à conta acesso à administração do libvirt. Para conferir:

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
sudo nixos-rebuild dry-build
```

Se o backup veio da implantação anterior à mudança de layout, restaure também o import da máquina que correspondia àquela cópia. Para aplicar após a validação, siga [Verificar e aplicar](#verificar-e-aplicar). Para iniciar um sistema já construído, escolha uma geração disponível no menu de inicialização do NixOS.

## Cuidados com credenciais e permissões

Guarde senhas, tokens e chaves privadas em arquivos com acesso restrito, fora do Git e de `/nix/store`, e faça os serviços lerem esses arquivos em tempo de execução. Valores gravados em arquivos Nix, inclusive em `local.nix`, podem aparecer em texto claro nos arquivos gerados e ficar acessíveis a outros usuários da máquina pelo Nix Store. [Manual do Nix sobre segredos](https://nix.dev/manual/nix/2.34/store/secrets)

Mantenha os arquivos de configuração importados protegidos contra escrita por contas sem autorização. Antes de usar a configuração em outra máquina, revise os serviços habilitados e as interfaces de rede em que eles escutam.
