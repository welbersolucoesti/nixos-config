# Como o NixOS e o Noir funcionam

[Projeto](../README.md) · [Índice](README.md)

## Nix, Nixpkgs e NixOS

| Nome | Papel |
| --- | --- |
| **Nix** | Ferramentas para avaliar expressões, construir pacotes e administrar o Nix Store. A linguagem usada nessas expressões também se chama Nix. É possível usar as ferramentas em outros sistemas. |
| **Nixpkgs** | Coleção de receitas de pacotes e bibliotecas Nix. Contém também os módulos que definem as opções do NixOS. |
| **NixOS** | Distribuição Linux que usa Nix e Nixpkgs para compor a configuração do sistema, incluindo aplicativos, serviços, kernel e inicialização. |
| **Noir** | Conjunto de módulos e um configurador para um NixOS já instalado. A máquina continua responsável por hardware, conta, rede e carregador de inicialização. |

## Ações e estado desejado

Em Debian ou Ubuntu, por exemplo, `sudo apt install htop` solicita ao gerenciador de pacotes que instale o htop naquele sistema. O gerenciador resolve dependências e registra a instalação. É uma operação **imperativa** porque o comando descreve a ação a executar. Essas distribuições também podem usar ferramentas declarativas para administrar máquinas.

No NixOS, o módulo abaixo inclui htop no conjunto de aplicativos do sistema. O arquivo descreve o **estado desejado**. A disponibilidade do executável no ambiente do sistema depende da construção e da ativação da configuração.

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.htop ];
}
```

Para retirar essa inclusão, remova `pkgs.htop` da lista e aplique a configuração revisada. O pacote ainda pode estar presente por outra declaração, por um perfil de usuário ou no Store por referência de outra geração. No Noir, htop já faz parte dos [aplicativos comuns](../applications.nix).

Em uma equipe, a declaração versionada permite revisar quais aplicativos devem estar disponíveis e reutilizar essa lista em outras máquinas. O custo é conhecer as opções do sistema de módulos e passar pela avaliação e ativação para efetivar a mudança. Uma instalação imperativa é conveniente para uma ação pontual. O Nix também permite experimentar ferramentas em uma sessão temporária, por exemplo com `nix-shell -p htop`.

## Da declaração ao sistema em execução

1. **Módulos e imports.** Um módulo pode declarar opções, definir valores e incluir outros módulos na lista `imports`. O sistema de módulos reúne essas contribuições. Por exemplo, listas de pacotes podem ser combinadas, enquanto definições incompatíveis de uma opção escalar podem gerar um erro.
2. **Avaliação.** O Nix interpreta as expressões, calcula os valores das opções necessárias e determina as derivações. Uma derivação descreve como produzir uma saída e quais entradas são necessárias. Uma checagem de sintaxe verifica somente se o arquivo pode ser lido como Nix.
3. **Construção.** O Nix materializa as saídas necessárias, construindo-as ou reutilizando resultados do Store ou de um cache binário configurado. Objetos do Store são tratados como imutáveis e têm caminhos com hash, normalmente sob `/nix/store`. Versões diferentes e suas dependências podem coexistir.
4. **Ativação.** O NixOS passa a usar a configuração construída e executa as ações de aplicação, como atualizar arquivos gerados e iniciar ou reiniciar serviços. `nixos-rebuild build` constrói sem ativar. O `switch` reúne construção e aplicação. O `dry-build` avalia e apresenta o que seria necessário construir ou obter.
5. **Gerações.** O perfil de sistema guarda referências a configurações construídas. Uma geração disponível pode oferecer um caminho de retorno. O sistema em execução, a geração apontada pelo perfil e a opção padrão do carregador podem divergir, sobretudo após uma ativação interrompida.

Por exemplo, se o módulo principal importa `applications.nix`, a lista de aplicativos desse arquivo é combinada com outras definições de `environment.systemPackages`. A máquina pode acrescentar um pacote como ripgrep e receber htop do módulo do Noir. Já duas definições incompatíveis para a mesma porta de um serviço podem interromper a avaliação. A checagem de sintaxe pode passar nos dois casos, pois a combinação das opções acontece depois.

Leitura oficial sobre [módulos](https://nix.dev/tutorials/module-system/index.html), [Nix Store](https://nix.dev/manual/nix/latest/store/) e [configuração do NixOS](https://nixos.org/manual/nixos/stable/#sec-changing-config).

## Gerações, rollback e dados

**Rollback** volta a uma configuração de sistema preservada. Uma geração depende dos objetos referenciados no Store e precisa continuar disponível para retorno. A coleta de lixo remove objetos que já não são alcançáveis a partir de referências preservadas, chamadas raízes. Apagar gerações antigas pode liberar essas referências e eliminar a possibilidade de retorno. [Manual da coleta de lixo do Nix](https://nix.dev/manual/nix/latest/command-ref/nix-collect-garbage.html)

| Camada | Exemplos | Como é recuperada |
| --- | --- | --- |
| Configuração declarada | Arquivos da máquina, módulos do Noir e preferências publicadas | Git e backups dos arquivos locais e da implantação. |
| Sistema construído | Aplicativos, kernel e configuração gerada | Gerações que ainda estejam disponíveis. |
| Preferências pessoais | Ajustes de aplicativo, favoritos, configurações editáveis da sessão | Backups do diretório pessoal e dos arquivos de configuração correspondentes. |
| Dados persistentes | Documentos, bancos de dados e estado de serviços em `/var/lib` | Backups ou procedimentos de recuperação próprios do dado. |

O NixOS tem partes imutáveis no Store e partes graváveis, como o diretório pessoal e os dados dos serviços. Uma geração anterior pode abrir os dados atuais com uma versão anterior do software. Antes de voltar após uma atualização que alterou o formato de um banco, confira a compatibilidade e o backup. A [recuperação do Noir](recovery.md) distingue retorno de geração, restauração dos arquivos publicados e restauração da escolha gráfica.

## O que o Noir acrescenta

O Noir reúne aplicativos, serviços e três perfis gráficos com imports explícitos. Separa a identidade em `config/local.nix`, as preferências em `settings.json` e os módulos versionados no Git. O configurador prepara uma cópia revisável desses arquivos para publicação. A [arquitetura](architecture.md) mostra onde cada decisão entra no fluxo.

No fluxo oficial, a configuração da máquina importa `noir.nix` da árvore publicada. A máquina continua responsável por iniciar com o hardware, a conta e a rede corretos. O Noir acrescenta aplicativos, serviços e, se escolhido, um perfil gráfico. Essa separação permite manter a configuração específica da máquina fora do repositório compartilhado.

O projeto usa módulos tradicionais do NixOS, com Nixpkgs selecionado pelo ambiente ou explicitamente no rebuild. Isso aproveita a configuração tradicional da máquina, mas exige que o operador saiba qual revisão está usando. Flakes oferecem uma forma de declarar entradas e registrar suas revisões em um arquivo de lock. Home Manager oferece módulos para declarar configurações de usuário. No Noir, configurações da sessão são tratadas pelos aplicativos e pelos módulos do projeto. A cobertura declarativa das preferências varia por aplicativo e perfil.

| Atualização | O que muda |
| --- | --- |
| **Repositório Noir** | Módulos, lista de aplicativos, configurador e recursos versionados. O Noir busca a revisão no Git e revisa a publicação. |
| **Nixpkgs** | Receitas, versões de pacotes e opções de módulos disponíveis à avaliação. A instalação pode selecioná-lo via canal ou `NIX_PATH`. Atualizar o checkout do Noir não atualiza esse conjunto. |

O mesmo commit do Noir pode produzir resultados diferentes com outra revisão de Nixpkgs, outra arquitetura ou entradas locais diferentes. O pacote opcional do Codex CLI fixa uma revisão própria e seu hash. Isso não fixa as entradas do sistema inteiro nem garante que caches, imagens e demais insumos continuem disponíveis. [Referência oficial sobre fixação do Nixpkgs](https://nix.dev/reference/pinning-nixpkgs)

Por exemplo, manter a revisão do Noir e trocar o Nixpkgs pode mudar a versão resolvida de htop ou a disponibilidade de uma opção gráfica. Em uma comparação entre máquinas, registre a revisão do Noir, a origem do Nixpkgs, a plataforma e as escolhas publicadas relevantes.

[Instalação](installation.md) · [Arquitetura](architecture.md) · [Personalização](customization.md)
