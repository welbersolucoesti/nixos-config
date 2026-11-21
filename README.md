# Configuração declarativa dos notebooks NixOS

Este repositório reúne os aplicativos, serviços e perfis gráficos **KDE Plasma** e **XFCE** dos notebooks do David. Usa módulos tradicionais do NixOS, sem Flakes ou Home Manager.

Para usar o projeto, você precisa de um **NixOS já instalado**, uma conta Linux normal declarada na configuração da máquina e acesso a `sudo` para publicar os arquivos. Prepare uma cópia da configuração da máquina, publique os arquivos do projeto e depois aplique a configuração. Para instalar o NixOS do zero, siga o [manual do NixOS](https://nixos.org/manual/nixos/stable/#ch-installation).

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

## Publicar a primeira revisão

### Preparar uma cópia da configuração da máquina

O instalador avalia suas mudanças antes de você editar a configuração em uso. Se sua instalação usa os dois arquivos padrão em `/etc/nixos`, faça uma cópia fora do repositório:

```bash
copia=$(mktemp -d)
cp /etc/nixos/configuration.nix /etc/nixos/hardware-configuration.nix "$copia/" &&
  printf '%s\n' "$copia/configuration.nix"
```

Abra no editor o `configuration.nix` do caminho exibido. Se a configuração importar outros arquivos por caminhos relativos, mantenha esses arquivos na mesma posição em relação à cópia. Preserve a conta Linux normal, `system.stateVersion` e as definições de inicialização, rede, áudio, energia e hardware da máquina.

Adapte o cabeçalho e os imports da cópia com o padrão abaixo. Preserve os demais argumentos e o corpo do seu módulo.

```nix
args@{ config, pkgs, ... }:
let
  deployment = (args.nixosConfigDeployment or (path: path)) /etc/nixos/nixos-config;
in
{
  imports = [
    ./hardware-configuration.nix
    (deployment + "/current/personal.nix")
  ];

  # Preserve a conta Linux, os demais imports e as configurações da máquina.
}
```

Use `current/personal.nix` como único import deste repositório. Ele já carrega os módulos do projeto e as escolhas da máquina. O trecho `args@` permite que o instalador teste os arquivos que pretende publicar. Retire imports antigos feitos diretamente do repositório, de `local.nix` e dos módulos avulsos de cron ou virtualização.

- Para usar **XFCE**, retire da cópia as declarações da máquina que ativam KDE Plasma (`services.desktopManager.plasma6.enable`) ou SDDM (`services.displayManager.sddm.enable`).
- Para usar **KDE**, retire as que ativam XFCE (`services.xserver.desktopManager.xfce.enable`) ou LightDM (`services.xserver.displayManager.lightdm.enable`).

### Executar o instalador

Na pasta do repositório, execute o comando pela própria conta Linux que receberá a identidade Git, sem colocar `sudo` antes de `bash`. Rode no mesmo terminal em que criou a variável `copia` ou substitua `"$copia/configuration.nix"` pelo caminho exibido na etapa anterior. O instalador pede `sudo` na hora da publicação protegida.

```bash
bash install.sh --configuration "$copia/configuration.nix"
```

1. Escolha KDE ou XFCE. Na pergunta sobre a conta Linux, pressione Enter para aceitar a conta sugerida. Informe o nome e o e-mail que devem aparecer como autor dos seus commits.
2. Aguarde a avaliação da cópia. Se houver erro, corrija a cópia e execute o comando novamente.
3. Confira o destino e a revisão apresentados. Digite `s` para publicar. Enter no menu de ambientes gráficos ou `n` na confirmação cancela.
4. Na primeira publicação protegida, o instalador grava a identidade Git depois de publicar os arquivos. Se aparecer `Revisão publicada` e depois um erro do Git, veja [Identidade Git e falhas parciais](#identidade-git-e-falhas-parciais).

Por padrão, o instalador lê os arquivos gravados no commit atual (`HEAD`). Edições em andamento só entram na publicação depois de registradas em um commit. Se aparecer `Arquivo regular ausente no commit`, use uma revisão que contenha todos os arquivos esperados pelo instalador. Para escolher outro commit, acrescente `--revision HASH` ao comando. Se a revisão já foi publicada nesta máquina, consulte [Recuperar uma revisão](#recuperar-uma-revisão).

Para ensaiar sem `sudo`, acrescente `--destination /CAMINHO/DESTINO` ao comando. Escolha um caminho sem espaços, fora do repositório, cujo diretório pai já exista e permita escrita pela sua conta. Use esse mesmo caminho, sem aspas, no lugar de `/etc/nixos/nixos-config` na cópia de `configuration.nix`. Deixe o instalador criar o diretório de destino. Nesse modo, a identidade Git fica registrada apenas no arquivo local do ensaio. Para a publicação protegida, restaure o caminho padrão na cópia e retire `--destination` do comando.

### Verificar e aplicar

Depois da publicação protegida, abra o arquivo em uso com `sudoedit /etc/nixos/configuration.nix` e repita as mudanças da cópia avaliada. Depois, confira os caminhos e valide a configuração:

```bash
readlink /etc/nixos/nixos-config/current
readlink /etc/nixos/nixos-config/current/config/local.nix
nixos-rebuild dry-build
```

O primeiro `readlink` deve mostrar `revisions/` seguido do hash publicado. O segundo deve mostrar `/etc/nixos/nixos-config/config/local.nix`. O `dry-build` avalia os arquivos importados pela configuração da máquina e mostra o que seria construído, sem ativar o sistema. Rode-o depois de ajustar os imports, mesmo que já esteja na pasta do repositório. Se houver erro, corrija a configuração antes de aplicar. Confira o funcionamento dos serviços e a sessão gráfica depois da ativação.

Depois de revisar o resultado, somente o proprietário aplica manualmente a configuração com `sudo nixos-rebuild switch`. Quando o arquivo da máquina já estiver migrado, use `bash install.sh` para publicar novas revisões. As escolhas da máquina ficam no arquivo local.

## Configuração local

O instalador cria `/etc/nixos/nixos-config/config/local.nix` na primeira publicação. Todas as revisões publicadas usam o mesmo arquivo, fora do repositório. Para mudar suas escolhas depois da instalação, abra o arquivo com `sudoedit /etc/nixos/nixos-config/config/local.nix`. Veja a estrutura em [config/local.example.nix](config/local.example.nix).

No módulo local, `personalConfig.desktop` aceita `"kde"` ou `"xfce"`. `personalConfig.username` deve identificar uma conta normal válida já declarada na máquina. Os campos de autoria Git registram as escolhas da primeira instalação.

Cron e virtualização começam desativados. Se quiser habilitá-los ou retirar o tema do Zsh, adicione apenas as linhas que desejar **dentro do bloco `personalConfig = { ... };`** criado pelo instalador:

```nix
cron.enable = true;
virtualization.enable = true;
zsh.theme = null;
```

O tema padrão do Oh My Zsh é `"bira"`. Em `zsh.theme`, você pode indicar outro tema disponível. Com `null`, os plugins, o autocompletar, as sugestões e o destaque de sintaxe continuam disponíveis. Salve e siga os passos de [verificação e aplicação](#verificar-e-aplicar), começando pelo `dry-build`. Se trocar de ambiente gráfico, confira também as declarações da máquina conforme a seção [Publicar a primeira revisão](#publicar-a-primeira-revisão). Se houver sessão padrão ou login automático configurado, revise essas escolhas.

Se uma implantação anterior guardava o arquivo em `/etc/nixos/nixos-config/local.nix`, preserve o original e transfira os ajustes para `/etc/nixos/nixos-config/config/local.nix` manualmente. Complete a identidade usando o modelo versionado. Retire o import direto do arquivo local na cópia da máquina antes da publicação.

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

`personal.nix` declara os imports explicitamente. `modules/optional/virtualization.nix` reúne os imports do conjunto opcional, incluindo seus aplicativos e os módulos de serviço libvirt e Podman. O inventário no começo de `install.sh` lista o que a implantação recebe, incluindo o modelo do painel. Ao adicionar um arquivo necessário, atualize o import correspondente e o inventário.

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

Recuperar uma **revisão publicada** aponta `current` para arquivos Nix antigos que serão usados na próxima construção. Uma geração excluída deixa de estar disponível para rollback, mesmo se a revisão com seus módulos ainda estiver em `revisions/`. Veja [Recuperar uma revisão](#recuperar-uma-revisão).

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

Se o instalador parar **antes de publicar** por causa do Git, confira a mensagem. Os caminhos globais precisam ficar dentro do diretório pessoal da conta, com propriedade e permissões adequadas e sem links simbólicos. O instalador também verifica variáveis que redirecionam a configuração ou a autoria e chaves duplicadas ou definidas em arquivos incluídos. Resolva o problema indicado antes de tentar novamente.

Se aparecer **`Revisão publicada`** e depois um erro do Git, os arquivos do NixOS já foram publicados. O instalador informa quais valores confirmou e onde parou. Pela própria conta, veja o valor e o arquivo de origem de cada preferência:

```bash
git config --global --includes --show-origin --get-regexp '^(user\.(name|email)|init\.defaultbranch)$'
```

Execute somente os comandos correspondentes aos ajustes que faltarem, substituindo os exemplos pelos seus dados:

```bash
git config --global user.name "NOVO_NOME"
git config --global user.email "NOVO_EMAIL"
git config --global init.defaultBranch main
```

`config/local.nix` registra as escolhas. Depois da primeira publicação, altere a autoria diretamente no Git quando precisar. Reconstruir o sistema ou executar novamente o instalador preserva as preferências Git existentes. A configuração de um repositório específico tem precedência sobre a global.

## Recuperar uma revisão

O instalador mantém as versões publicadas em `/etc/nixos/nixos-config/revisions/` e verifica a integridade dos arquivos antes de trocar `current`. O link indica qual versão será usada na próxima construção. Todas usam as escolhas atuais de `config/local.nix`. Com os imports da máquina migrados, a configuração publicada funciona independentemente da cópia do repositório.

Na pasta do repositório, substitua `HASH_ANTERIOR` pelo código completo exibido pelo instalador ao preservar a revisão anterior. Valide a revisão com a configuração atual da máquina:

```bash
bash install.sh --check-rollback HASH_ANTERIOR
```

A verificação pode recusar revisões antigas sem o vínculo para o arquivo local ou incompatíveis com a configuração atual. Se houver erro, mantenha a revisão atual.

A avaliação e a troca manual são operações separadas. O `mv` abaixo substitui o link `current` de forma atômica, por renomeação no mesmo diretório. Entre a avaliação e a troca, porém, outra publicação ou uma edição da configuração pode mudar o estado que foi validado. Evite fazer essas mudanças em paralelo e, se algo mudou, rode a verificação novamente antes da troca. Use o mesmo hash nos dois passos:

```bash
cd /etc/nixos/nixos-config &&
  sudo ln -s -- revisions/HASH_ANTERIOR .current-recovery &&
  sudo mv -Tf -- .current-recovery current &&
  nixos-rebuild dry-build
```

Se o `dry-build` passar e você quiser colocar a revisão recuperada em uso, siga a etapa de ativação em [Verificar e aplicar](#verificar-e-aplicar).

## Cuidados com credenciais e permissões

Guarde senhas, tokens e chaves privadas em arquivos com acesso restrito, fora do Git e de `/nix/store`, e faça os serviços lerem esses arquivos em tempo de execução. Valores gravados em arquivos Nix, inclusive em `local.nix`, podem aparecer em texto claro nos arquivos gerados e ficar acessíveis a outros usuários da máquina pelo Nix Store. [Manual do Nix sobre segredos](https://nix.dev/manual/nix/2.34/store/secrets)

Mantenha os arquivos de configuração importados protegidos contra escrita por contas sem autorização. Antes de usar a configuração em outra máquina, revise os serviços habilitados e as interfaces de rede em que eles escutam.
