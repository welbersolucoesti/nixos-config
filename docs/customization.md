# Personalizar e manter um fork

[Projeto](../README.md) · [Índice](README.md)

Um **fork** é uma cópia do repositório Git mantida de forma independente. Use [as preferências locais](configuration.md) para wallpaper, tema Zsh ou opcionais existentes. Use o código versionado do fork para mudar pacotes, serviços, perfis e as opções oferecidas pelo configurador. A identidade e o JSON de cada máquina continuam fora do Git.

## Alterar aplicativos e serviços

Para incluir ripgrep em todas as instalações do fork, acrescente `ripgrep` à lista `environment.systemPackages` de [`applications.nix`](../applications.nix). Para retirar `fastfetch`, remova-o da mesma lista. Quando o aplicativo vem de um módulo dedicado, como o DBeaver, remova o import correspondente e confira usos em outros módulos e nos lançadores de sessão. Uma referência restante pode manter o pacote disponível ou deixar um atalho sem executável.

Para personalizar um serviço já declarado, edite sua definição. Por exemplo, alterar somente `port = 5432;` para `port = 5433;` em [`core/services/postgresql.nix`](../core/services/postgresql.nix) preserva a escuta local e as regras de autenticação. A mudança só afeta o serviço ao aplicar a configuração. Na máquina de teste, consulte `pg_isready -h localhost -p 5433` e ajuste a porta dos clientes que precisarem conectar.

## Criar e importar um módulo

Se o aplicativo precisar de configuração própria, separe-a em um módulo. A alternativa abaixo administra ripgrep a partir de `core/applications/ripgrep.nix` no fork.

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.ripgrep ];
}
```

Acrescente `./core/applications/ripgrep.nix` como mais um item da lista `imports` existente em [`applications.nix`](../applications.nix), ao lado dos módulos dos outros aplicativos. Retire a entrada direta de ripgrep se ela tiver sido usada no exemplo anterior. `pkgs` é o conjunto de pacotes fornecido pela avaliação. Os imports são relativos ao arquivo que os declara. Um arquivo novo só entra na árvore candidata se estiver versionado como arquivo regular na revisão sincronizada.

## Modificar perfis gráficos

| Perfil | Exemplo de alteração no fork |
| --- | --- |
| [KDE Plasma](desktops/kde.md) | Em [`layout.js`](../core/desktops/kde/layout.js), alterar `top.height` afeta o painel criado pelo modelo quando ainda não existem painéis. Para uma conta já configurada, ajuste o painel pela própria sessão. |
| [GNOME](desktops/gnome.md) | Em [`gnome.nix`](../core/desktops/gnome.nix), trocar `intellihide = true;` por `intellihide = false;` muda a chave administrada do Dash to Dock. |
| [Cinnamon](desktops/cinnamon.md) | Em [`session.nix`](../core/desktops/cinnamon/session.nix), trocar `panels-height = [ "1:42" "2:38" ];` por `[ "1:44" "2:38" ]` muda a altura declarada do painel inferior, identificado por `1`. |
| [LXQt](desktops/lxqt.md) | Em [`panel.conf`](../core/desktops/lxqt/panel.conf), alterar `panelSize=42` na seção `[bottom]` muda a altura inicial do painel inferior. Uma conta com painéis próprios mantém precedência. |

São mudanças no comportamento de um perfil. As propriedades dependem das versões do Plasma, Dash to Dock, Cinnamon e LXQt Panel. Ao atualizar o Nixpkgs, confira os identificadores do modelo, chaves da extensão e nomes das propriedades nos componentes usados pela nova revisão. A [escolha gráfica publicada](configuration.md#escolha-gráfica) continua sujeita à verificação do Noir. Use instalações descartáveis independentes para homologar perfis diferentes.

## Criar um opcional e expor uma preferência

Para tornar ripgrep opcional no fork, use o módulo abaixo em `core/optional/search-tools.nix` no lugar das inclusões incondicionais anteriores. Importe-o na lista de [`noir.nix`](../noir.nix).

```nix
{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.personalConfig.searchTools.enable {
    environment.systemPackages = [ pkgs.ripgrep ];
  };
}
```

Em [`preferences.nix`](../core/config/preferences.nix), adicione `searchTools = mkEnableOption "as ferramentas de busca";` ao submódulo `optionals`. Em [`settings.nix`](../core/config/settings.nix), acrescente `searchTools.enable = readOnly types.bool;` em `options.personalConfig` e `searchTools.enable = values.optionals.searchTools;` em `config.personalConfig`. Acrescente o valor `false` ao [modelo versionado](../settings.example.json). A ausência da chave também mantém o opcional desabilitado, inclusive em JSONs anteriores.

No fork com essas alterações, o objeto abaixo habilita o opcional. O exemplo mantém `desktop` explícito como **Definido pela máquina** e só se aplica a esse caso. Em uma instalação já publicada com outro perfil, preserve o valor existente e acrescente a chave aos opcionais já gravados.

```json
{
  "desktop": null,
  "optionals": {
    "searchTools": true
  }
}
```

Para expor o controle no Dialog, em [`edit-settings.nix`](../core/config/edit-settings.nix) insira `values.optionals.searchTools` na lista de `states`, antes de `codex`. Em `manage_settings` de [`core/install.sh`](../core/install.sh), atualize a declaração das listas e o trecho que serializa a seleção. O restante da função, incluindo a revisão, continua como está.

```bash
# Declaração no início de manage_settings.
local -a names=('CRON' 'Virtualização' 'Ferramentas de busca' 'Codex CLI')
local -a items=() enabled=(false false false false)

# No ramo Opcionais, logo após obter a seleção do Dialog.
for tag in $selection; do
  [[ $tag =~ ^[1-4]$ ]] || die 'Seleção de opcionais inválida.'
  enabled[tag - 1]=true
done
printf -v value '{"cron":%s,"virtualization":%s,"searchTools":%s,"codex":%s}' "${enabled[@]}"
```

A transformação de opcionais em `edit-settings.nix` já combina as mudanças com as chaves existentes. A ordem de `states`, `names`, `enabled` e dos argumentos do `printf` é um detalhe interno compartilhado. Manter Codex no fim preserva a checagem atual de `validate_settings`, que identifica seu estado pelo último item. Se esse formato mudar, revise o produtor dos estados e todos os pontos que os consomem. O menu **Editar preferências** continua sendo um recurso do Dialog.

Teste a preferência ausente, ligada e desligada, a edição dos outros opcionais e a preservação da chave `desktop`. Para um campo de outro tipo, siga o fluxo de wallpaper ou tema Zsh, com schema, consulta ou transformação no editor, controle na interface e mapeamento para um consumidor Nix. Preserve a consulta isolada de desktop e a revisão do diff antes de gravar.

## Remoto e sincronização do fork

Após criar um fork no GitHub, clone-o usando a URL do próprio fork. O Git chama esse remoto de `origin` por padrão. Registre o projeto original sob um nome separado, por exemplo `upstream`.

```bash
git remote add upstream https://github.com/welbersolucoesti/nixos-config.git
git remote -v
git branch -vv
```

O remoto chamado `upstream` é uma convenção do exemplo. O **upstream da branch** é a branch remota que o Git registra como referência de acompanhamento. Se a branch local e a branch do fork se chamarem `main`, o exemplo abaixo configura esse acompanhamento após localizar `origin/main`.

```bash
git fetch origin
git branch --set-upstream-to=origin/main main
git status -sb
```

Para incorporar mudanças do projeto original, consulte `git fetch upstream` e revise e integre as mudanças na branch do fork. Resolva divergências no Git e disponibilize a revisão aprovada no remoto do fork antes de iniciar a publicação.

| Situação após consultar o remoto da branch | Resultado no Noir |
| --- | --- |
| Checkout limpo e no mesmo commit | O Noir pode preparar a publicação. |
| Checkout limpo e apenas atrás | O Noir apresenta e pede confirmação para avançar até a revisão consultada, sem criar um merge. |
| Mudanças locais, commits apenas locais ou históricos divergentes | O Noir bloqueia a publicação. Revise no Git antes de tentar novamente. |

Um checkout limpo tem os arquivos versionados sem alterações pendentes e os arquivos novos fora do índice devidamente versionados ou ignorados. `settings.json` e `config/local.nix` devem permanecer ignorados. O Noir também bloqueia avanços que sobrescreveriam arquivos locais ignorados.

## Validar em ambiente isolado

1. Use um checkout descartável com cópias ilustrativas de [`config/local.example.nix`](../config/local.example.nix) e [`settings.example.json`](../settings.example.json). Crie a conta de teste na configuração da VM e faça `personalConfig.username` corresponder a ela.
2. Verifique sintaxe Bash e Nix e avalie as preferências isoladamente. Por exemplo, na raiz do checkout de teste, o comando abaixo lê o modelo e mostra os valores efetivos.

   ```bash
   nix-instantiate --eval --strict --json core/config/edit-settings.nix \
     --argstr root "$PWD" --argstr file "$PWD/settings.example.json" --argstr attr values
   ```

3. Na VM, use uma configuração de teste com os imports de hardware e do `noir.nix` do checkout descartável. Valide essa configuração com dry-build para detectar opções desconhecidas, conflitos e incompatibilidades. Um módulo pode passar na checagem de sintaxe sem ser alcançado por nenhum import.
4. Para testar o configurador, simule a interface e os comandos que interagem com Git, privilégio e rebuild. Para homologação gráfica, o proprietário usa uma VM com a configuração construída e verifica a sessão conforme a página do perfil. Use uma conta nova para padrões iniciais e outra conta descartável com preferências já existentes para testar a precedência.

### Inspecionar o resultado de um módulo

Com o exemplo do opcional aplicado ao fork descartável, execute o comando abaixo a partir da raiz desse checkout. Ele carrega `noir.nix`, fornece a conta ilustrativa do modelo e verifica se a lista efetiva de pacotes contém ripgrep. Ajuste `usuario` se tiver alterado a identidade de teste. A avaliação temporária usa a versão do Nixpkgs de teste em `system.stateVersion`. Preserve o valor existente na configuração de uma máquina instalada. Use a chave ausente, `false` e `true` no JSON de teste. O resultado esperado é `false`, `false` e `true`, respectivamente, desde que nenhuma outra definição inclua ripgrep.

```bash
nix-instantiate --eval --strict --json --argstr root "$PWD" --expr '
  { root }:
  let
    evaluated = import <nixpkgs/nixos/lib/eval-config.nix> {
      modules = [
        (builtins.toPath (root + "/noir.nix"))
        ({ lib, ... }: {
          users.users.usuario.isNormalUser = true;
          system.stateVersion = lib.trivial.release;
        })
      ];
    };
  in builtins.any (pkg: (pkg.pname or "") == "ripgrep")
    evaluated.config.environment.systemPackages
'
```

Essa inspeção força o valor consultado. A avaliação Nix é preguiçosa e outras partes podem ainda não ter sido avaliadas. Para distinguir falhas após essa etapa, consulte [Avaliação, construção e ativação](recovery.md#avaliação-construção-e-ativação).

[Arquitetura](architecture.md) · [Manutenção](maintenance.md) · [Recuperação](recovery.md)
