# Arquitetura

[Projeto](../README.md) · [Índice](README.md)

O Noir usa o sistema tradicional de módulos do NixOS e o Nixpkgs da máquina, sem Flakes nem Home Manager. O checkout é a área de trabalho e de preparação. A configuração da máquina importa a árvore publicada em `/etc/nixos/nixos-config`.

## Estrutura do repositório

| Caminho | Responsabilidade |
| --- | --- |
| [`noir`](../noir) | Entrada Bash do configurador. Carrega o fluxo compartilhado e chama `main`. |
| [`noir.nix`](../noir.nix) | Ponto de entrada Nix. Importa identidade, preferências, aplicativos, serviços e perfis, e exige identidade completa. |
| [`applications.nix`](../applications.nix) | Lista versionada dos aplicativos comuns e seus imports explícitos. |
| [`config/local.example.nix`](../config/local.example.nix) e [`settings.example.json`](../settings.example.json) | Modelos versionados da identidade e das preferências. Os arquivos locais correspondentes ficam fora do Git. |
| [`core/install.sh`](../core/install.sh) | Pré-requisitos, sincronização Git, configuração local, validações, integração, publicação protegida, backups e rebuild. |
| [`core/lib/`](../core/lib/) | Interface comum e modo texto em `ui.sh`, widgets em `ui-dialog.sh` e tema em `noir.dialogrc`. |
| [`core/config/`](../core/config/) | Declaração da identidade, leitura das preferências e adaptação para o NixOS e o editor. |
| [`core/applications/`](../core/applications/) | Módulos de aplicativos, terminais e lançadores do Noir. |
| [`core/services/`](../core/services/) | Serviços comuns e serviços de libvirt e Podman, condicionados à virtualização. |
| [`core/system/`](../core/system/) | Política de pacotes, fontes, ZRAM e manutenção do Nix. |
| [`core/optional/`](../core/optional/) | Agendamento, composição do conjunto de virtualização, pacote do Codex CLI e adaptação do tema Zsh. |
| [`core/desktops/`](../core/desktops/) | Perfis KDE Plasma, GNOME, Cinnamon e XFCE e seus recursos compartilhados. |
| [`core/wallpapers/`](../core/wallpapers/) | Imagens disponíveis para a preferência declarativa de wallpaper. |

## Fluxo de preferências

1. [`options.nix`](../core/config/options.nix) declara a identidade. A preparação valida `config/local.nix` e a configuração completa verifica se a conta é uma usuária normal do sistema.
2. [`preferences.nix`](../core/config/preferences.nix) lê o objeto JSON, declara tipos e padrões e preserva a distinção entre escolhas gravadas e valores efetivos. A consulta isolada da autoridade gráfica avalia a chave `desktop` sem depender das outras preferências.
3. [`settings.nix`](../core/config/settings.nix) expõe os valores efetivos como opções internas de leitura no NixOS. A imagem selecionada é incorporada ao Nix Store.
4. [`edit-settings.nix`](../core/config/edit-settings.nix) atende às consultas do configurador e gera o JSON candidato. O Bash apresenta a revisão e controla a gravação.

## Fronteiras da publicação

A árvore candidata parte dos arquivos regulares da revisão Git sincronizada. Os arquivos locais ignorados são tratados separadamente. O Noir conserva os imports explícitos e valida a árvore candidata depois da sincronização.

No destino oficial, a etapa protegida recebe a árvore preparada, confere os estados revisados e realiza as trocas da implantação, dos backups e, quando necessário, do import. A integração limita-se à inclusão prevista no [bloco convencional](installation.md#preparar-a-configuração-da-máquina). A composição da máquina, incluindo hardware e conta, continua sob responsabilidade do proprietário.

A trava do checkout serializa a edição e a preparação da publicação. A trava do diretório pai protege as trocas e é compartilhada com os rebuilds do Noir no destino oficial. A [autoridade da escolha gráfica](configuration.md#escolha-gráfica) é o registro publicado. A sincronização do checkout e a configuração inicial do Git global ocorrem depois da publicação.

[Instalação](installation.md) · [Manutenção](maintenance.md) · [Recuperação](recovery.md)
