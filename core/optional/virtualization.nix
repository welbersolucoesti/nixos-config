{
  # Uma escolha local habilita o conjunto. Cada módulo condiciona suas próprias definições.
  imports = [
    ../applications/kontainer.nix
    ../applications/distrobox.nix
    ../applications/podman-desktop.nix
    ../applications/virt-viewer.nix
    ../applications/virt-manager.nix
    ../services/libvirtd.nix
    ../services/podman.nix
  ];
}
