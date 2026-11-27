# Instalação

[Projeto](../README.md) · [Índice](README.md)

## Pré-requisitos

- NixOS já instalado, com uma conta normal existente e declarada em `users.users`. A primeira instalação deve ser executada pela própria conta escolhida.
- Git, Bash, `nix-instantiate` e Nixpkgs acessível pelo ambiente. Caso falte Git, pode-se abrir uma sessão temporária com `nix-shell -p git`.
- Acesso ao remoto Git. No Dialog, o Noir desabilita os prompts de autenticação do Git no terminal. Prepare o acesso ao remoto antes de iniciar.
- Para o destino oficial, acesso a `sudo`, ferramentas como `setfacl` disponíveis no ambiente do sistema e um diretório `/etc/nixos` sob controle de root. A publicação requer GNU `mv` com `--exchange` e `--no-copy` e um sistema de arquivos que permita a troca.

Os comandos abaixo mostram o caminho e a versão do Nixpkgs da sessão.

```bash
nix-instantiate --find-file nixpkgs
nix-instantiate --eval --strict -E '(import <nixpkgs> {}).lib.version'
```

Em uma máquina com NetworkManager, `nmcli device status` ajuda a verificar a conexão. Se for necessário conectar ao Wi-Fi pelo console, use `nmcli device wifi list` e `nmcli --ask device wifi connect "NOME_DA_REDE"`. A opção `--ask` evita colocar a senha na linha de comando.

## Preparar a configuração da máquina

A publicação oficial usa `/etc/nixos/configuration.nix` e reconhece o bloco convencional gerado pelo NixOS, com apenas o import do hardware ou também o import do Noir, nessa ordem. O exemplo abaixo mostra o bloco integrado.

```nix
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nixos-config/noir.nix
    ];
```

O Noir verifica o formato e os imports efetivos. Se o import do Noir estiver ausente no bloco convencional, prepara e valida a inclusão e apresenta a alteração para revisão antes de publicar. Se já estiver presente no formato aceito, é preservado. Imports adicionais, duplicados, conflitantes ou fora do formato reconhecido bloqueiam a publicação. O administrador deve revisar esses casos, inclusive imports legados de `personal.nix`, preservando o hardware, a conta, a rede, a inicialização e `system.stateVersion`.

Antes de optar por um perfil, confira as declarações de desktop, gerenciador de login, sessão padrão e login automático da máquina. As páginas de [ambientes gráficos](README.md#ambientes-gráficos) indicam os componentes e conflitos de cada perfil.

## Primeira publicação

Na conta escolhida, abra o terminal gráfico ou um console de texto (TTY). O [início rápido](../README.md#início-rápido) mostra como obter o repositório e iniciar o configurador.

1. Selecione **Instalar ou atualizar**. Informe a conta Linux, o nome e o e-mail de autoria Git. Caso já exista um `config/local.nix` no checkout, os dados devem coincidir com os informados. O Noir gera o arquivo na preparação quando ele está ausente.
2. Autorize a consulta ao remoto. Revise e confirme o fast-forward quando houver commits disponíveis. A publicação requer uma branch limpa e alinhada ao upstream consultado.
3. Escolha o ambiente gráfico quando solicitado. Uma escolha explícita em `settings.json` é respeitada, inclusive **Definido pela máquina**. A primeira publicação bem-sucedida consolida essa escolha. Consulte [Escolha gráfica](configuration.md#escolha-gráfica).
4. Revise o import do NixOS, quando houver inclusão, o resumo da publicação e as mudanças de preferências apresentadas. Confirme **Publicar a configuração revisada?** e autentique-se para publicar no destino oficial.
5. O Noir tenta gravar a [identidade Git global](configuration.md#identidade) pela conta escolhida após a primeira publicação. Quando o fluxo oficial termina com sucesso, oferece **Validar agora (dry-build)**. A ativação é uma etapa posterior, sob responsabilidade do proprietário. Consulte [Validação e ativação](maintenance.md#validação-e-ativação).

Em um terminal interativo, o Noir procura o Dialog no `PATH` e, se necessário, tenta carregá-lo com `nix-shell -p dialog`. A interface requer 40 colunas por 12 linhas. Use `./noir --plain` se o Dialog estiver indisponível ou se a autenticação exigir interação direta com o terminal. Fora de um terminal interativo, o Noir usa o modo texto.

Após a ativação, o comando `noir` instalado e os atalhos dos perfis procuram o arquivo executável `~/nixos-config/noir`. Se o checkout estiver em outro local, execute `./noir` a partir dele.

## Destino alternativo

```bash
./noir --destination /CAMINHO/DESTINO
```

Use um destino separado do checkout, fora de `/etc/nixos`, com diretório pai físico e gravável. O fluxo publica sem integração com a configuração da máquina e sem o menu de gerenciamento do sistema. A primeira publicação ainda pode gravar arquivos locais do checkout e aplicar a identidade Git global. Para uma instalação de teste, use checkout e conta descartáveis.

[Configuração](configuration.md) · [Manutenção](maintenance.md)
