# NixOS Personal Configurations

Configurações pessoais para NixOS, utilizando **Nixpkgs**, sem dependência de Flakes ou Home Manager.

Este repositório reúne configurações declarativas utilizadas no meu ambiente Linux, com foco em desenvolvimento de software, produtividade e facilidade de reprodução entre instalações.

## Objetivo

A proposta é simples: reduzir configurações manuais e manter o ambiente de trabalho documentado, versionado e reproduzível.

Em vez de reinstalar aplicativos, reconfigurar serviços e lembrar como resolver particularidades do hardware a cada instalação, essas definições são mantidas em arquivos Nix.

O repositório representa meu ambiente pessoal. Ele pode servir como referência para outros usuários, mas não pretende ser uma configuração universal.

## Ambiente

A configuração foi desenvolvida para um ambiente NixOS com KDE Plasma e Wayland. O `personal.nix` não habilita o ambiente gráfico nem configura a sessão Wayland; essas definições devem existir na configuração principal da máquina.

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
nix-configs/
├── .gitignore
├── AGENTS.md
├── README.md
├── personal.nix
├── cron.nix
└── virtualization.nix
```

**`personal.nix`** contém as configurações pessoais do sistema, incluindo aplicativos, serviços e ajustes de hardware.

**`cron.nix`** define um serviço e um timer opcionais para um script privado externo ao repositório.

**`virtualization.nix`** disponibiliza opcionalmente QEMU/KVM, libvirt, virt-manager e virt-viewer. O arquivo não é ativado enquanto não for importado na configuração da máquina.

**`AGENTS.md`** estabelece orientações para agentes de IA que trabalham neste repositório, incluindo limites de edição e validação.

**`.gitignore`** define os padrões de arquivos que não serão rastreados pelo Git.

## Instalação

### 1. Pré-requisitos

- NixOS instalado e funcionando.
- Acesso administrativo (`sudo`).
- Git.
- Um canal ou revisão do Nixpkgs que disponibilize os pacotes utilizados.

Esta configuração é um módulo complementar. Ela **não substitui** os arquivos `configuration.nix` e `hardware-configuration.nix` da instalação.

### 2. Obter os arquivos

Clone este repositório para um diretório de sua preferência ou copie os arquivos manualmente.

Os exemplos abaixo consideram o repositório localizado em:

```text
~/nix-configs/
```

### 3. Importar o módulo pessoal

No arquivo `/etc/nixos/configuration.nix`, **preserve a lista `imports` existente** e acrescente somente `./personal.nix`, caso ainda não esteja presente. O exemplo consolidado abaixo é apenas uma referência: **não copie a lista inteira sobre a sua configuração**.

```nix
imports = [
  ./hardware-configuration.nix
  ./personal.nix
  # ./cron.nix           # opcional, somente quando David decidir habilitar
  # ./virtualization.nix # opcional, somente quando David decidir habilitar
  # ... outros módulos já utilizados pela máquina ...
];
```

As linhas comentadas são opcionais e não ativam os módulos. Preserve também todos os imports não exibidos no exemplo. Para usar caminhos relativos como `./personal.nix`, crie um link simbólico apontando para o arquivo versionado.

A partir da raiz do repositório:

```bash
sudo ln -s "$(realpath personal.nix)" /etc/nixos/personal.nix
```

**Atenção:** se `/etc/nixos/personal.nix` já existir, faça um backup e remova ou renomeie o arquivo antigo antes de criar o link.

Alternativamente, o `configuration.nix` pode importar diretamente o caminho absoluto do módulo.

### 4. Adaptar a configuração

Antes de aplicar o arquivo, revise os pontos abaixo.

**Nome do usuário**

A configuração contém:

```nix
users.users.david.shell = pkgs.zsh;
```

Substitua `david` pelo nome do usuário da sua instalação.

**Identidade Git**

O módulo também define `user.name` e `user.email` no arquivo `/etc/gitconfig`. Antes de aplicar a configuração, substitua esses dados pelos seus e considere que o endereço de e-mail ficará visível se o repositório for público.

Por ser uma configuração **de sistema**, os valores podem ser herdados por outros usuários. Configurações de usuário (`~/.gitconfig` ou `~/.config/git/config`) e de repositório podem sobrescrevê-los.

**Pacotes não livres**

Alguns aplicativos utilizados exigem a permissão para pacotes não livres. O `personal.nix` já inclui:

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

O módulo `cron.nix` executa `/home/david/.local/share/nixos-cron/cron.sh` como usuário `david`, diariamente às **03h00 no horário local**. O serviço é `oneshot` e termina ao concluir o script. Se o arquivo não existir, a execução é ignorada; `Persistent=false` impede recuperar tarefas perdidas enquanto o computador estava desligado.

A partir da raiz do repositório, crie o link (se o destino já existir, revise-o antes):

```bash
sudo ln -s "$(realpath cron.nix)" /etc/nixos/cron.nix
```

**Somente quando desejar habilitar o agendamento**, acrescente `./cron.nix` à lista `imports` já existente em `/etc/nixos/configuration.nix`. Não remova `personal.nix`, `hardware-configuration.nix` ou outros módulos. Consulte o exemplo consolidado na seção de instalação.

Após revisar e validar, o proprietário aplica manualmente a configuração:

```bash
sudo nixos-rebuild switch
```

Como usuário `david`, crie e edite manualmente o script privado fora do repositório:

```bash
mkdir -p /home/david/.local/share/nixos-cron
chmod 700 /home/david/.local/share/nixos-cron
touch /home/david/.local/share/nixos-cron/cron.sh
chmod 600 /home/david/.local/share/nixos-cron/cron.sh
vim /home/david/.local/share/nixos-cron/cron.sh
```

O Bash do Nixpkgs lê o arquivo diretamente, sem exigir permissão de execução. O `PATH` inclui coreutils, findutils, grep, sed e awk; não depende da configuração interativa do Zsh. Para outros programas, declare os pacotes em `path` no módulo. Não use `sudo` no script nem inclua senhas, tokens ou chaves no repositório. O conteúdo privado não é copiado para o Nix Store, e cada computador pode manter comandos diferentes.

Para verificar o timer, iniciar uma execução manual e consultar os logs:

```bash
systemctl list-timers --all david-cron.timer
sudo systemctl start david-cron.service
journalctl -u david-cron.service
systemctl status david-cron.timer david-cron.service
journalctl -u david-cron.service --since today --no-pager
```

O `ConditionPathExists` faz o systemd pular o início do serviço quando o script não existe; isso não equivale a uma execução bem-sucedida nem constitui monitoramento de falhas. Confira o resultado da última execução com `systemctl status` e os registros com `journalctl`. Uma falha do script pode exigir investigação manual; o timer, por si só, não envia alertas.

Mesmo na execução manual, o serviço roda como `david`. Alterações no conteúdo do script privado **não exigem rebuild**; mudanças em `cron.nix` exigem reconstruir e aplicar a configuração. Ao adaptar para outra máquina, ajuste o usuário e os caminhos no módulo e nos comandos acima. O usuário precisa existir e o diretório pessoal deve estar acessível no horário agendado.

## Virtualização opcional (QEMU/KVM)

O arquivo `virtualization.nix` configura o serviço libvirt, habilita o virt-manager e disponibiliza o virt-viewer. É um módulo **opcional e inativo por padrão**: sua presença no repositório não instala nem habilita virtualização na máquina.

Para utilizá-lo futuramente, revise o usuário `david` e o grupo `libvirtd` no módulo. Pertencer a esse grupo permite administrar recursos de virtualização e exige confiança no usuário autorizado. Verifique também se a CPU e o firmware oferecem suporte à virtualização de hardware e se `/dev/kvm` está disponível.

A partir da raiz do repositório, crie o link simbólico apenas se o destino ainda não existir (caso exista, revise-o antes):

```bash
sudo ln -s "$(realpath virtualization.nix)" /etc/nixos/virtualization.nix
```

Depois, **somente quando decidir habilitar o recurso**, acrescente `./virtualization.nix` à lista de imports já existente em `/etc/nixos/configuration.nix`. Preserve todos os outros módulos, inclusive `./cron.nix` caso esteja habilitado. Consulte o exemplo consolidado na seção de instalação; não substitua a lista inteira.

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

**QEMU/KVM não é Distrobox.** QEMU/KVM executa máquinas virtuais completas; Distrobox integra contêineres Linux ao ambiente do usuário e exige um runtime de contêineres, como Podman ou Docker. Este módulo não instala Distrobox.

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
- Tema `bira`.
- Plugins `git` e `sudo`.
- Autocompletar, sugestões automáticas e destaque de sintaxe.

As configurações são administradas pelo módulo do NixOS.

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

O Git é instalado globalmente e recebe configurações padrão declarativas pelo NixOS, sem necessidade de Home Manager.

O módulo gerencia `/etc/gitconfig` com as opções:

```gitconfig
[user]
    name = David
    email = seu-email@example.com

[init]
    defaultBranch = main
```

O e-mail acima é apenas ilustrativo. No `personal.nix`, revise a identidade antes de publicar ou reutilizar a configuração. Como `/etc/gitconfig` é global para o sistema, outros usuários podem herdar essa identidade. Configurações específicas do usuário ou do repositório têm precedência.

Após aplicar a configuração, confira quais arquivos estão fornecendo os valores efetivos:

```bash
git config --list --show-origin
```

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
