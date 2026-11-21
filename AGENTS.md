# Instruções para agentes

## Projeto

Este repositório contém configurações pessoais e declarativas do NixOS para uma estação de desenvolvimento com KDE Plasma e Wayland. Utiliza módulos tradicionais do NixOS e Nixpkgs, sem Flakes ou Home Manager.

- `personal.nix` é o módulo principal reutilizável, importado pelo `/etc/nixos/configuration.nix` da máquina.
- `modules/optional/cron.nix` declara o serviço e o timer systemd para um script privado externo ao repositório. O recurso é habilitado por `personalConfig.cron.enable`.
- `modules/optional/virtualization.nix` declara o suporte a QEMU/KVM e as ferramentas de contêineres. O recurso é habilitado por `personalConfig.virtualization.enable`.
- `modules/optional/zsh-theme.nix` define `personalConfig.zsh.theme`, cuja configuração padrão é `"bira"`. O valor `null` desativa o tema.
- `README.md` documenta o repositório para pessoas que desejem adaptar a configuração aos próprios computadores.
- `.gitignore` contém as regras de arquivos ignorados pelo Git.

## Fonte de verdade

Leia os arquivos relevantes do repositório antes de fazer alterações. Considere o código Nix existente como a fonte de verdade. Se o README divergir de `personal.nix` ou dos módulos em `modules/`, corrija a documentação em vez de presumir que a implementação funciona como descrito. Não invente configurações, versões de pacotes, resultados de execução ou compatibilidade de hardware.

## Regras de edição

- Prefira alterações pequenas, focadas e idiomáticas. Mantenha a configuração simples.
- Não introduza Flakes, Home Manager, um diretório `shells/`, novas ferramentas ou dependências adicionais sem solicitação explícita.
- Mantenha cron e virtualização desativados por padrão. A ativação depende de uma escolha explícita de David na configuração local. O `configuration.nix` da máquina não é gerenciado por este repositório.
- Em tarefas exclusivamente de documentação, edite apenas os arquivos de documentação solicitados. Não altere `personal.nix`, serviços do sistema ou outros arquivos de configuração.
- Nunca adicione nem reproduza senhas, tokens, chaves privadas ou outros segredos. Evite repetir endereços de e-mail pessoais na documentação.
- Não execute `sudo`, atualizações, instalações de pacotes, `git commit` ou `git push` sem solicitação explícita.
- Nunca execute comandos de ativação do NixOS, conforme a seção "Aplicação do sistema".
- Não afirme que verificações foram executadas se elas não foram realmente realizadas.

## Convenções do README

- Escreva em português brasileiro (`pt-BR`), com exemplos práticos e Markdown correto.
- Organize o README para facilitar a leitura: objetivo, pré-requisitos, estrutura do repositório, instalação, recursos, validação, limitações e segurança.
- Descreva fielmente os pacotes e serviços existentes em `personal.nix`, incluindo o JDK Java configurado, editores, PostgreSQL, Zsh, Git, Bluetooth, biometria e keyd, quando presentes. Documente os módulos opcionais sem pressupor que estejam habilitados.
- Diferencie configurações globais do sistema (como `/etc/gitconfig`) de configurações específicas do usuário.
- Explique que as versões dos pacotes dependem da revisão do Nixpkgs e que este repositório não fixa todas as dependências.
- Destaque pressupostos específicos da máquina e etapas de adaptação; não prometa compatibilidade universal.
- Inclua comandos somente quando forem relevantes e coerentes com o repositório.
- Mantenha uma apresentação bem cuidada, mas discreta. Evite excesso de elementos decorativos e afirmações sem fundamento.

## Aplicação do sistema

Agentes podem editar e validar arquivos conforme as tarefas autorizadas.

É terminantemente proibido executar:
- `nixos-rebuild switch`
- `nixos-rebuild boot`
- `nixos-rebuild test`

Essa proibição vale com ou sem `sudo`, mesmo mediante
aprovação genérica para executar comandos.

Somente o proprietário da máquina executa comandos
de ativação da configuração.

## Conclusão das tarefas

Ao concluir cada tarefa, apresente um resumo breve dos arquivos alterados, das decisões importantes e das verificações realmente executadas. Para tarefas exclusivamente de documentação, `git diff --check` é suficiente quando disponível; não reconstrua o sistema operacional apenas para atualizar textos.

## Validação

Para alterações em arquivos `.nix`, execute:

- `git diff --check`
- `git diff --cached --check`
- `nixos-rebuild dry-build`, sem `sudo`

Se o sandbox impedir o acesso ao daemon do Nix,
solicite autorização para executar fora do sandbox.

Para alterações exclusivamente de documentação,
execute as verificações Git aplicáveis.

Informe os resultados reais, inclusive eventuais falhas.

Nenhuma validação autoriza a ativação da configuração.
