# Instruções para agentes

## Projeto e arquitetura

O Noir reúne módulos declarativos do NixOS para KDE Plasma, GNOME, Cinnamon e LXQt, nessa ordem. Utilize módulos tradicionais do NixOS e do Nixpkgs.

- `noir` é a entrada do configurador. `core/install.sh` concentra verificações, sincronização Git, integração, publicação e rebuild. `core/lib/ui.sh` oferece a interface comum e o modo texto, e `core/lib/ui-dialog.sh` fornece os widgets do Dialog. Mantenha as operações no fluxo comum e exponha no menu somente as operações implementadas.
- `noir.nix` é o ponto de entrada Nix. `applications.nix` reúne os aplicativos comuns versionados. Mantenha imports explícitos. A publicação copia os arquivos regulares da revisão Git, sem inventário manual.
- `core/config/options.nix` declara a identidade. `core/config/preferences.nix` lê e valida o JSON. `core/config/settings.nix` adapta as preferências para o NixOS e `core/config/edit-settings.nix` atende ao editor e às consultas do configurador.
- `config/local.nix` guarda a identidade e `settings.json` guarda as preferências. Ambos ficam fora do Git. Os modelos versionados são `config/local.example.nix` e `settings.example.json`.
- A configuração da máquina permanece sob controle do proprietário. Na publicação oficial, o Noir pode incluir `./nixos-config/noir.nix` no bloco convencional de imports de `/etc/nixos/configuration.nix`, após validação e revisão da alteração.
- `core/applications/`, `core/services/`, `core/system/`, `core/desktops/` e `core/optional/` organizam os módulos. Consulte a [arquitetura](docs/architecture.md) para o mapa completo.

Leia os arquivos relevantes antes de alterar o projeto. Para arquitetura, comportamento e opções, use o código Nix, o fluxo Bash e os modelos versionados como fonte de verdade. Se a documentação divergir, corrija o texto segundo o código. Não invente opções, versões, compatibilidade, funcionalidades ou resultados de execução.

## Autoridade e publicação

- Preserve os arquivos locais e a implantação ativa. Na primeira publicação, valide a identidade preparada contra os dados coletados. Na atualização, a identidade efetiva é a do `config/local.nix` publicado.
- A primeira publicação bem-sucedida consolida a escolha gráfica, independentemente da ativação. Antes dela, a ausência de `desktop` solicita seleção e `null` é a escolha explícita **Definido pela máquina**. Depois dela, o `settings.json` publicado é a autoridade. Preserve o bloqueio quando a escolha do checkout for removida ou alterada.
- Preserve a leitura isolada da autoridade gráfica e a validação completa das demais preferências na preparação. Se a escolha estiver ausente na implantação, só aceite evidência em `settings.json` de um backup reconhecido. Rejeite valores fora do esquema e mantenha o bloqueio quando faltar evidência.
- Mantenha as verificações de checkout limpo e sincronizado, as travas, a revisão da integração e as garantias de reversão. Preserve a área de recuperação e os backups quando houver reversão incompleta. A recuperação administrativa excepcional depende de autorização explícita e de evidência da escolha original.
- Mantenha cron, virtualização e Codex CLI desativados por padrão. A habilitação depende de escolha explícita nas preferências locais. O tema Zsh usa `bira` por padrão e `null` o desativa.

## Regras de edição e segurança

- Prefira alterações pequenas, focadas e idiomáticas. Mantenha a configuração simples.
- Não introduza Flakes, Home Manager, um diretório `shells/`, novas ferramentas ou dependências adicionais sem solicitação explícita.
- Em tarefas exclusivamente documentais, edite apenas os arquivos de documentação autorizados. Preserve código-fonte, serviços, arquivos Nix, configurações da máquina, implantação e arquivos pessoais.
- Nunca adicione nem reproduza senhas, tokens, chaves privadas ou outros segredos. Evite repetir endereços de e-mail pessoais na documentação.
- Não execute `sudo`, atualizações, instalações de pacotes, publicação, recuperação administrativa, `git commit` ou `git push` sem solicitação explícita. A proibição de ativação vale em qualquer caso.

## Aplicação do sistema

Agentes podem editar e validar arquivos conforme as tarefas autorizadas. A execução dos comandos abaixo por agentes é terminantemente proibida.

- `nixos-rebuild switch`
- `nixos-rebuild boot`
- `nixos-rebuild test`

A proibição vale com ou sem `sudo`, por alias, script ou interface, mesmo mediante aprovação genérica. Somente o proprietário da máquina executa comandos de ativação. A confirmação interativa do Noir depois do dry-build só autoriza a ativação quando respondida pelo proprietário. Agentes jamais selecionam uma ativação real no Noir. Nenhuma validação autoriza ativar o sistema.

## Testes itinerantes e validação

- Para alterações em arquivos `.nix`, execute `git diff --check`, `git diff --cached --check` e `nixos-rebuild dry-build` sem `sudo`. Se o sandbox impedir acesso ao daemon do Nix, solicite autorização para executar fora do sandbox.
- Para alterações exclusivamente documentais, execute as verificações Git aplicáveis. `git diff --check` é suficiente quando disponível. A revisão de texto dispensa rebuild.
- Para alterações no configurador, execute `bash -n` nos scripts Bash alterados. Teste as interações com comandos simulados ou lógica isolada. Use casos e artefatos temporários para os testes itinerantes e remova-os ao concluir. Mantenha a publicação real, a ativação, a implantação ativa e os arquivos pessoais fora dos testes.
- Informe as verificações realmente executadas, inclusive falhas e limitações.

## Convenções documentais e entrega

- Escreva em pt-BR, em Markdown válido, com exemplos relevantes e links relativos entre páginas. Mantenha o [README público](README.md) conciso e o [índice da documentação](docs/README.md) atualizado. Preserve a ordem KDE Plasma, GNOME, Cinnamon e LXQt.
- Descreva fielmente pacotes e serviços, incluindo o JDK configurado, editores, PostgreSQL, Zsh, Git, Bluetooth, biometria e keyd, quando presentes. Documente os opcionais como escolhas. Explique a aplicação única da identidade Git global pela própria conta após a primeira publicação protegida e a precedência da configuração de cada repositório.
- Explique que as versões dependem da revisão do Nixpkgs e que existem dependências sem revisão fixada no projeto. Registre pressupostos específicos da máquina, etapas de adaptação e limites de homologação, sem prometer compatibilidade universal.
- Ao concluir, resuma os arquivos alterados, as decisões importantes e as verificações feitas.
