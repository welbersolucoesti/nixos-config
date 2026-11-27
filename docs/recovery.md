# Diagnóstico e recuperação

[Projeto](../README.md) · [Índice](README.md)

## Diagnóstico inicial

No Dialog, use **Registros** na tela de resultado. Os rebuilds também gravam a saída em `${XDG_STATE_HOME:-$HOME/.local/state}/noir/rebuilds/`. O resumo indica o arquivo quando o rebuild chega a criar um registro.

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

O Noir reconhece implantações legadas com `personal.nix` e pode obter a escolha explícita de `config/local.nix`. Também consulta `.previous` quando a leitura da implantação indica ausência da escolha. Um JSON inválido interrompe a leitura. A remoção automática do desktop legado é restrita à declaração literal no início de `personalConfig`, no formato emitido pelo instalador anterior. Imports antigos na configuração da máquina ainda precisam de revisão conforme [Preparar a configuração da máquina](installation.md#preparar-a-configuração-da-máquina). Se a fonte da escolha for legada ou vier do backup, publique a escolha recuperada no JSON da implantação atual antes de usar o rebuild do Noir.

Se a implantação existe e nenhuma cópia confiável registra a escolha, o Noir bloqueia a operação. A recuperação administrativa excepcional exige evidência da escolha original, como um registro confiável ou confirmação expressa do proprietário. A sessão em execução, por si só, pode pertencer a outra geração. Com o Noir fechado, preserve o JSON publicado em um backup administrativo separado de `.previous`, restaure somente a chave original por substituição atômica, preserve as demais preferências, o proprietário e as permissões, e sincronize o checkout. Mantenha `.previous` intacto. Valide a opção de desktop e, quando aplicável, o gerenciador de login na configuração resultante. Faça um dry-build antes de decidir qualquer ação sobre o sistema.

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

## Ativação interrompida

Uma falha no `switch` pode ocorrer depois da construção ou da mudança do perfil, com o sistema anterior ainda em execução. Compare o sistema ativo, o perfil e a entrada que o carregador configurou para o próximo boot. Uma entrada existente no menu, por si só, não indica a entrada padrão.

```bash
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
```

Confira o registro do Noir e, conforme a falha, o journal da máquina. O proprietário decide qualquer ação posterior a partir desse estado.

## Gerações do NixOS

Os backups da implantação guardam os arquivos avaliados pelo NixOS. As gerações guardam sistemas já construídos. O proprietário pode selecionar uma geração ainda disponível no menu de inicialização. A disponibilidade das gerações depende da retenção local e da [manutenção do Nix](maintenance.md#manutenção-do-nix).

[Configuração](configuration.md) · [Manutenção](maintenance.md)
