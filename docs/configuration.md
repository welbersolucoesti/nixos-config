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
| `desktop` | `"kde"`, `"gnome"`, `"cinnamon"`, `"lxqt"` ou `null`. O modelo omite a chave para permitir a seleção inicial. |
| `wallpaper` | Nome de um arquivo regular em [`core/wallpapers/`](../core/wallpapers/). O padrão é `nixos-001.png`. |
| `optionals.cron` | Booleano, com padrão `false`. |
| `optionals.virtualization` | Booleano, com padrão `false`. |
| `optionals.codex` | Booleano, com padrão `false`. |
| `zsh.theme` | Nome do tema Oh My Zsh ou `null`. A ausência da chave usa `"bira"`. Com `null`, o tema fica desativado e os demais recursos do Zsh continuam disponíveis. |

No Dialog, **Editar preferências** oferece **Wallpaper**, **Opcionais** e **Tema Zsh**. Deixar o campo **Wallpaper** vazio remove a seleção e volta ao papel de parede padrão. O campo de tema vazio grava `null`. Na lista de opcionais, use `Espaço` para marcar ou desmarcar **CRON**, **Virtualização** e **Codex CLI**. O Noir valida a edição, apresenta as diferenças e pede confirmação antes de gravar no checkout. Use **Instalar ou atualizar** para publicar e [aplique a configuração](maintenance.md#validação-e-ativação) para levar os efeitos ao sistema. Consulte os requisitos dos [módulos opcionais](applications.md#módulos-opcionais).

Para editar manualmente, use o modelo como referência para as chaves e os tipos do JSON. Mantenha o valor de `desktop` já publicado e preserve as demais chaves do checkout. As opções derivadas do JSON são de leitura no NixOS. Em uma configuração antiga, revise definições de tema e opcionais em `local.nix` e registre as preferências correspondentes no JSON.

Por exemplo, este JSON habilita virtualização e desativa o tema Zsh em uma instalação que escolheu **Definido pela máquina**. Se houver outras preferências, integre apenas `optionals.virtualization` e `zsh.theme` ao arquivo existente. Use sempre o valor de `desktop` da própria instalação.

```json
{
  "desktop": null,
  "optionals": {
    "virtualization": true
  },
  "zsh": {
    "theme": null
  }
}
```

## Preferências da sessão

As escolhas em `settings.json` pertencem ao Noir. Aplicativos e ambientes gráficos também podem armazenar preferências no diretório pessoal da conta.

| Tipo | Efeito |
| --- | --- |
| Editável pela conta | A interface do aplicativo grava a escolha pessoal quando a chave admite alteração. |
| Padrão inicial | O perfil fornece um valor ou layout para contas que ainda não têm estado correspondente. |
| Valor bloqueado | A chave gerenciada prevalece durante a sessão, como em configurações dconf com bloqueio ativo. |
| Configuração reaplicada | Uma rotina de sessão volta a configurar o valor em um momento definido, como o papel de parede no início do Plasma ou a lista de atalhos personalizados no login do GNOME. |

As páginas dos [perfis](README.md#ambientes-gráficos) descrevem exemplos dessas diferenças. Para mudar o que um perfil define ou reaplica, consulte [personalização do fork](customization.md#modificar-perfis-gráficos).

## Escolha gráfica

| Estado | Efeito |
| --- | --- |
| Arquivo ausente ou objeto válido sem `desktop`, como `{}` | Na primeira publicação, o Noir solicita a escolha. A avaliação Nix isolada resolve a opção ausente para `null`. |
| `"desktop": null` | Escolha explícita **Definido pela máquina**. Os módulos comuns continuam disponíveis e a configuração da máquina é responsável pelo desktop e pelo login. |
| `desktop` com um perfil explícito | O Noir respeita a seleção. A lista oferece KDE Plasma, GNOME, Cinnamon e LXQt nessa ordem. |
| `desktop` com um valor fora do esquema | A leitura falha. |
| Arquivo com zero bytes ou JSON inválido | A leitura falha. |

A primeira publicação bem-sucedida consolida a escolha, independentemente do dry-build ou da ativação. Em uma implantação atual com escolha explícita, o JSON publicado é a autoridade. O editor exibe o desktop para consulta. Se a chave for removida do checkout ou seu valor divergir do publicado, o Noir bloqueia a edição, a publicação e o rebuild. Essa regra inclui o valor `null`.

Uma escolha ausente ou divergente na implantação pode exigir [recuperação](recovery.md#escolha-gráfica-ausente-ou-divergente). Caso a publicação tenha sido concluída e a sincronização local tenha falhado, confira [Preferências locais após publicação](recovery.md#preferências-locais-após-publicação).

[Instalação](installation.md) · [Manutenção](maintenance.md)
