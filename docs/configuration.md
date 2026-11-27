# Configuração

[Projeto](../README.md) · [Índice](README.md)

## Identidade

`config/local.nix` guarda `personalConfig.username`, `personalConfig.git.userName` e `personalConfig.git.userEmail`. Use [o modelo versionado](../config/local.example.nix) como referência. A conta deve ser normal e estar declarada no NixOS. O Noir valida o arquivo preparado na primeira publicação e preserva a identidade publicada nas atualizações.

Após a primeira publicação, o Noir executa `git config --global` na própria conta escolhida para registrar `user.name`, `user.email` e `init.defaultBranch = main`. A operação preserva as demais preferências globais. O arquivo de destino é `~/.gitconfig` ou, se ele estiver ausente e já houver um arquivo XDG aplicável, a configuração global em `${XDG_CONFIG_HOME:-$HOME/.config}/git/config`. O Noir verifica os caminhos e rejeita redirecionamentos do ambiente e definições conflitantes dessas chaves.

Para alterar a autoria de commits depois da primeira publicação, use a configuração do Git. A configuração de um repositório específico tem precedência sobre a global. Em caso de falha na configuração inicial, consulte [Identidade Git após publicação](recovery.md#identidade-git-após-publicação).

## Preferências

`settings.json` é um objeto JSON local, ignorado pelo Git assim como `config/local.nix`. O [modelo versionado](../settings.example.json) mostra os padrões. As escolhas do checkout são preparadas para publicação. O NixOS avalia as preferências da árvore publicada.

| Chave | Valores e padrão |
| --- | --- |
| `desktop` | `"kde"`, `"gnome"`, `"cinnamon"`, `"xfce"` ou `null`. O modelo omite a chave para permitir a seleção inicial. |
| `wallpaper` | Nome de um arquivo regular em [`core/wallpapers/`](../core/wallpapers/). O padrão é `nixos-001.png`. |
| `optionals.cron` | Booleano, com padrão `false`. |
| `optionals.virtualization` | Booleano, com padrão `false`. |
| `optionals.codex` | Booleano, com padrão `false`. |
| `zsh.theme` | Nome do tema Oh My Zsh ou `null`. A ausência da chave usa `"bira"`. Com `null`, o tema fica desativado e os demais recursos do Zsh continuam disponíveis. |

No Dialog, **Editar preferências** oferece **Wallpaper**, **Opcionais** e **Tema Zsh**. O campo de wallpaper vazio remove a seleção e volta ao padrão. O campo de tema vazio grava `null`. Na lista de opcionais, use Espaço para marcar ou desmarcar **CRON**, **Virtualização** e **Codex CLI**. O Noir valida a edição, apresenta o diff e pede confirmação antes de gravar no checkout. As mudanças chegam à implantação pelo fluxo **Instalar ou atualizar**. Consulte os requisitos e efeitos dos [módulos opcionais](applications.md#módulos-opcionais).

Para editar manualmente, use o modelo como referência para as chaves e os tipos do JSON. Mantenha o valor de `desktop` já publicado e preserve as demais chaves do checkout. As opções derivadas do JSON são de leitura no NixOS. Em uma configuração antiga, revise definições de tema e opcionais em `local.nix` e registre as preferências correspondentes no JSON.

## Escolha gráfica

| Estado | Efeito |
| --- | --- |
| Arquivo ausente ou objeto válido sem `desktop`, como `{}` | Na primeira publicação, o Noir solicita a escolha. A avaliação Nix isolada resolve a opção ausente para `null`. |
| `"desktop": null` | Escolha explícita **Definido pela máquina**. Os módulos comuns continuam disponíveis e a configuração da máquina é responsável pelo desktop e pelo login. |
| `desktop` com um perfil explícito | O Noir respeita a seleção. A lista oferece KDE Plasma, GNOME, Cinnamon e XFCE nessa ordem. |
| Arquivo com zero bytes ou JSON inválido | A leitura falha. |

A primeira publicação bem-sucedida consolida a escolha, independentemente do dry-build ou da ativação. Em uma implantação atual com escolha explícita, o JSON publicado é a autoridade. O editor exibe o desktop para consulta. Se a chave for removida do checkout ou seu valor divergir do publicado, o Noir bloqueia a edição, a publicação e o rebuild. Essa regra inclui o valor `null`.

Uma implantação antiga pode exigir [migração ou recuperação](recovery.md#escolha-gráfica-ausente-ou-divergente). Caso a publicação tenha sido concluída e a sincronização local tenha falhado, confira [Preferências locais após publicação](recovery.md#preferências-locais-após-publicação).

[Instalação](installation.md) · [Manutenção](maintenance.md)
