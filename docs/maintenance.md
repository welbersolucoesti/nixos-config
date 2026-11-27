# Manutenção

[Projeto](../README.md) · [Índice](README.md)

Atualizar o Noir altera os módulos e recursos do repositório. Atualizar o Nixpkgs altera os pacotes e as opções de módulos usados ao avaliar o sistema. São operações independentes. Consulte [Conceitos](concepts.md#o-que-o-noir-acrescenta) para os efeitos sobre as versões e a reprodutibilidade.

## Atualização e publicação

Execute `./noir` pela conta normal e selecione **Instalar ou atualizar**. Use **Editar preferências** no Dialog antes de iniciar se houver mudanças locais a publicar.

1. Autorize a consulta ao remoto configurado. O Noir busca os commits e apresenta as diferenças. Se houver um avanço possível, confirme o fast-forward para o commit apresentado. Mudanças locais não commitadas, commits somente locais e branches divergentes bloqueiam a publicação.
2. Revise a preparação. A árvore candidata vem da revisão sincronizada do Git, incluindo `applications.nix`. A identidade vem da implantação existente. O Noir prepara `settings.json` separadamente e confere a escolha gráfica contra a autoridade publicada. A preparação verifica a sintaxe dos módulos e as preferências. A avaliação completa da máquina ocorre no dry-build.
3. Confirme a publicação. No destino oficial, a operação protegida usa `sudo`. No Dialog, o campo oculto é exibido após a confirmação e a senha só é enviada quando o `sudo` solicita autenticação. No modo texto, a autenticação ocorre no terminal.
4. Se houver troca da árvore implantada, a anterior passa a ser `/etc/nixos/nixos-config.previous`. Quando o Noir inclui o import, também guarda o `configuration.nix` original no caminho informado no resultado. Consulte [Backups e reversão da publicação](recovery.md#backups-e-reversão-da-publicação).

## Validação e ativação

No destino oficial, **Gerenciar sistema** oferece **Validar configuração (dry-build)** e **Aplicar configuração (switch)**. O dry-build avalia a configuração da máquina e planeja a construção a partir da cópia publicada. Execute-o pela conta normal. O Noir verifica a correspondência da chave `desktop` com o checkout, mantém a trava compartilhada com a publicação protegida e usa o canal de sistema do root quando o caminho resolve para o Nix Store.

O comando abaixo avalia diretamente a configuração publicada em uma sessão com o Nixpkgs apropriado.

```bash
nixos-rebuild dry-build --no-flake -I nixos-config=/etc/nixos/configuration.nix
```

A invocação direta usa o ambiente Nix da sessão e avalia a configuração sem as verificações adicionais do Noir. A avaliação pode exigir acesso de leitura ao arquivo de identidade publicado. Consulte [Permissões da implantação](recovery.md#permissões-da-implantação).

O resultado de um dry-build pode listar saídas que seriam construídas ou baixadas. Um resultado bem-sucedido confirma a avaliação e o planejamento. Falhas durante a construção real, a ativação ou o login ainda são possíveis. `nixos-rebuild build` materializa a configuração sem ativá-la quando for necessário testar também a construção em um ambiente apropriado.

Somente o proprietário confirma **Aplicar configuração agora?**. O fluxo exige terminal interativo e executa um novo dry-build antes de pedir confirmação, inclusive após uma validação avulsa. O Dialog solicita a senha sob demanda. No modo texto, o `sudo` autentica no terminal.

O `switch` pode reiniciar o gerenciador de login e derrubar a sessão gráfica. A operação atual depende do terminal que a iniciou. Quando houver possibilidade de interrupção da sessão gráfica, o proprietário pode iniciar o Noir em um [TTY](installation.md#acessar-um-tty). Em caso de interrupção, confira o [registro e o estado do sistema](recovery.md#ativação-interrompida) antes de repetir a operação.

## Atualizar o Nixpkgs

Identifique primeiro de onde vem o Nixpkgs usado pelo sistema. `nix-instantiate --find-file nixpkgs` mostra a resolução na conta atual. O Noir usa o canal `nixos` de root no rebuild quando `/nix/var/nix/profiles/per-user/root/channels/nixos` resolve para um caminho do Nix Store. A resolução da conta e a do rebuild podem apontar para revisões diferentes.

Se o sistema é gerenciado por canais, `nix-update` atualiza os canais de root depois de o alias do Noir estar disponível. Em instalações que fixam ou fornecem o Nixpkgs por outro caminho, atualize a origem adotada pela máquina. A mudança de origem só afeta os aplicativos em execução depois de construir e aplicar a configuração. Preserve `system.stateVersion`, que trata da compatibilidade de estado dos serviços, e faça um dry-build antes de aplicar. [Atualização do NixOS](https://nixos.org/manual/nixos/stable/#sec-upgrading)

## Manutenção do Nix

O Noir declara coleta semanal de objetos sem referências e remoção de gerações elegíveis com mais de 60 dias. Gerações removidas deixam de estar disponíveis para retorno. Perfis e outras raízes do Nix mantêm os objetos referenciados.

| Alias | Operação |
| --- | --- |
| `nix-update` | Atualiza os canais do root. |
| `nix-check` | Avalia e planeja a construção com dry-build. |
| `nix-system-build` | Constrói a configuração sem ativar. |
| `nix-switch` | Executa `sudo nixos-rebuild switch`. Uso exclusivo do proprietário. |
| `nix-generations` | Lista as gerações do perfil de sistema. |
| `nix-diff ORIGEM DESTINO` | Compara dois caminhos de sistema existentes. |

`nix-store --gc --print-dead` lista os objetos elegíveis à coleta. As versões dos pacotes comuns dependem da revisão do Nixpkgs disponível na máquina. Se a avaliação e a ativação encontrarem versões diferentes, confira o `NIX_PATH` e os canais da conta e do root na instalação.

[Configuração](configuration.md) · [Diagnóstico e recuperação](recovery.md)
