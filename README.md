# NixOS Personal Configurations

Configurações pessoais para NixOS, utilizando **Nixpkgs**, sem dependência de Flakes ou Home Manager.

Este repositório reúne configurações declarativas utilizadas no meu ambiente Linux, com foco em desenvolvimento de software, produtividade e facilidade de reprodução entre instalações.

## Objetivo

A proposta é simples: reduzir configurações manuais e manter o ambiente de trabalho documentado, versionado e reproduzível.

Em vez de reinstalar aplicativos, reconfigurar serviços e lembrar como resolver particularidades do hardware a cada instalação, essas definições são mantidas em arquivos Nix.

O repositório mantém a configuração pessoal dos notebooks do David.

## Ambiente

A configuração foi desenvolvida para NixOS com KDE Plasma e Wayland. Com `personalConfig.desktop` ausente, a configuração da máquina continua responsável pelo ambiente gráfico. Os perfis opcionais são KDE Plasma com SDDM e XFCE com LightDM em X11.

As definições incluem:

| Categoria | Recursos |
|---|---|
| Desenvolvimento | Eclipse Temurin JDK 25, IntelliJ IDEA, Visual Studio Code, DBeaver |
| Navegadores | Google Chrome; Firefox desabilitado com `lib.mkForce false` |
| Segurança | Bitwarden, fprintd e Polkit |
| Terminal e utilitários | Zsh, Oh My Zsh, Git, Vim, Htop, wget e usbutils |
| Banco de dados | PostgreSQL 18 |
| Hardware | Bluetooth habilitado e ligado no boot; remapeamento de teclado com keyd |
| Memória | Swap comprimido em RAM (ZRAM), com zstd e tamanho lógico de 50% da RAM |
| Manutenção Nix | `nix-command` habilitado (sem Flakes); coleta de lixo semanal com retenção de 60 dias |

Alguns recursos dependem de hardware compatível ou da disponibilidade dos pacotes no canal Nixpkgs utilizado.

## Estrutura do repositório

```text
nixos-config/
├── .gitignore
├── AGENTS.md
├── README.md
├── config/
│   ├── local.example.nix
│   └── options.nix
├── install.sh
├── modules/
│   ├── desktops/
│   │   ├── kde.nix
│   │   └── xfce.nix
│   ├── optional/
│   │   ├── cron.nix
│   │   ├── virtualization.nix
│   │   └── zsh-theme.nix
│   ├── personal.nix
│   └── system/
│       ├── hardware.nix
│       ├── maintenance.nix
│       ├── packages.nix
│       └── postgresql.nix
└── personal.nix
```

**`personal.nix`** importa os módulos e a configuração local quando ela existe. `config/options.nix` declara o perfil, a identidade e as opções dos módulos. `config/local.example.nix` é o modelo versionado. A configuração particular fica na implantação, em `/etc/nixos/nixos-config/config/local.nix`.

Os módulos em `modules/system/` declaram pacotes, serviços, hardware e manutenção. `modules/personal.nix` reúne as configurações de Zsh e Git, e `modules/desktops/` contém os perfis gráficos.

**`modules/optional/`** contém os módulos de agendamento, virtualização e tema do Zsh. As escolhas ficam na configuração local da máquina.

**`AGENTS.md`** estabelece orientações para agentes de IA que trabalham neste repositório, incluindo limites de edição e validação.

**`.gitignore`** define os padrões de arquivos que não serão rastreados pelo Git.

## Preparação de uma instalação mínima do NixOS

Entre no TTY com sua conta local após concluir a instalação oficial do NixOS. O `install.sh` pressupõe um NixOS já instalado e publica a configuração deste repositório. A instalação do sistema, incluindo discos e bootloader, é feita pelo instalador oficial. [Manual do NixOS](https://nixos.org/manual/nixos/stable/#ch-installation)

### Conectividade Wi-Fi pelo TTY

Este procedimento pressupõe que o NetworkManager esteja instalado, ativo e gerenciando a interface Wi-Fi. No TTY, confira o estado da interface, liste as redes e substitua `NOME_DA_REDE` pelo nome da rede escolhida. O último comando verifica a conectividade.

```bash
nmcli device status
nmcli device wifi list
nmcli --ask device wifi connect "NOME_DA_REDE"
ping -c 3 nixos.org
```

O `--ask` solicita a senha interativamente, mantendo-a fora da linha de comando e do histórico do shell. [Referência do nmcli](https://networkmanager.dev/docs/api/latest/nmcli.html)

Se o NetworkManager estiver indisponível, use Ethernet para o bootstrap ou consulte o [manual oficial do NixOS sobre redes](https://nixos.org/manual/nixos/stable/#sec-networking).

A conexão de bootstrap permite baixar o Git e clonar o repositório. Para manter a rede após reinicializações, preserve as definições persistentes em `/etc/nixos/configuration.nix`. O NetworkManager pode salvar perfis localmente. Mantenha nomes de rede e credenciais fora do repositório e as credenciais fora do Nix Store.

### Git temporário e checkout

Depois de confirmar a conexão no TTY, abra um ambiente temporário com Git. `nix-shell -p git` disponibiliza o comando nessa sessão e deixa a configuração declarativa intacta. [Referência do nix-shell](https://nix.dev/manual/nix/latest/command-ref/nix-shell.html)

```bash
nix-shell -p git
```

Dentro desse ambiente, clone o repositório e entre no diretório:

```bash
git clone https://github.com/welbersolucoesti/nixos-config.git
cd nixos-config
```

Em seguida, [prepare a cópia revisada de `configuration.nix` e execute a primeira instalação](#3-preparar-e-avaliar-a-configuração-da-máquina). Depois da publicação, [ajuste a configuração real da máquina](#4-aplicar-os-ajustes-à-configuração-da-máquina) e [valide e aplique manualmente](#5-validar-a-configuração-e-aplicar-manualmente).

## Instalação

### 1. Pré-requisitos

- NixOS instalado e funcionando.
- Acesso administrativo (`sudo`).
- Git.
- Um canal ou revisão do Nixpkgs que disponibilize os pacotes utilizados.

Esta configuração é um módulo complementar. Ela **não substitui** os arquivos `configuration.nix` e `hardware-configuration.nix` da instalação.

### 2. Obter os arquivos

Use o checkout obtido na preparação. O instalador publica os módulos de um commit do checkout local. Por padrão, usa `HEAD`. Para escolher outro commit revisado, passe `--revision HASH`. A publicação exige todos os módulos da estrutura atual.

Os exemplos abaixo consideram o repositório localizado em:

```text
~/nixos-config/
```

### 3. Preparar e avaliar a configuração da máquina

Na primeira instalação, ou se a máquina ainda importa `personal.nix` pelo checkout, prepare uma cópia revisada de `configuration.nix`. Preserve seus argumentos e capture o conjunto inteiro com `args@`. Antes do corpo do módulo, introduza a referência à implantação. O trecho abaixo mostra as alterações na estrutura, com o destino protegido padrão:

```nix
args@{ config, pkgs, ... }:
let
  deployment = (args.nixosConfigDeployment or (path: path)) /etc/nixos/nixos-config;
in
{
  imports = [
    ./hardware-configuration.nix
    (deployment + "/current/personal.nix")
    # Preserve os demais imports da máquina.
  ];
  # Preserve o restante da configuração.
}
```

Mantenha os imports relativos acessíveis na cópia, incluindo o módulo de hardware. A entrada `current/personal.nix` já importa a configuração local. Retire da lista qualquer import direto de `local.nix` e os imports antigos de cron e virtualização. Para manter esses recursos, use as opções em `config/local.nix`. Para XFCE, remova da cópia as declarações que habilitam `services.desktopManager.plasma6.enable` e `services.displayManager.sddm.enable`.

Depois de preparar a cópia revisada e conferir seus imports relativos, execute a primeira instalação na raiz do checkout com sua conta normal:

```bash
bash install.sh --configuration /caminho/para/configuration.nix
```

Na primeira execução, escolha KDE Plasma ou XFCE e informe o nome e o e-mail de autoria Git. Execute o instalador pela própria conta Linux selecionada, já declarada em `users.users`. A avaliação usa o Nixpkgs local e reproduz a árvore de implantação em um diretório temporário. Pressione Enter no menu ou responda `n` na confirmação para cancelar. Depois da confirmação, o instalador publica os módulos e `config/local.nix`. Na implantação padrão, só então aplica a identidade Git com as permissões da conta executora.

Use `bash install.sh` sem argumentos apenas quando `/etc/nixos/configuration.nix` já estiver migrado. Nas execuções seguintes, o instalador preserva `config/local.nix` e a configuração Git da conta.

Para testar a publicação sem privilégios, use `--destination` com um caminho alternativo em um diretório temporário gravável, fora do checkout. Use esse mesmo caminho na cópia da configuração. Publicações alternativas e verificações de rollback deixam a configuração Git intacta.

### 4. Aplicar os ajustes à configuração da máquina

Depois da publicação, compare a cópia avaliada com `/etc/nixos/configuration.nix` e faça os ajustes manualmente. Retire também do arquivo real os imports antigos de cron, virtualização e `local.nix`. Preserve `hardware-configuration.nix`, `system.stateVersion` e os demais ajustes.

**Migração de uma implantação existente**

Se o arquivo local ainda estiver em `/etc/nixos/nixos-config/local.nix`, preserve o original e copie manualmente seus ajustes para `/etc/nixos/nixos-config/config/local.nix` antes de publicar a nova revisão. Se o destino já existir, revise o conteúdo e incorpore apenas os ajustes necessários. Use `config/local.example.nix` como referência para completar a conta e a identidade Git. O instalador aponta campos ausentes ou incompatíveis e mantém o arquivo intacto. Para a publicação, use uma cópia revisada da configuração da máquina com apenas o import de `current/personal.nix` da implantação. A troca de `current` preserva a revisão anterior.

**Perfil gráfico**

O instalador grava a escolha em `/etc/nixos/nixos-config/config/local.nix`. Para trocar de perfil depois da instalação, o proprietário pode editar esse arquivo:

```nix
personalConfig.desktop = "xfce";
```

Use `"kde"` para KDE Plasma com SDDM. Antes de ativar XFCE, retire também da configuração efetiva da máquina as declarações que habilitam Plasma e SDDM, mesmo que já tenha removido essas linhas na cópia usada pelo instalador. Preserve os ajustes de áudio, teclado e hardware. Revise a sessão padrão e o login automático, se configurados.

**Opções locais**

Acrescente ao `local.nix` somente as escolhas que deseja aplicar:

```nix
personalConfig.cron.enable = true;
personalConfig.virtualization.enable = true;
personalConfig.zsh.theme = null;
```

Cron e virtualização ficam desativados por padrão, e o tema padrão é `"bira"`. O instalador preserva o conteúdo do arquivo local nas execuções seguintes.

**Conta Linux e autoria Git**

Revise `personalConfig.username`, `personalConfig.git.userName` e `personalConfig.git.userEmail` no arquivo local. O módulo usa uma conta normal já declarada e configura seu shell como Zsh. Escolha o e-mail que deseja publicar nos commits. Veja a seção [Git](#git) para a precedência dos arquivos e o alcance da configuração.

**Pacotes não livres**

Alguns aplicativos utilizados exigem a permissão para pacotes não livres. O módulo `modules/system/packages.nix` já inclui:

```nix
nixpkgs.config.allowUnfree = lib.mkForce true;
```

O `lib.mkForce` dá prioridade a essa definição sobre definições comuns de outros módulos. Revise essa política ao adaptar o módulo.

**Hardware**

O leitor biométrico e o remapeamento de teclado dependem de compatibilidade com o hardware utilizado. O módulo habilita o `fprintd` e o Polkit, mas não cadastra impressões digitais; o cadastro e o funcionamento da autenticação precisam ser verificados na máquina.

**Serviços**

Revise a configuração do PostgreSQL antes de utilizá-la em ambientes com dados importantes.

### 5. Validar a configuração e aplicar manualmente

**Validação pelo Emu (agente Codex), sem `sudo`:**

```bash
nixos-rebuild dry-build
```

O comando avalia a configuração do sistema que importa o módulo e determina o que precisaria ser construído, **sem ativar uma nova geração**. A execução sem `sudo` depende das permissões e da configuração do Nix. Executá-lo na raiz deste repositório não seleciona automaticamente o `personal.nix`; a importação precisa estar configurada conforme as etapas anteriores.

Para alterações exclusivamente de documentação, `git diff --check` é suficiente; não é necessário executar `nixos-rebuild dry-build`. O `dry-build` não valida a qualidade do Markdown nem garante que os serviços funcionarão depois de ativados. Para conferir problemas de espaços em branco nas alterações locais, execute:

```bash
git diff --check
```

Se as alterações já estiverem na área de preparação do Git (`git add`), verifique também:

```bash
git diff --cached --check
```

**Aplicação exclusiva pelo proprietário da máquina (David):** após revisar pessoalmente os arquivos e os resultados da validação, somente David decide quando executar, no próprio terminal:

```bash
sudo nixos-rebuild switch
```

**O Emu e quaisquer outros agentes automatizados estão proibidos de executar `nixos-rebuild switch`, `nixos-rebuild boot` e `nixos-rebuild test`, com ou sem `sudo`.** Apenas David pode ativar ou agendar a ativação de uma geração. `dry-build` avalia e planeja derivações sem ativá-las; não comprova o funcionamento do serviço nem substitui testes funcionais. A responsabilidade dos agentes termina na validação permitida e no relato dos resultados.

## Agendamento diário opcional

O módulo `modules/optional/cron.nix` executa `$HOME/.local/share/nixos-cron/cron.sh` como a conta de `personalConfig.username`, diariamente às **03h00 no horário local**. O serviço e o timer usam o nome `nixos-cron`. O serviço é `oneshot` e termina ao concluir o script. Se o arquivo não existir, a execução é ignorada. `Persistent=false` impede recuperar tarefas perdidas enquanto o computador estava desligado.

Para habilitar o agendamento, defina `personalConfig.cron.enable = true;` no `local.nix`.

Após revisar e validar, o proprietário aplica manualmente a configuração:

```bash
sudo nixos-rebuild switch
```

Na sessão da conta selecionada, crie e edite manualmente o script privado fora do repositório:

```bash
mkdir -p "$HOME/.local/share/nixos-cron"
chmod 700 "$HOME/.local/share/nixos-cron"
touch "$HOME/.local/share/nixos-cron/cron.sh"
chmod 600 "$HOME/.local/share/nixos-cron/cron.sh"
vim "$HOME/.local/share/nixos-cron/cron.sh"
```

O Bash do Nixpkgs lê o arquivo diretamente, sem exigir permissão de execução. O `PATH` inclui coreutils, findutils, grep, sed e awk; não depende da configuração interativa do Zsh. Para outros programas, declare os pacotes em `path` no módulo. Não use `sudo` no script nem inclua senhas, tokens ou chaves no repositório. O conteúdo privado não é copiado para o Nix Store, e cada computador pode manter comandos diferentes.

Para verificar o timer, iniciar uma execução manual e consultar os logs:

```bash
systemctl list-timers --all nixos-cron.timer
sudo systemctl start nixos-cron.service
journalctl -u nixos-cron.service
systemctl status nixos-cron.timer nixos-cron.service
journalctl -u nixos-cron.service --since today --no-pager
```

O `ConditionPathExists` faz o systemd pular o início do serviço quando o script não existe; isso não equivale a uma execução bem-sucedida nem constitui monitoramento de falhas. Confira o resultado da última execução com `systemctl status` e os registros com `journalctl`. Uma falha do script pode exigir investigação manual; o timer, por si só, não envia alertas.

Mesmo na execução manual, o serviço roda como a conta selecionada. Alterações no script privado dispensam rebuild. Mudanças no módulo `modules/optional/cron.nix` exigem reconstruir e aplicar a configuração. O caminho é derivado do diretório pessoal declarado para a conta em `users.users`. O diretório deve estar acessível no horário agendado.

## Virtualização opcional (QEMU/KVM e Distrobox)

O módulo `modules/optional/virtualization.nix` configura o serviço libvirt, habilita o virt-manager e disponibiliza o virt-viewer. Também habilita o Podman e instala o Podman Desktop (interface gráfica para contêineres, imagens e pods), o Distrobox e o Kontainer (interface Qt/Kirigami para gerenciar ambientes Distrobox no KDE Plasma). Por padrão, a virtualização fica desativada.

O módulo adiciona a conta selecionada em `personalConfig.username` ao grupo `libvirtd`. Pertencer a esse grupo permite administrar recursos de virtualização e exige confiança no usuário autorizado. Verifique também se a CPU e o firmware oferecem suporte à virtualização de hardware e se `/dev/kvm` está disponível.

Para habilitar o recurso, defina `personalConfig.virtualization.enable = true;` no `local.nix`.

Valide a configuração importada com `nixos-rebuild dry-build`, sem `sudo`. A aplicação, se desejada, é feita **exclusivamente por David**, executando manualmente `sudo nixos-rebuild switch`. Nenhum agente deve executar comandos de ativação.

Após ativar e abrir uma nova sessão, confira:

```bash
lscpu | grep Virtualization
ls -l /dev/kvm
id -nG
virsh -c qemu:///system list --all
```

Checklist para uma eventual ativação, a ser executado pelo proprietário na máquina:

- Conferir suporte de virtualização no processador e no firmware (BIOS/UEFI).
- Validar `nixos-rebuild dry-build` com o módulo efetivamente importado, sem ativar o sistema.
- Após aplicação manual por David e nova sessão, verificar `/dev/kvm`, grupos do usuário e conexão `qemu:///system`.
- Criar uma VM de teste e verificar inicialização, armazenamento, console gráfico e rede virtual.
- Se necessário, configurar separadamente firmware UEFI/OVMF, TPM virtual e conectividade bridge.

A criação de VMs, a rede virtual NAT ou bridge, o firmware UEFI/OVMF e o TPM virtual podem exigir configuração adicional. O módulo não configura essas opções explicitamente nem garante compatibilidade com todo hardware. O virt-manager pode ser utilizado no KDE Plasma Wayland, normalmente via XWayland.

### Contêineres de desenvolvimento (Podman, Podman Desktop, Distrobox e Kontainer)

**QEMU/KVM não é Distrobox.** QEMU/KVM executa máquinas virtuais completas; Distrobox integra contêineres Linux ao ambiente do usuário, compartilhando o kernel do host. O módulo utiliza **Podman** como runtime, **Podman Desktop** para inspecionar e administrar contêineres, imagens e pods, e **Kontainer** como interface gráfica específica para o Distrobox; não instala DistroShelf nem Docker.

Configuração declarativa incluída no módulo:

```nix
virtualisation.podman.enable = true;

environment.systemPackages = with pkgs; [
  virt-viewer
  podman-desktop
  distrobox
  kontainer
];
```

A presença desses pacotes e do serviço Podman **não cria contêineres automaticamente**. As imagens, os contêineres e os aplicativos exportados pelo Distrobox são gerenciados posteriormente pelo usuário; não são declarados neste arquivo. A compatibilidade do pacote `kontainer` depende da revisão do Nixpkgs utilizada.

Após David importar, validar e aplicar manualmente o módulo, poderá conferir os comandos e criar um ambiente de teste:

```bash
podman --version
distrobox --version
distrobox-list
# Exemplo opcional: cria um contêiner de desenvolvimento
# distrobox-create --name dev-fedora --image fedora:latest
```

O exemplo de criação permanece comentado para evitar alterações involuntárias. O Kontainer e o Podman Desktop poderão ser abertos pelo lançador de aplicativos do KDE quando estiverem instalados. A conexão do Podman Desktop com o runtime deve ser verificada na sessão do usuário; a instalação do pacote, por si só, não garante a detecção automática do socket rootless. O Podman pode funcionar em modo rootless para contêineres do usuário; esse uso depende de permissões e configurações adequadas do sistema. Contêineres Distrobox não oferecem o mesmo isolamento de uma máquina virtual completa.

A opção de virtualização habilita em conjunto libvirt/QEMU/KVM e Podman/Podman Desktop/Distrobox/Kontainer.

## Memória comprimida (ZRAM)

O módulo `personal.nix` habilita swap comprimido em memória com `zramSwap.enable = true`, algoritmo `zstd` e `memoryPercent = 50`. Esse percentual define o tamanho lógico do dispositivo, não uma reserva antecipada de metade da RAM física.

A configuração dispensa partição ou arquivo swap em disco para o uso do ZRAM, mas **não fornece hibernação em disco**. Depois de aplicar a configuração manualmente, confira:

```bash
zramctl
swapon --show
```

## Manutenção do Nix Store

O módulo habilita a interface moderna do Nix por meio de `nix.settings.experimental-features = [ "nix-command" ];`. **Flakes continuam desabilitados**; o repositório segue utilizando canais e módulos tradicionais.

A coleta de lixo é agendada semanalmente com `nix.gc.automatic = true`, `dates = "weekly"` e `options = "--delete-older-than 60d"`. Isso torna elegíveis para exclusão gerações com mais de 60 dias. **Gerações excluídas não podem mais ser usadas para rollback**; objetos ainda referenciados por raízes do Nix são preservados.

Para consultar as gerações disponíveis:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Para listar objetos atualmente elegíveis à coleta, sem apagá-los:

```bash
nix-store --gc --print-dead
```

A aplicação das mudanças continua sendo responsabilidade exclusiva do proprietário da máquina, após validação.

## PostgreSQL

O módulo habilita o PostgreSQL 18 para desenvolvimento local.

Configuração:

- Escuta TCP limitada a `localhost`.
- Porta `5432`.
- Autenticação TCP local utilizando SCRAM-SHA-256.
- Criação ou alteração de senhas configurada para usar SCRAM-SHA-256 (`password_encryption`).
- Nenhuma senha definida diretamente no arquivo Nix.

As regras de autenticação TCP configuradas são:

```text
host all all 127.0.0.1/32 scram-sha-256
host all all ::1/128      scram-sha-256
```

O módulo declara apenas regras `host` para conexões TCP. **Ele não estabelece explicitamente a autenticação por socket Unix** (`local`); a política efetiva depende das regras geradas pelo módulo NixOS e de sua composição. Não presuma que sockets Unix exigem senha SCRAM. Antes de depender dessa política, consulte o arquivo `pg_hba.conf` efetivo da instância (por exemplo, usando `SHOW hba_file;` no PostgreSQL) e revise as entradas `local`. Alterar a política de autenticação exige decisão separada.

A configuração não disponibiliza conexões TCP para outros computadores da rede.

**Importante:** a senha dos usuários do banco deve ser administrada separadamente. Este repositório não configura senhas, bancos de aplicação ou políticas de backup.

Não utilize esta configuração como referência de segurança para produção sem uma revisão apropriada.

## Java

O módulo inclui **Eclipse Temurin JDK 25** nos pacotes globais do sistema. Ele não define `JAVA_HOME` nem configura o JDK utilizado por cada IDE ou projeto.

Pacote Nixpkgs:

```nix
temurin-bin-25
```

Após aplicar a configuração, confira a versão encontrada no `PATH`:

```bash
java -version
javac -version
```

A instalação global do JDK não impede a utilização de outras versões em ambientes de desenvolvimento específicos.

## Zsh

O módulo habilita:

- Zsh como shell do usuário configurado.
- Oh My Zsh.
- Plugins `git` e `sudo`.
- Autocompletar, sugestões automáticas e destaque de sintaxe.

O tema do Oh My Zsh é configurado separadamente por `personalConfig.zsh.theme`. O padrão é `"bira"`. Use o nome de outro tema disponível ou defina `null` para usar o Zsh com Oh My Zsh e sem tema.

### Atalhos de manutenção

`environment.shellAliases` define aliases globais para os shells dos usuários, incluindo o Zsh. Após aplicar a configuração, abra um novo terminal para utilizá-los.

| Alias | Efeito |
|---|---|
| `nix-update` | Atualiza os canais do usuário root com `sudo nix-channel --update`; não atualiza o sistema em execução. |
| `nix-check` | Executa `nixos-rebuild dry-build`: avalia e planeja a construção, sem realizar uma compilação completa nem ativar o sistema. |
| `nix-system-build` | Executa `nixos-rebuild build`: constrói a configuração sem ativá-la. |
| `nix-switch` | Executa `sudo nixos-rebuild switch`: constrói e ativa a configuração. Uso manual exclusivo do proprietário; agentes não devem executá-lo. |
| `nix-generations` | Lista as gerações do perfil do sistema. |
| `nix-diff` | Executa `nix store diff-closures` com dois caminhos explícitos, na ordem origem e destino. |

O nome `nix-system-build` preserva o comando nativo `nix-build`. Para comparar gerações, escolha dois caminhos existentes; não é necessário que seus números sejam consecutivos. Por exemplo, se as gerações 10 e 14 existirem:

```bash
nix-diff /nix/var/nix/profiles/system-10-link /nix/var/nix/profiles/system-14-link
```

A comparação apenas consulta as closures, sem alterar ou ativar gerações. `nix-diff` habilita `nix-command` somente nessa chamada. `/run/current-system` pode ser usado como um dos caminhos para representar a geração ativa.

## Git

O Git continua disponível no sistema. Na primeira publicação no destino protegido, o instalador grava apenas `user.name`, `user.email` e `init.defaultBranch` com `git config --global`, pela conta selecionada. O Git grava em `~/.gitconfig` ou no arquivo XDG existente quando `~/.gitconfig` estiver ausente. Aliases, assinatura e as demais preferências são preservados. Configurações de cada repositório continuam com precedência. [Documentação das configurações do Git](https://git-scm.com/docs/git-config#FILES)

O instalador confere o `HOME` da conta, aceita `XDG_CONFIG_HOME` dentro dele e recusa links simbólicos, permissões inseguras e variáveis que mudam o arquivo de configuração ou a autoria. Se as chaves estiverem duplicadas ou vierem de arquivos incluídos, revise suas origens antes de instalar.

`config/local.nix` registra as escolhas da instalação. Editar `personalConfig.git.userName` ou `personalConfig.git.userEmail` ali não altera o arquivo global do Git, mesmo após um rebuild. Para atualizar a identidade depois, execute pela própria conta:

```bash
git config --global user.name "NOVO_NOME"
git config --global user.email "NOVO_EMAIL"
git config --global init.defaultBranch main
```

Se alguma gravação falhar depois da publicação, a revisão NixOS permanece publicada. O instalador informa quais chaves foram verificadas e onde parou. Revise as origens com `git config --show-origin --list` e complete manualmente as chaves pendentes. Uma nova execução preserva o arquivo Git no estado em que estiver.

## Remapeamento da tecla Copilot

Uma das personalizações deste ambiente é o remapeamento da tecla Copilot para controle de reprodução multimídia.

Em determinados teclados, essa tecla emite a combinação:

```text
LeftShift + LeftMeta + F23
```

O módulo configura o `keyd` com a intenção de transformá-la em:

```text
Play/Pause
```

Configuração:

```nix
services.keyd = {
  enable = true;

  keyboards.default = {
    ids = [ "*" ];

    settings.main = {
      "leftshift+leftmeta+f23" = "playpause";
    };
  };
};
```

O remapeamento é configurado no serviço `keyd`, separado dos atalhos do KDE Plasma. A presença dessa regra no módulo não comprova seu funcionamento: valide a combinação emitida pelo teclado e o resultado na máquina antes de depender desse atalho.

**Observação:** nem todos os teclados possuem a mesma implementação da tecla Copilot. A configuração também utiliza `ids = [ "*" ]`, abrangendo os teclados gerenciados pelo serviço.

## Versionamento e reprodução

O objetivo deste repositório é manter configurações reutilizáveis entre instalações.

Entretanto, o `personal.nix` sozinho não garante versões de pacotes idênticas em máquinas diferentes. Os resultados também dependem da revisão do Nixpkgs utilizada.

Para inspecionar a origem dos canais configurados, utilize:

```bash
nix-channel --list
sudo nix-channel --list
```

Para consultar a revisão do Nixpkgs no contexto do usuário atual, quando o canal estiver acessível:

```bash
nix-instantiate --eval --strict -E '(import <nixpkgs> {}).lib.version'
```

Registre também qual canal ou revisão é utilizado pelo `nixos-rebuild` no ambiente de root. Esses comandos ajudam a documentar o ambiente, mas **não fixam** uma revisão e não garantem, isoladamente, uma reprodução exata.

Para reprodução exata, é necessário fixar a revisão das dependências por um mecanismo apropriado.

Este projeto prioriza inicialmente uma configuração simples, baseada nos módulos tradicionais do NixOS.

### Implantação e recuperação

- O checkout da conta do usuário serve para desenvolvimento. O instalador copia apenas os módulos do commit selecionado e verifica seus hashes antes de publicar.
- `/etc/nixos/nixos-config/config/local.nix` guarda a identidade, o perfil e os ajustes da máquina fora das revisões. Cada revisão aponta `config/local.nix` para esse arquivo por um link absoluto. O checkout e os arquivos versionados da revisão contêm apenas o modelo `config/local.example.nix` e as opções. Mantenha credenciais em arquivos protegidos fora do Nix Store.
- A implantação protegida fica em `/etc/nixos/nixos-config`, sob propriedade de root. O publicador recebe o conteúdo por entrada padrão e confere os hashes após gravá-lo em uma área privada dentro do destino protegido ou em seu diretório pai. O link `current` só muda após a revisão estar completa em `revisions/HASH`. A revisão anterior continua disponível mesmo após a troca.

Para recuperar uma revisão, use o hash completo informado pelo instalador. Primeiro, no checkout, avalie a revisão preservada com o `local.nix` e a configuração da máquina atuais:

```bash
bash install.sh --check-rollback HASH_ANTERIOR
```

Se a avaliação falhar, mantenha `current` e revise a incompatibilidade. Revisões antigas sem o vínculo para `config/local.nix` são recusadas. Mesmo com o vínculo, uma revisão pode desconhecer opções do arquivo local ou ter serviços incompatíveis com os imports da máquina.

`--check-rollback` verifica a compatibilidade em uma operação separada e não torna atômica a troca manual posterior de `current`. No exemplo abaixo, o último comando substitui o link atomicamente por renomeação no mesmo diretório. A avaliação e a renomeação podem ocorrer sobre estados diferentes se a configuração mudar nesse intervalo. Execute os comandos a partir de `/etc/nixos/nixos-config`:

```bash
sudo ln -s -- revisions/HASH_ANTERIOR .current-recovery &&
  sudo mv -Tf -- .current-recovery current
```

Valide novamente com `nixos-rebuild dry-build`. Essa troca recupera os módulos publicados e preserva `local.nix`; qualquer alteração no sistema em execução depende da aplicação manual pelo proprietário.

## Segurança

Antes de utilizar ou compartilhar qualquer configuração:

- Revise os serviços habilitados e as interfaces de rede expostas.
- Não armazene senhas, tokens ou outras credenciais diretamente em arquivos Nix públicos.
- Para alterações no módulo Nix, o agente deve validar com `nixos-rebuild dry-build`, sem `sudo`, e informar o resultado. Para alterações exclusivamente de documentação, basta `git diff --check`. Somente David pode executar manualmente comandos de ativação (`nixos-rebuild switch`, `boot` ou `test`).
- Mantenha os arquivos e diretórios importados protegidos contra modificações não autorizadas.
- Adapte configurações específicas de usuário e hardware.

## Filosofia

Este repositório nasceu de uma necessidade prática: **não precisar resolver o mesmo problema duas vezes**.

Cada ajuste manual que puder ser representado de forma declarativa se torna uma oportunidade de melhorar a próxima instalação.

A proposta não é automatizar tudo a qualquer custo, mas tornar o ambiente de desenvolvimento mais previsível, compreensível e fácil de manter.

---

**Nota:** este é um projeto pessoal, compartilhado como referência e ponto de partida. Revise e adapte as configurações antes de utilizá-las em sua própria instalação.
