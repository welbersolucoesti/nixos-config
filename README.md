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

Alguns recursos dependem de hardware compatível ou da disponibilidade dos pacotes no canal Nixpkgs utilizado.

## Estrutura do repositório

```text
nix-configs/
├── .gitignore
├── AGENTS.md
├── README.md
└── personal.nix
```

**`personal.nix`** contém as configurações pessoais do sistema, incluindo aplicativos, serviços e ajustes de hardware.

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

No arquivo `/etc/nixos/configuration.nix`, inclua:

```nix
imports = [
  ./hardware-configuration.nix
  ./personal.nix
];
```

Em seguida, crie um link simbólico apontando para o arquivo versionado.

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

**O Emu e quaisquer outros agentes automatizados estão proibidos de executar `nixos-rebuild switch`, com ou sem `sudo`.** Sua responsabilidade termina na validação e no relato do resultado. O comando `switch` constrói e ativa a configuração e exige privilégios administrativos.

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

A autenticação por socket Unix pode seguir regras diferentes.

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

Para reprodução exata, é necessário fixar a revisão das dependências por um mecanismo apropriado.

Este projeto prioriza inicialmente uma configuração simples, baseada nos módulos tradicionais do NixOS.

## Segurança

Antes de utilizar ou compartilhar qualquer configuração:

- Revise os serviços habilitados e as interfaces de rede expostas.
- Não armazene senhas, tokens ou outras credenciais diretamente em arquivos Nix públicos.
- Para alterações no módulo Nix, o agente deve validar com `nixos-rebuild dry-build`, sem `sudo`, e informar o resultado. Para alterações exclusivamente de documentação, basta `git diff --check`. Somente David pode executar manualmente `sudo nixos-rebuild switch`.
- Mantenha os arquivos e diretórios importados protegidos contra modificações não autorizadas.
- Adapte configurações específicas de usuário e hardware.

## Filosofia

Este repositório nasceu de uma necessidade prática: **não precisar resolver o mesmo problema duas vezes**.

Cada ajuste manual que puder ser representado de forma declarativa se torna uma oportunidade de melhorar a próxima instalação.

A proposta não é automatizar tudo a qualquer custo, mas tornar o ambiente de desenvolvimento mais previsível, compreensível e fácil de manter.

---

**Nota:** este é um projeto pessoal, compartilhado como referência e ponto de partida. Revise e adapte as configurações antes de utilizá-las em sua própria instalação.
