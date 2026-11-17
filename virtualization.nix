{ pkgs, ... }:

# Modulo opcional de virtualizacao QEMU/KVM via libvirt.
# Nao e ativado enquanto nao for importado pelo configuration.nix.
{
  virtualisation.libvirtd.enable = true;

  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    virt-viewer
  ];

  # Acesso a administracao do libvirt para o usuario local.
  # Revise o nome do usuario antes de importar este modulo.
  users.users.david.extraGroups = [ "libvirtd" ];
}
