{ lib, pkgs, ... }:

let
  # Reutiliza os instaladores originais com hash do Nixpkgs e exclui o
  # visualizador do Word, que inclui Tahoma fora do projeto Core Fonts.
  microsoftCoreFonts = pkgs.corefonts.overrideAttrs (old: {
    env.exes = builtins.appendContext
      (lib.concatStringsSep " " (lib.filter
        (path: !(lib.hasSuffix "-wd97vwr32.exe" path))
        (lib.splitString " " (builtins.unsafeDiscardStringContext old.env.exes))))
      (lib.filterAttrs
        (path: _: !(lib.hasSuffix "-wd97vwr32.exe.drv" path))
        (builtins.getContext old.env.exes));
    buildCommand = ''
      for installer in $exes; do
        cabextract "$installer"
      done
      target="$out/share/fonts/truetype"
      find . -maxdepth 1 -iname '*.ttf' -exec install -m444 -Dt "$target" {} +
      install -m444 -T ${pkgs.fetchurl {
        url = "https://corefonts.sourceforge.net/eula.htm";
        hash = "sha256-LOgNEsM+dANEreP2LsFi+pAnBNDMFB9Pg+KJAahlC6s=";
      }} "$target/eula.html"
    '';
    preferLocalBuild = true;
    allowSubstitutes = false;
  });
in
{
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    microsoftCoreFonts
  ];
}
