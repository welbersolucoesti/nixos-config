# Diagnóstico e recuperação

[Projeto](../README.md) · [Índice](README.md)

## Diagnóstico por sintomas

No Dialog, use **Registros** na tela de resultado. Os rebuilds também gravam a saída em `${XDG_STATE_HOME:-$HOME/.local/state}/noir/rebuilds/`. O resumo indica o arquivo quando o rebuild chega a criar um registro.

| Sintoma | Primeiro ponto a conferir |
| --- | --- |
| O Noir não abre em Dialog | Confirme que o terminal está em modo interativo e tem espaço suficiente. Use `./noir --plain` conforme [Obter e abrir o Noir](installation.md#obter-e-abrir-o-noir). |
| O atalho ou a entrada de menu do Noir não abre | Confirme se `~/nixos-config/noir` existe e é executável. Para um checkout em outro local, abra `./noir` nesse diretório. |
| O checkout está sujo, adiantado ou divergente | Confira o [estado do Git](#estado-do-git) e a [sincronização do fork](customization.md#remoto-e-sincronização-do-fork). |
| O bloco de imports foi rejeitado | Compare a configuração da máquina com o [bloco reconhecido](installation.md#preparar-a-configuração-da-máquina). |
| Há erro de leitura de `config/local.nix` | Confira as [permissões da implantação](#permissões-da-implantação). |
| A publicação falhou ou há `.nixos-config.*` pendente | Examine [Backups e reversão da publicação](#backups-e-reversão-da-publicação). |
| O desktop está ausente ou diverge | Consulte [Escolha gráfica ausente ou divergente](#escolha-gráfica-ausente-ou-divergente). |
| A publicação terminou e há uma etapa local pendente | Confira [Preferências locais](#preferências-locais-após-publicação) ou [Identidade Git](#identidade-git-após-publicação), conforme o resumo. |
| O dry-build falhou | Comece pela mensagem e pelo [registro da validação](#falha-no-dry-build). |
| A avaliação passou e a construção falhou | Consulte [Avaliação, construção e ativação](#avaliação-construção-e-ativação) para identificar a derivação e os registros. |
| O terminal fechou no switch ou a sessão esperada não aparece | Confira [Ativação interrompida](#ativação-interrompida), o perfil escolhido e as declarações de login da máquina. |

## Estado do Git

No checkout, `git status` e `git diff` mostram mudanças locais. O comando abaixo mostra os commits exclusivos de cada lado em relação ao upstream já consultado.

```bash
git log --oneline --left-right HEAD...@{upstream}
```

## Permissões da implantação

Na primeira publicação protegida, o `config/local.nix` publicado fica sob controle de root e recebe uma ACL que concede leitura ao UID que publicou. Atualizações preservam as permissões desse arquivo. Se uma implantação anterior tiver modo `0600` sem ACL e essa for a causa do erro de leitura, o administrador pode executar o comando abaixo a partir da conta autorizada a ler o arquivo.

```bash
sudo setfacl -m "u:$(id -u):r--" -- /etc/nixos/nixos-config/config/local.nix
```

Mantenha as configurações importadas protegidas contra escrita por contas não autorizadas. Senhas, tokens e chaves privadas devem ficar fora do Git e do Nix Store. Arquivos Nix e valores usados durante a avaliação podem aparecer no Store ou em arquivos gerados. Serviços que necessitam de segredos devem lê-los em tempo de execução a partir de caminhos com acesso restrito.

## Backups e reversão da publicação

Uma troca bem-sucedida guarda a implantação anterior em `/etc/nixos/nixos-config.previous`, substituindo a cópia anterior desse caminho. Quando a publicação inclui o import, o Noir salva também o `configuration.nix` original em um arquivo `configuration.nix.noir.*.previous` no mesmo diretório. Uma atualização com a mesma árvore dispensa a troca da implantação.

Se uma etapa da publicação falhar após uma troca, o Noir tenta desfazer, em ordem inversa, as mudanças na árvore, no import e nos backups. Se uma restauração for bloqueada, as etapas restantes são interrompidas para preservar os arquivos dos quais o estado atual pode depender. O resultado informa os caminhos preservados. Uma área `.nixos-config.*` pendente bloqueia novas operações do Noir que dependem da implantação.

Com o Noir fechado, o administrador deve conferir a implantação, a cópia anterior, o arquivo da máquina e os caminhos informados antes de restaurar qualquer arquivo. O import e a árvore restaurados precisam corresponder, especialmente se a cópia anterior tiver outro ponto de entrada. Preserve os originais, a área de recuperação e as edições locais. Depois de restabelecer uma combinação coerente, faça um dry-build. Restaurar arquivos altera a entrada da próxima avaliação. Para iniciar um sistema já construído, consulte [Gerações do NixOS](#gerações-do-nixos).

## Escolha gráfica ausente ou divergente

Em uma implantação atual com escolha explícita, recupere o valor publicado no checkout conforme [Preferências locais após publicação](#preferências-locais-após-publicação). Preserve a distinção entre uma chave ausente e o valor explícito `null`.

Quando a implantação tem `noir.nix` e a escolha está ausente, o Noir pode consultar o `settings.json` do backup reconhecido em `.previous`. Um JSON inválido ou um valor gráfico fora do esquema interrompe a operação antes da consulta ao backup. Se a escolha válida vier do backup, publique a escolha recuperada no JSON da implantação atual antes de usar o rebuild do Noir.

O configurador exige um `noir.nix` regular na árvore da implantação e no backup consultado. Implantações de formato anterior são rejeitadas.

Se a implantação existe e nenhuma cópia confiável registra uma escolha suportada, o Noir bloqueia a operação. A recuperação administrativa excepcional exige evidência da escolha original, como um registro confiável ou confirmação expressa do proprietário. A sessão em execução, por si só, pode pertencer a outra geração. Com o Noir fechado, preserve o JSON publicado em um backup administrativo separado de `.previous`, restaure somente a chave original por substituição atômica, preserve as demais preferências, o proprietário e as permissões, e sincronize o checkout. Mantenha `.previous` intacto. Valide a opção de desktop e, quando aplicável, o gerenciador de login na configuração resultante. Faça um dry-build antes de decidir qualquer ação sobre o sistema.

## Preferências locais após publicação

Uma falha ao gravar o checkout depois da publicação preserva a escolha da implantação. Se o checkout estiver sem `settings.json`, copie o JSON publicado para o checkout. Se o arquivo já existir, copie apenas o valor de `desktop`, preservando as demais chaves. Confira a igualdade dos valores, inclusive quando a escolha for `null`, antes de retomar o fluxo.

## Identidade Git após publicação

Se o ajuste do Git falhar depois da publicação, os arquivos continuam implantados. Pela conta escolhida, use o comando abaixo para conferir as entradas globais e seus arquivos de origem.

```bash
git config --includes --show-origin --show-scope --get-regexp '^(user\.(name|email)|init\.defaultbranch)$'
```

Corrija permissões ou definições duplicadas no arquivo de origem. Dos comandos abaixo, execute apenas os ajustes pendentes com os dados da conta.

```bash
git config --global user.name "NOME"
git config --global user.email "EMAIL"
git config --global init.defaultBranch main
```

## Falha no dry-build

Se a falha ocorrer antes de criar um registro, use a mensagem do Noir. Um arquivo ilegível, uma trava de outra operação ou uma escolha gráfica divergente são verificações anteriores ao Nix. Se a avaliação chegou a iniciar, leia o primeiro erro relevante no registro. Uma opção desconhecida pode indicar incompatibilidade com a revisão do Nixpkgs. Um conflito entre módulos pode apontar para um desktop ou gerenciador de login já definido pela máquina. Corrija a origem da definição, publique novamente se os arquivos do Noir precisarem mudar e repita a validação.

## Avaliação, construção e ativação

| Etapa | Indício no registro | Próximo passo |
| --- | --- | --- |
| Avaliação | Opção desconhecida, tipo incorreto, import ausente ou conflito de definições. | Identifique a opção e o módulo indicados. Confira se a revisão do Nixpkgs é a esperada e se o módulo consta dos imports. |
| Construção | Erro ao obter uma dependência ou falha de uma derivação identificada por um caminho `.drv`. | Leia a primeira falha do construtor ou do download. Quando houver um caminho de derivação e o recurso estiver disponível, `nix log /nix/store/…-pacote.drv` consulta o registro correspondente. |
| Ativação | A construção terminou e uma unidade ou ação de aplicação falhou. | Use o registro do rebuild e o journal para identificar a unidade. Antes de repetir, compare o sistema ativo, o perfil e o próximo boot. |

No perfil LXQt, o valor publicado é `"lxqt"` e a sessão esperada no SDDM é **LXQt (Wayland)**. Para falhas de portal, painel, bloqueador ou KCM, consulte o [diagnóstico do perfil LXQt](desktops/lxqt.md#diagnóstico).

## Ativação interrompida

Uma falha no `switch` pode ocorrer depois da construção ou da mudança do perfil, com o sistema anterior ainda em execução. Compare o sistema ativo, o perfil e a entrada que o carregador configurou para o próximo boot. Uma entrada existente no menu, por si só, não indica a entrada padrão.

```bash
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
```

Confira o registro do Noir e, conforme a falha, o journal da máquina. O proprietário decide qualquer ação posterior a partir desse estado.

Se a tela de login não aparecer, use um [TTY disponível](installation.md#acessar-um-tty). O comando `systemctl status display-manager.service` ajuda a verificar se o serviço iniciou. A ausência da sessão esperada também pode vir da escolha **Definido pela máquina** ou de declarações de login incompatíveis.

## Gerações do NixOS

Os backups da implantação guardam os arquivos avaliados pelo NixOS. As gerações guardam sistemas já construídos. O proprietário pode selecionar uma geração ainda disponível no menu de inicialização. A disponibilidade das gerações depende da retenção local e da [manutenção do Nix](maintenance.md#manutenção-do-nix).

Ao voltar a uma geração anterior, a máquina pode continuar com arquivos locais e dados de serviços alterados depois daquela geração. Para recuperar esses dados, use os backups correspondentes. Consulte [Gerações, rollback e dados](concepts.md#gerações-rollback-e-dados).

[Configuração](configuration.md) · [Manutenção](maintenance.md)
