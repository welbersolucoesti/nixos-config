# Noir · Configuração declarativa para NixOS

O Noir configura uma estação NixOS de desenvolvimento com aplicativos, serviços e três perfis gráficos. Usa os módulos tradicionais do NixOS e o Nixpkgs, sem Flakes ou Home Manager.

- **Perfis que usam os componentes nativos de cada ambiente**, com temas, atalhos e layouts próprios do Noir.
- **Publicação revisável** pelo configurador Dialog ou em modo texto, com uma cópia da implantação anterior quando há atualização da árvore.
- **Configuração local fora do Git**, com identidade e preferências separadas dos módulos versionados.

## Ambientes gráficos

| Perfil | Sessão e login | Destaque |
| --- | --- | --- |
| [KDE Plasma](docs/desktops/kde.md) | Plasma 6, com Wayland disponível e SDDM | Breeze Dark e dois painéis flutuantes. |
| [GNOME](docs/desktops/gnome.md) | Wayland e GDM | Dock inferior, bandeja e histórico da área de transferência. |
| [Cinnamon](docs/desktops/cinnamon.md) | X11 e LightDM com Slick Greeter | Painéis Noir e ícones Papirus-XApp-Dark. |

Também é possível manter o ambiente gráfico sob controle da configuração da máquina e usar os módulos comuns do Noir. A escolha gráfica é consolidada na primeira publicação bem-sucedida. Consulte [Escolha gráfica](docs/configuration.md#escolha-gráfica).

## Início rápido

O Noir requer um NixOS já instalado, uma conta normal e acesso administrativo para publicar no destino oficial. Execute os comandos abaixo a partir do diretório pessoal da própria conta.

```bash
git clone https://github.com/welbersolucoesti/nixos-config.git
cd nixos-config
./noir
```

Selecione **Instalar ou atualizar**. O [guia de instalação](docs/installation.md) cobre a escolha do perfil, a publicação e o primeiro login. Use `./noir --plain` para o modo texto.

## Documentação

- **[Instalar](docs/installation.md)** — da preparação do NixOS ao primeiro login.
- **[Compreender](docs/concepts.md)** — como Nix, Nixpkgs e NixOS se relacionam e onde o Noir entra.
- **[Personalizar](docs/customization.md)** — como alterar módulos, validar mudanças e manter um fork.

[Índice completo](docs/README.md)
