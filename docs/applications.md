# Aplicativos, serviços e módulos opcionais

[Projeto](../README.md) · [Índice](README.md)

## Aplicativos e serviços comuns

| Área | Configuração |
| --- | --- |
| Navegação | Google Chrome. O Noir desabilita o módulo do Firefox do NixOS e permite pacotes proprietários em todo o sistema. |
| Desenvolvimento | IntelliJ IDEA, Visual Studio Code, DBeaver, Postman e Eclipse Temurin JDK 25. |
| Uso geral | Bitwarden, ONLYOFFICE Desktop Editors, Inkscape, GIMP, Fastfetch, Vim, wget, usbutils, Git, htop e pv. |
| Fontes | JetBrainsMono Nerd Font e Microsoft Core Fonts. A derivação das fontes Microsoft inclui a licença. Consulte-a antes de distribuir a saída. |
| Terminal | A conta escolhida usa Zsh, Oh My Zsh, complementação, sugestões e destaque de sintaxe, com os plugins `git` e `sudo`. O Noir cria um `.zshrc` vazio na ativação se o arquivo estiver ausente e o diretório estiver disponível para escrita. |
| Bluetooth | O adaptador começa ligado. O pareamento fica a cargo da conta. |
| Biometria e autorização | fprintd e Polkit. A biometria depende de leitor compatível e de digitais cadastradas. |
| Teclado | O keyd mapeia `leftshift+leftmeta+f23` para reproduzir ou pausar em todos os teclados gerenciados. A combinação emitida pela tecla Copilot depende do hardware. |
| Memória | ZRAM com zstd e tamanho lógico de 50% da RAM. A hibernação requer swap em disco e configuração de retomada à parte. |

A lista comum reside em [`applications.nix`](../applications.nix). Terminais gráficos e atalhos específicos estão nas páginas dos [perfis](README.md#ambientes-gráficos).

Aplicativos comuns são disponibilizados ao sistema após a ativação. Preferências do aplicativo, como extensões de editor e arquivos do usuário, continuam na conta. Para mudar o conjunto de pacotes, consulte [Alterar aplicativos e serviços](customization.md#alterar-aplicativos-e-serviços).

### Java, Vim e ONLYOFFICE

O pacote `temurin-bin-25` fornece `java` e `javac`. Use `java -version` e `javac -version` para conferir a versão encontrada no terminal. A seleção de `JAVA_HOME` e do SDK da IDE depende de cada projeto.

O Vim inclui NERDTree (`:NERDTreeToggle`), indentação de quatro espaços, numeração, pesquisa incremental e undo persistente em `${XDG_STATE_HOME:-$HOME/.local/state}/vim/undo`.

O ONLYOFFICE Desktop Editors recebe os padrões de idioma `pt-BR` e tema `theme-night`. As preferências da conta têm precedência e ficam em `${XDG_CONFIG_HOME:-$HOME/.config}/onlyoffice/DesktopEditors.conf`.

### PostgreSQL

O PostgreSQL 18 escuta em `localhost:5432`. As regras TCP para os endereços locais IPv4 e IPv6 exigem SCRAM-SHA-256. As novas senhas gravadas pelo servidor também usam SCRAM-SHA-256. Sem `-h`, o cliente pode usar um socket Unix, sujeito às regras `local` do arquivo de autenticação efetivo.

```bash
pg_isready -h localhost -p 5432
psql -h localhost -p 5432 -U USUARIO -d BANCO -W
```

O exemplo de conexão pressupõe um usuário e banco já criados. Guarde senhas fora dos arquivos Nix, mantenha backups e revise autenticação e firewall antes de expor o serviço à rede.

A configuração do serviço declara como o PostgreSQL inicia e aceita conexões. Os bancos e usuários que forem criados fazem parte do estado persistente. Uma geração anterior usa os dados disponíveis no disco. Consulte [Gerações, rollback e dados](concepts.md#gerações-rollback-e-dados) antes de voltar após uma mudança na versão do servidor.

### Impressões digitais

Use os comandos abaixo na sessão da conta que usará o leitor para cadastrar e conferir uma digital.

```bash
fprintd-enroll -f right-index-finger
fprintd-list "$USER"
fprintd-verify
```

`fprintd-delete "$USER"` apaga todas as digitais da conta. O perfil [XFCE](desktops/xfce.md#autenticação-e-bloqueio) oferece também o comando `biometria` e configuração PAM específica. O comportamento no login e no desbloqueio precisa ser verificado no leitor físico.

## Módulos opcionais

As chaves e os controles estão descritos em [Preferências](configuration.md#preferências). Os três módulos abaixo começam desativados. Os recursos ficam disponíveis após publicação e ativação da configuração.

### CRON

`optionals.cron` habilita o serviço e o timer systemd `nixos-cron`. O timer roda diariamente às 03h no horário local, sem recuperar horários perdidos enquanto a máquina estava desligada. O serviço executa como a conta escolhida e só roda se existir o script privado em `~/.local/share/nixos-cron/cron.sh`. O Bash lê o arquivo em cada execução e o conteúdo fica fora do Git e do Nix Store.

```bash
cron_dir="$HOME/.local/share/nixos-cron"
mkdir -p -- "$cron_dir" &&
  chmod 700 -- "$cron_dir" &&
  (umask 077; touch -- "$cron_dir/cron.sh") &&
  chmod 600 -- "$cron_dir/cron.sh"
```

Edite o script pela própria conta. O serviço fornece utilitários básicos em seu próprio `PATH`. Os comandos abaixo mostram o próximo horário e os registros do serviço.

```bash
systemctl list-timers --all nixos-cron.timer
systemctl status nixos-cron.service
journalctl -u nixos-cron.service
```

O serviço termina após executar o script e pode aparecer inativo entre execuções. O timer não envia alertas. O administrador pode iniciar uma execução avulsa com `sudo systemctl start nixos-cron.service`, mantendo a execução do script sob a identidade da conta escolhida.

### Virtualização

`optionals.virtualization` habilita libvirt com QEMU/KVM, virt-manager e virt-viewer, além de Podman, Podman Desktop, Distrobox e Kontainer. A conta selecionada recebe o grupo `libvirtd`, que permite administrar o libvirt. Após aplicar, encerre a sessão e entre novamente para receber a associação ao grupo.

```bash
ls -l /dev/kvm
id -nG
virsh -c qemu:///system list --all
podman --version
distrobox-list
```

A aceleração requer suporte do processador e habilitação no firmware. A criação de máquinas virtuais, redes, contêineres e ambientes Distrobox fica a cargo da conta. Contêineres compartilham o kernel do hospedeiro e podem ter acesso ao diretório pessoal. Se o Podman Desktop não encontrar o Podman, confira a conexão ao socket da conta em modo sem privilégios.

### Codex CLI

`optionals.codex` adiciona `codex` ao ambiente do sistema. O módulo resolve o pacote em [uma revisão própria do Nixpkgs](../core/optional/codex-package.nix), com hash verificado, independente da revisão usada pelos demais pacotes. A avaliação pode precisar obter o tarball na primeira utilização. Desativar o opcional retira o executável gerenciado ao aplicar a configuração e preserva os arquivos pessoais e as credenciais.

O comando abaixo consulta a versão resolvida e a derivação a partir da raiz do checkout.

```bash
nix-instantiate --eval --strict -E '
  let
    pkgs = import <nixpkgs> {};
    codex = import ./core/optional/codex-package.nix { inherit pkgs; };
  in { inherit (codex) version drvPath; }
'
```

Uma atualização da revisão requer atualizar também o hash, conferir a versão resolvida e validar a configuração com o opcional habilitado.

[Configuração](configuration.md) · [Manutenção](maintenance.md)
