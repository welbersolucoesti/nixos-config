{ config, lib, pkgs, ... }:

{
  options.personalConfig.virtualization.enable = lib.mkEnableOption "as ferramentas de virtualização e contêineres";

  config = lib.mkIf config.personalConfig.virtualization.enable {
    # ----------------------------------------------------------------------------
    # Maquinas virtuais: QEMU/KVM com libvirt
    # ----------------------------------------------------------------------------

    # Habilita o gerenciamento de maquinas virtuais pelo libvirt.
    virtualisation.libvirtd.enable = true;

    # Interface grafica para administrar maquinas virtuais.
    programs.virt-manager.enable = true;

    # Permite que o usuario local administre recursos do libvirt.
    # Revise o nome do usuario antes de importar este modulo.
    users.users.david.extraGroups = [ "libvirtd" ];

    # ----------------------------------------------------------------------------
    # Conteineres de desenvolvimento: Podman e Distrobox
    # ----------------------------------------------------------------------------

    # Disponibiliza o runtime de conteineres utilizado pelo Distrobox.
    # Nao cria nem inicia conteineres automaticamente.
    virtualisation.podman.enable = true;

    # ----------------------------------------------------------------------------
    # Aplicativos de virtualizacao
    # ----------------------------------------------------------------------------

    environment.systemPackages = with pkgs; [
      # Visualizador de consoles de maquinas virtuais.
      virt-viewer

      # Interface grafica para inspecionar conteineres, imagens e pods do Podman.
      podman-desktop

      # Cria e integra ambientes Linux em conteineres Podman.
      distrobox

      # Interface grafica Qt/Kirigami para gerenciar o Distrobox no KDE Plasma.
      kontainer
    ];
  };
}
