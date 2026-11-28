# Instalação

[Projeto](../README.md) · [Índice](README.md)

O Noir acrescenta módulos a um NixOS já instalado. Se a máquina ainda não inicia em NixOS, comece pela instalação base. [Manual de instalação do NixOS](https://nixos.org/manual/nixos/stable/#sec-installation)

## Pré-requisitos

- NixOS já instalado, com uma conta normal existente e declarada em `users.users`. A primeira instalação deve ser executada pela própria conta escolhida.
- Git, Bash, `nix-instantiate` e acesso ao **Nixpkgs**, a coleção de pacotes e módulos usada na avaliação. Caso falte Git, abra uma sessão temporária com `nix-shell -p git`.
- Acesso ao **remoto Git**, o repositório de onde o Noir consulta as revisões. Na interface Dialog, prepare as credenciais antes de iniciar, pois os prompts do Git no terminal ficam desabilitados.
- Para a **publicação** no destino oficial, acesso a `sudo`, a ferramentas de sistema como `setfacl` e a um diretório `/etc/nixos` sob controle de `root`. Publicar é colocar a cópia revisada em `/etc/nixos/nixos-config` para a próxima avaliação do sistema. O GNU `mv` deve oferecer `--exchange` e `--no-copy`, e o sistema de arquivos deve permitir a troca dos diretórios sem cópia.

Os comandos abaixo mostram o caminho e a versão do Nixpkgs da sessão.

```bash
nix-instantiate --find-file nixpkgs
nix-instantiate --eval --strict -E '(import <nixpkgs> {}).lib.version'
```

Em uma máquina com NetworkManager, `nmcli device status` ajuda a verificar a conexão. Se for necessário conectar ao Wi-Fi pelo console, use `nmcli device wifi list` e `nmcli --ask device wifi connect "NOME_DA_REDE"`. A opção `--ask` evita colocar a senha na linha de comando.

## Preparar a configuração da máquina

Confirme que a instalação base inicia e que a conta escolhida consegue entrar, acessar a rede e usar `sudo`. A configuração da máquina continua responsável pelo hardware, pelos discos, pela rede e pelo carregador de inicialização. Preserve `system.stateVersion`, que mantém padrões de compatibilidade de serviços com o estado da instalação.

O NixOS combina suas declarações em **módulos**, arquivos que podem incluir outros módulos por meio da lista `imports`. A publicação oficial reconhece em `/etc/nixos/configuration.nix` o bloco convencional gerado pelo NixOS, com apenas o import do hardware ou também o import do Noir, nessa ordem. O exemplo abaixo mostra o bloco integrado.

```nix
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nixos-config/noir.nix
    ];
```

O Noir verifica o formato e os imports efetivos. Se o import do Noir estiver ausente no bloco convencional, prepara e valida a inclusão e apresenta a alteração para revisão antes de publicar. Se já estiver presente no formato aceito, é preservado. Imports adicionais, duplicados, conflitantes ou fora do formato reconhecido bloqueiam a publicação. O administrador deve revisar esses casos, preservando o hardware, a conta, a rede, a inicialização e `system.stateVersion`.

## Escolher o ambiente gráfico

Compare as sessões antes de publicar. O **gerenciador de login** é o serviço que apresenta a tela de entrada e inicia a sessão gráfica. Wayland e X11 são protocolos usados para exibir janelas e lidar com a entrada da sessão.

| Escolha | O que o Noir configura |
| --- | --- |
| [KDE Plasma](desktops/kde.md) | Plasma 6, com Wayland quando disponível, SDDM e dois painéis flutuantes. |
| [GNOME](desktops/gnome.md) | GNOME em Wayland, GDM e extensões de dock, bandeja e área de transferência. |
| [Cinnamon](desktops/cinnamon.md) | Sessão X11, LightDM com Slick Greeter e dois painéis com tarefas agrupadas. |
| [LXQt](desktops/lxqt.md) | Sessão LXQt Wayland com KWin e SDDM. O XWayland atende aplicativos X11. |
| **Definido pela máquina** | Módulos comuns do Noir. A máquina continua responsável pela sessão gráfica ou pelo uso somente em console. |

Para um perfil Noir, confira se a instalação base já declara outro desktop, gerenciador de login, sessão padrão ou login automático. Resolva as configurações incompatíveis à luz da página do perfil antes da validação. A [escolha gráfica](configuration.md#escolha-gráfica) fica consolidada na primeira publicação bem-sucedida, mesmo que a ativação seja adiada.

## Obter e abrir o Noir

Siga o [início rápido](../README.md#início-rápido) a partir do diretório pessoal da conta selecionada. O `git clone` cria o **checkout**, a cópia local do repositório. Entre nele e execute `./noir` pela conta normal. O menu deve oferecer **Instalar ou atualizar**. Em terminal interativo, o Noir procura o Dialog no `PATH` e, se necessário, tenta carregá-lo com `nix-shell -p dialog`. A interface requer 40 colunas por 12 linhas. Use `./noir --plain` se o Dialog estiver indisponível ou se precisar autenticar diretamente no terminal. Fora de um terminal interativo, o Noir usa o modo texto.

## Primeira publicação

A publicação coloca os módulos e dados locais revisados no destino e integra o import quando necessário. O sistema em execução continua com a configuração anterior até a ativação.

1. Selecione **Instalar ou atualizar**. Informe a conta Linux, o nome e o e-mail de autoria Git. Caso já exista um `config/local.nix` no checkout, os dados devem coincidir com os informados. O Noir gera o arquivo na preparação quando ele está ausente.
2. Autorize a consulta ao remoto. Se houver revisões novas, confirme o **fast-forward**, que avança a branch local até a revisão consultada sem criar um merge. **Branch** é a linha de desenvolvimento e **upstream** é a branch remota que ela acompanha. O checkout precisa estar limpo, sem alterações pendentes ou arquivos novos não ignorados.
3. Escolha o ambiente gráfico quando solicitado. Uma escolha explícita em `settings.json` é respeitada, inclusive **Definido pela máquina**. A primeira publicação bem-sucedida consolida essa escolha. Consulte [Escolha gráfica](configuration.md#escolha-gráfica).
4. Revise o import do NixOS, quando houver inclusão, o resumo da publicação e as mudanças de preferências apresentadas. Confirme **Publicar a configuração revisada?** e autentique-se para publicar no destino oficial.
5. Confira o resumo. Uma publicação bem-sucedida mostra o destino e, quando aplicável, a inclusão do import. O Noir tenta gravar a [identidade Git global](configuration.md#identidade) pela conta escolhida. Se essa etapa falhar, consulte [Identidade Git após publicação](recovery.md#identidade-git-após-publicação).

Se a publicação for bloqueada ou o resumo indicar falha, consulte [Diagnóstico por sintomas](recovery.md#diagnóstico-por-sintomas) antes de repetir a operação. Uma publicação bem-sucedida já torna a [escolha gráfica imutável](configuration.md#escolha-gráfica), mesmo que a etapa seguinte seja cancelada ou falhe.

## Acessar um TTY

Um **TTY** é um console de texto independente do terminal aberto na sessão gráfica. Antes de ativar, salve o trabalho e conheça o caminho de volta para a sessão. No terminal gráfico, o comando abaixo pode mostrar o número do console virtual usado pela sessão, quando o ambiente expõe o identificador de sessão.

```bash
if [ -n "${XDG_SESSION_ID:-}" ]; then
  loginctl show-session "$XDG_SESSION_ID" -p VTNr --value
fi
```

Na sessão gráfica, tente `Ctrl+Alt+F3` quando houver um console de login no TTY 3. Se estiver ocupado ou indisponível, tente outro console, como `Ctrl+Alt+F4`. Alguns teclados exigem `Fn` para enviar a tecla de função. Em uma VM, pode ser necessário enviar a combinação pela interface da VM. Entre com a conta normal, vá ao checkout e abra `./noir` ou `./noir --plain`. Para voltar do console, use a tecla de função do console gráfico, por exemplo `Alt+F2` se a sessão estiver no TTY 2. O número pode mudar quando o gerenciador de login reinicia. [Consoles virtuais no systemd](https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html)

## Da validação ao primeiro login

1. Selecione **Validar agora (dry-build)** depois da publicação, ou abra **Gerenciar sistema → Validar configuração (dry-build)**. O dry-build **valida** a configuração publicada, avaliando suas opções e mostrando o que seria necessário construir ou obter. Se houver erro, abra os [registros de rebuild](recovery.md#falha-no-dry-build) e resolva a causa antes de aplicar.
2. Quando estiver pronto para aplicar, o proprietário pode abrir um [TTY](#acessar-um-tty) e escolher **Gerenciar sistema → Aplicar configuração (switch)**. A operação ainda depende da sessão que a iniciou, e o gerenciador de login pode reiniciar durante o switch. O Noir executa outro dry-build e pede confirmação. A **construção** produz ou obtém os componentes da configuração. A **ativação** passa a usar essa configuração no sistema, inclusive com reinício de serviços quando necessário. Consulte [Validação e ativação](maintenance.md#validação-e-ativação) e, se o processo for interrompido, confira o [estado do sistema](recovery.md#ativação-interrompida).
3. Na tela de login, entre com a conta já existente da máquina. Para um perfil Noir, confira a sessão e o gerenciador de login descritos na [página do perfil](README.md#ambientes-gráficos). Com **Definido pela máquina**, use o ambiente ou console configurado na própria máquina. Contas que já têm preferências podem apresentar um layout diferente do padrão inicial.
4. Abra um terminal e confira um aplicativo comum, por exemplo com `java -version`. O comando `noir` instalado e os atalhos dos perfis procuram `~/nixos-config/noir`. Se o checkout estiver em outro local, execute `./noir` a partir dele. Se a sessão esperada estiver ausente, consulte [Diagnóstico por sintomas](recovery.md#diagnóstico-por-sintomas).

## Depois do primeiro login

- Para mudar papel de parede, opcionais ou tema Zsh, use [Editar preferências](configuration.md#preferências). As mudanças precisam ser publicadas e ativadas para entrar na configuração do sistema. Desktop e identidade seguem as regras descritas no guia de configuração.
- Para atualizar os módulos do Noir ou aplicar preferências já salvas, siga [Atualização e publicação](maintenance.md#atualização-e-publicação). Para atualizar os pacotes e módulos que o NixOS usa na avaliação, siga [Atualizar o Nixpkgs](maintenance.md#atualizar-o-nixpkgs).

## Destino alternativo

```bash
./noir --destination /CAMINHO/DESTINO
```

Use um destino separado do checkout, fora de `/etc/nixos`, com diretório pai físico e gravável. O fluxo publica sem integração com a configuração da máquina e sem o menu de gerenciamento do sistema. A primeira publicação ainda pode gravar arquivos locais do checkout e aplicar a identidade Git global. Para uma instalação de teste, use checkout e conta descartáveis.

[Configuração](configuration.md) · [Manutenção](maintenance.md)
