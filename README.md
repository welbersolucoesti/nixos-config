# NixOS Personal Configurations

Configurações pessoais para NixOS, utilizando **Nixpkgs**, sem dependência de Flakes ou Home Manager.

Este repositório reúne configurações declarativas utilizadas no meu ambiente Linux, com foco em desenvolvimento de software, produtividade e facilidade de reprodução entre instalações.

## Objetivo

A proposta é simples: reduzir configurações manuais e manter o ambiente de trabalho documentado, versionado e reproduzível.

Em vez de reinstalar aplicativos, reconfigurar serviços e lembrar como resolver particularidades do hardware a cada instalação, essas definições são mantidas em arquivos Nix.

O repositório representa meu ambiente pessoal. Ele pode servir como referência para outros usuários, mas não pretende ser uma configuração universal.

## Ambiente

A configuração foi desenvolvida para NixOS com KDE Plasma e Wayland.

As definições incluem:

| Categoria | Recursos |
|---|---|
| Desenvolvimento | Eclipse Temurin JDK 25, IntelliJ IDEA, DBeaver |
| Navegadores | Google Chrome |
| Segurança | Bitwarden, fprintd e Polkit |
| Terminal | Zsh, Oh My Zsh, Git, Vim e Htop |
| Banco de dados | PostgreSQL 18 |
| Hardware | Bluetooth e remapeamento de teclado com keyd |

Alguns recursos dependem de hardware compatível ou da disponibilidade dos pacotes no canal Nixpkgs utilizado.

## Estrutura do repositório

```text
nix-configs/
├── .gitignore
├── README.md
└── personal.nix
```

**`personal.nix`** contém as configurações pessoais do sistema, incluindo aplicativos, serviços e ajustes de hardware.

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

**Pacotes não livres**

Alguns aplicativos utilizados exigem a permissão para pacotes não livres. Se necessário, configure no `configuration.nix`:

```nix
nixpkgs.config.allowUnfree = true;
```

**Hardware**

O leitor biométrico e o remapeamento de teclado dependem de compatibilidade com o hardware utilizado.

**Serviços**

Revise a configuração do PostgreSQL antes de utilizá-la em ambientes com dados importantes.

### 5. Validar e aplicar

Primeiro, execute:

```bash
sudo nixos-rebuild dry-build
```

Esse comando avalia a configuração e apresenta as derivações que precisariam ser construídas, sem ativar uma nova geração.

Se a avaliação estiver correta:

```bash
sudo nixos-rebuild switch
```

O NixOS construirá e ativará a configuração.

## PostgreSQL

O módulo habilita o PostgreSQL 18 para desenvolvimento local.

Configuração:

- Escuta TCP limitada a `localhost`.
- Porta `5432`.
- Autenticação TCP local utilizando SCRAM-SHA-256.
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

O ambiente utiliza **Eclipse Temurin JDK 25** como distribuição Java padrão.

Pacote Nixpkgs:

```nix
temurin-bin-25
```

Para verificar a instalação:

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

## Remapeamento da tecla Copilot

Uma das personalizações deste ambiente é o remapeamento da tecla Copilot para controle de reprodução multimídia.

Em determinados teclados, essa tecla emite a combinação:

```text
LeftShift + LeftMeta + F23
```

O módulo utiliza `keyd` para transformá-la em:

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

O `keyd` realiza o remapeamento em uma camada independente dos atalhos específicos do KDE Plasma, permitindo seu uso em sessões Wayland e X11.

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
- Verifique as alterações antes de executar `nixos-rebuild` com privilégios administrativos.
- Mantenha os arquivos e diretórios importados protegidos contra modificações não autorizadas.
- Adapte configurações específicas de usuário e hardware.

## Filosofia

Este repositório nasceu de uma necessidade prática: **não precisar resolver o mesmo problema duas vezes**.

Cada ajuste manual que puder ser representado de forma declarativa se torna uma oportunidade de melhorar a próxima instalação.

A proposta não é automatizar tudo a qualquer custo, mas tornar o ambiente de desenvolvimento mais previsível, compreensível e fácil de manter.

---

**Nota:** este é um projeto pessoal, compartilhado como referência e ponto de partida. Revise e adapte as configurações antes de utilizá-las em sua própria instalação.
