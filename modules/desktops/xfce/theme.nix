pkgs:
{
  theme = {
    name = "Orchis-Dark";
    package = pkgs.orchis-theme;
  };
  iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };
  cursorTheme = {
    name = "breeze_cursors";
    package = pkgs.runCommand "noir-breeze-cursors" { } ''
      mkdir -p "$out/share/icons"
      cp -r ${pkgs.kdePackages.breeze}/share/icons/breeze_cursors "$out/share/icons/"
    '';
    size = 24;
  };
}
