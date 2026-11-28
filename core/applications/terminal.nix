{ config, lib, pkgs, ... }:

let
  # O KXMLGUI procura estes arquivos antes dos recursos internos do Konsole.
  # Mantém a versão original do XML para dar precedência ao arquivo pessoal.
  konsoleToolbars = pkgs.runCommand "konsole-noir-toolbars" {
    inherit (pkgs.kdePackages.konsole) src;
  } ''
    target="$out/share/kxmlgui5/konsole"
    mkdir -p "$target"
    tar -xf "$src" -C "$target" --strip-components=2 --wildcards \
      '*/desktop/konsoleui.rc' '*/desktop/sessionui.rc'
    substituteInPlace "$target/konsoleui.rc" \
      --replace-fail '<ToolBar name="mainToolBar">' '<ToolBar name="mainToolBar" hidden="true">'
    substituteInPlace "$target/sessionui.rc" \
      --replace-fail '<ToolBar name="sessionToolbar">' '<ToolBar name="sessionToolbar" hidden="true">'
  '';
in
{
  config = lib.mkIf (config.personalConfig.desktop == "kde") {
    environment.systemPackages = [
      konsoleToolbars
      (pkgs.writeTextDir "share/konsole/Noir.profile" ''
        [General]
        Name=Noir
        Parent=FALLBACK/

        [Scrolling]
        ScrollBarPosition=2
      '')
    ];
    environment.etc."xdg/konsolerc".text = ''
      [Desktop Entry]
      DefaultProfile=Noir.profile

      [MainWindow]
      MenuBar=Disabled

      [KonsoleWindow]
      RemoveWindowTitleBarAndFrame=false

      [TabBar]
      TabBarVisibility=ShowTabBarWhenNeeded
    '';
  };
}
