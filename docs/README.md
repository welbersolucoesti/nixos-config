# Documentação do Noir

[Projeto](../README.md)

## Por objetivo

| Objetivo | Caminho de leitura |
| --- | --- |
| **Instalar e usar** | [Instalação](installation.md) → [Configuração](configuration.md) → [Manutenção](maintenance.md). Em caso de falha, consulte [Diagnóstico por sintomas](recovery.md#diagnóstico-por-sintomas). |
| **Compreender o NixOS** | [Conceitos](concepts.md) → [Fluxos internos do Noir](architecture.md#fluxos-do-noir). |
| **Personalizar e manter um fork** | [Arquitetura](architecture.md) → [Personalização](customization.md) → [Validação em ambiente isolado](customization.md#validar-em-ambiente-isolado). |

## Por assunto

| Guia | Conteúdo |
| --- | --- |
| [Conceitos](concepts.md) | Configuração declarativa, Nix Store, gerações e limites de reprodutibilidade. |
| [Instalação](installation.md) | Pré-requisitos, integração com o NixOS, primeira publicação e primeiro login. |
| [Configuração](configuration.md) | Identidade, escolha gráfica imutável e preferências locais. |
| [Manutenção](maintenance.md) | Atualização, publicação, dry-build e ativação pelo proprietário. |
| [Aplicativos e serviços](applications.md) | Pacotes da estação, serviços compartilhados e módulos opcionais. |
| [Diagnóstico e recuperação](recovery.md) | Registros, falhas de publicação, recuperação administrativa e gerações do NixOS. |
| [Arquitetura](architecture.md) | Estrutura do repositório e responsabilidades dos módulos. |
| [Personalização](customization.md) | Aplicativos, serviços, perfis, preferências e sincronização de um fork. |

## Ambientes gráficos

Nas tabelas de atalhos, **Super** é a tecla de sistema, geralmente marcada com o logotipo do Windows. O Plasma a registra como **Meta** nas combinações descritas aqui. A coluna **Observação** identifica os atalhos do Noir e os padrões nativos. [Tecla Super](https://help.gnome.org/gnome-help/keyboard-key-super.html)

- [KDE Plasma](desktops/kde.md)
- [GNOME](desktops/gnome.md)
- [Cinnamon](desktops/cinnamon.md)
- [XFCE](desktops/xfce.md)

Os roteiros de validação gráfica usam uma instalação descartável ou VM, com uma conta nova e outra com preferências já gravadas. Registre a revisão do Noir, a do Nixpkgs e o tipo de sessão. Quando um teste depender de hardware físico, registre também o equipamento ou marque o caso como pendente.
