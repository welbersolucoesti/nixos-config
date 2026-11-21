{ pkgs, ... }:

{
  # Zsh com autocompletar, sugestões automáticas e destaque de sintaxe.
  programs.zsh = {

    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    # Oh My Zsh com tema bira e plugins git e sudo.
    ohMyZsh = {
      enable = true;
      plugins = ["git" "sudo"];
      theme = "bira";
    };
  };

  # Define o shell do usuário david; adapte o nome ao reutilizar o módulo.
  users.users.david.shell = pkgs.zsh;

  environment.etc."gitconfig".text = ''
    [user]
      name = David
      email = welbersolucoesti@gmail.com

    [init]
      defaultBranch = main
  '';

}
