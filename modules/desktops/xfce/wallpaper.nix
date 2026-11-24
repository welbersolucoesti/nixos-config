{ config, lib, ... }:

let
  image = "xfce-cp-dark.svg";
  imageDirectory = "share/backgrounds/xfce";
in
{
  config = lib.mkIf (config.personalConfig.desktop == "xfce") {
    # Os dois programas usam a imagem pessoal por monitor quando ela existe.
    # Altera somente o fallback nativo e mantém a coleção de imagens do XFCE.
    nixpkgs.overlays = [
      (_: prev: {
        xfdesktop = prev.xfdesktop.overrideAttrs (old: {
          configureFlags = (old.configureFlags or [ ]) ++ [
            "--with-default-backdrop-filename=/run/current-system/sw/${imageDirectory}/${image}"
          ];
          postInstall = (old.postInstall or "") + ''
            test -s "$out/${imageDirectory}/${image}"
          '';
        });
        xfce4-screensaver = prev.xfce4-screensaver.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/xfce-bg.c \
              --replace-fail '#define XFCE_BG_FALLBACK_IMG "xfce-x.svg"' '#define XFCE_BG_FALLBACK_IMG "${image}"'
          '';
        });
      })
    ];
    environment.pathsToLink = [ "/${imageDirectory}" ];
  };
}
